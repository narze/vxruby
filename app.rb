require "bundler/setup"
require_relative "config"
require "sinatra/base"
require "websocket/driver"
require "tempfile"
require "json"

# Adapter to make rack hijacked IO work with websocket-driver
class RackIO
  attr_reader :io, :env

  def initialize(env)
    @env = env
    env["rack.hijack"].call
    @io = env["rack.hijack_io"]
    @url = "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['REQUEST_URI']}"
  end

  def url
    @url
  end

  def write(data)
    @io.write(data)
  end
end

class VxRuby < Sinatra::Base
  set :server, :puma
  set :port, Config::PORT
  set :bind, Config::BIND
  set :public_folder, File.join(__dir__, "public")

  # Allow access from Tailscale IPs and local network
  set :host_authorization, {permitted_hosts: []}

  get "/" do
    send_file File.join(settings.public_folder, "index.html")
  end

  get "/ws" do
    return [400, {}, ["WebSocket only"]] unless env["HTTP_UPGRADE"]&.downcase == "websocket"

    rack_io = RackIO.new(env)
    driver = WebSocket::Driver.rack(rack_io)
    io = rack_io.io
    tempfile = nil

    driver.on :open do |_event|
      puts "[WS] Client connected"
      tempfile = Tempfile.new(["recording", ".ogg"])
      tempfile.binmode
    end

    driver.on :message do |event|
      data = event.data

      if data.is_a?(String) && data == "stop"
        puts "[WS] Stop received, transcribing..."
        driver.text(JSON.generate({type: "status", text: "Transcribing..."}))

        begin
          tempfile.close

          transcription = RubyLLM.transcribe(
            tempfile.path,
            model: Config::TRANSCRIPTION_MODEL
          )

          text = transcription.text
          IO.popen("pbcopy", "w") { |p| p.print text }
          puts "[WS] Transcription: #{text}"

          driver.text(JSON.generate({type: "result", text: text}))
        rescue => e
          puts "[WS] Error: #{e.message}"
          driver.text(JSON.generate({type: "error", text: e.message}))
        ensure
          tempfile&.unlink
          tempfile = Tempfile.new(["recording", ".ogg"])
          tempfile.binmode
        end
      elsif data.is_a?(Array)
        # Binary data arrives as array of bytes
        tempfile&.write(data.pack("C*"))
      elsif data.is_a?(String) && data != "stop"
        # Binary data might arrive as binary string
        tempfile&.write(data.b)
      end
    end

    driver.on :close do |_event|
      puts "[WS] Client disconnected"
      tempfile&.close
      tempfile&.unlink
      tempfile = nil
      io.close rescue nil
    end

    driver.start

    # Read loop in a thread
    Thread.new do
      begin
        loop do
          data = io.readpartial(4096)
          driver.parse(data)
        end
      rescue EOFError, IOError
        driver.close
      end
    end

    # Return async response to prevent Sinatra from closing the connection
    [-1, {}, []]
  end

  run! if app_file == $0
end

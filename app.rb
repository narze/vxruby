require "bundler/setup"
require_relative "config"
require "sinatra/base"
require "faye/websocket"
require "tempfile"

class VxRuby < Sinatra::Base
  set :server, :puma
  set :port, Config::PORT
  set :bind, Config::BIND
  set :public_folder, File.join(__dir__, "public")

  get "/" do
    send_file File.join(settings.public_folder, "index.html")
  end

  get "/ws" do
    return [400, {}, ["WebSocket only"]] unless Faye::WebSocket.websocket?(env)

    ws = Faye::WebSocket.new(env)
    tempfile = nil

    ws.on :open do |_event|
      puts "[WS] Client connected"
      tempfile = Tempfile.new(["recording", ".webm"])
      tempfile.binmode
    end

    ws.on :message do |event|
      if event.data.is_a?(String) && event.data == "stop"
        puts "[WS] Stop received, transcribing..."
        ws.send(JSON.generate({type: "status", text: "Transcribing..."}))

        begin
          tempfile.close

          transcription = RubyLLM.transcribe(
            tempfile.path,
            model: Config::TRANSCRIPTION_MODEL
          )

          text = transcription.text
          IO.popen("pbcopy", "w") { |p| p.print text }
          puts "[WS] Transcription: #{text}"

          ws.send(JSON.generate({type: "result", text: text}))
        rescue => e
          puts "[WS] Error: #{e.message}"
          ws.send(JSON.generate({type: "error", text: e.message}))
        ensure
          tempfile&.unlink
          tempfile = Tempfile.new(["recording", ".webm"])
          tempfile.binmode
        end
      elsif event.data.is_a?(Array)
        tempfile&.write(event.data.pack("C*"))
      end
    end

    ws.on :close do |_event|
      puts "[WS] Client disconnected"
      tempfile&.close
      tempfile&.unlink
      tempfile = nil
    end

    ws.rack_response
  end

  run! if app_file == $0
end

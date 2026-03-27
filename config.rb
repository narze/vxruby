require "dotenv/load"
require "ruby_llm"

RubyLLM.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
end

module Config
  PORT = ENV.fetch("PORT", 4567).to_i
  BIND = ENV.fetch("BIND", "0.0.0.0")
  TRANSCRIPTION_MODEL = ENV.fetch("TRANSCRIPTION_MODEL", "gemini-2.5-flash")
  SSL_CERT = ENV.fetch("SSL_CERT", File.join(__dir__, "certs", "server.crt"))
  SSL_KEY = ENV.fetch("SSL_KEY", File.join(__dir__, "certs", "server.key"))
  SSL_ENABLED = File.exist?(SSL_CERT) && File.exist?(SSL_KEY)
  PERMITTED_HOSTS = ["localhost"].concat(
    ENV.fetch("PERMITTED_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  )
end

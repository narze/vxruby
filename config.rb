require "dotenv/load"
require "ruby_llm"

RubyLLM.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
end

module Config
  PORT = ENV.fetch("PORT", 4567).to_i
  BIND = ENV.fetch("BIND", "0.0.0.0")
  TRANSCRIPTION_MODEL = ENV.fetch("TRANSCRIPTION_MODEL", "gemini-2.5-flash")
end

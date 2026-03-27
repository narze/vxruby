require_relative "config"

if Config::SSL_ENABLED
  ssl_bind Config::BIND, Config::PORT,
    cert: Config::SSL_CERT,
    key: Config::SSL_KEY,
    verify_mode: "none"
else
  bind "tcp://#{Config::BIND}:#{Config::PORT}"
end

# VxRuby - Personal Speech Transcriber

## Context

A self-hosted personal speech transcriber. The user opens a browser on their Android phone, speaks into it, and the audio is sent to a Ruby server running on their MacBook. The server transcribes the audio using RubyLLM (Gemini) and copies the text to the macOS clipboard. The transcription is also displayed back in the browser.

## Architecture

```
Android Browser  →(WebSocket)→  Sinatra Server (macOS)  →(audio file)→  RubyLLM (Gemini)
                 ←(WebSocket)←                          ←(text)←
                                        ↓
                                  macOS clipboard (pbcopy)
```

## Components

### Client (Single HTML page served by Sinatra)

- Served at `/` by Sinatra
- Uses browser **MediaRecorder API** to capture audio from microphone
- Connects to server via **WebSocket** at `/ws`
- Audio format: WebM/Opus (default MediaRecorder output on Android Chrome)
- **UI**: Large record/stop button, status indicator (idle/recording/transcribing), transcription result text area
- **WebSocket protocol**:
  - Client sends binary messages (audio chunks) while recording
  - Client sends text message `"stop"` when recording ends
  - Server sends text message back with transcription result or error

### Server (Sinatra + Faye-WebSocket)

- **`app.rb`** — Main Sinatra application
  - GET `/` serves the HTML client
  - WebSocket upgrade at `/ws`
  - On WebSocket connection: creates a temp file to buffer audio chunks
  - On binary message: appends audio data to temp file
  - On `"stop"` text message:
    1. Closes temp file
    2. Calls `RubyLLM.transcribe(temp_file_path, model: configured_model)`
    3. Copies result to macOS clipboard via `pbcopy`
    4. Sends transcription text back to client via WebSocket
    5. Cleans up temp file
- **`config.rb`** — Configuration module
  - Loads from `.env` via dotenv
  - `TRANSCRIPTION_MODEL` — default: `gemini-2.5-flash`
  - `GEMINI_API_KEY` — required
  - `PORT` — default: `4567`
  - `BIND` — default: `0.0.0.0`

### Transcription (RubyLLM)

- Uses `RubyLLM.transcribe(file_path, model: model)` API
- Default model: `gemini-2.5-flash` (configurable)
- Language auto-detection (handles mixed Thai/English)
- Optional `prompt` parameter for context hints

### Clipboard

- macOS: `IO.popen('pbcopy', 'w') { |p| p.print text }`

## File Structure

```
vxruby/
├── Gemfile
├── app.rb                 # Sinatra server + WebSocket handler
├── config.rb              # Configuration
├── public/
│   └── index.html         # Client UI (HTML + JS + CSS, single file)
├── .env.example           # Example environment variables
└── .gitignore
```

## Dependencies (Gemfile)

- `sinatra` — web framework
- `puma` — web server (supports Rack hijack for WebSocket)
- `faye-websocket` — WebSocket support
- `ruby_llm` — LLM integration for transcription
- `dotenv` — environment variable management

## Configuration (.env)

```
GEMINI_API_KEY=your_key_here
TRANSCRIPTION_MODEL=gemini-2.5-flash
PORT=4567
BIND=0.0.0.0
```

## Networking

- Server binds to `0.0.0.0` for Tailscale access
- No HTTPS needed — Tailscale provides encrypted tunnel
- Access from Android: `http://<tailscale-ip>:4567`
- Microphone access works over HTTP on Tailscale (treated as secure context by most browsers, but may need testing — fallback: use `chrome://flags` to allow insecure origins for mic access)

## Error Handling

- WebSocket connection errors: show status in UI, auto-reconnect
- Transcription errors: send error message back to client, display in UI
- Missing API key: fail fast on server startup with clear error message

## Verification

1. Start server: `ruby app.rb`
2. Open `http://localhost:4567` in browser
3. Click record, speak, click stop
4. Verify transcription appears in browser
5. Verify text is in macOS clipboard (`pbpaste` to check)
6. Test from Android via Tailscale IP

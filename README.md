# VxRuby

A self-hosted personal speech transcriber. Open the browser on your phone, speak into it, and the server transcribes the audio using [RubyLLM](https://rubyllm.com/) and copies the text to your macOS clipboard.

## Architecture

```
Phone Browser  →(WebSocket)→  Ruby Server (macOS)  →(audio)→  LLM (RubyLLM)
               ←(WebSocket)←                       ←(text)←
                                      ↓
                                macOS clipboard (pbcopy)
```

## Setup

### Prerequisites

- Ruby 3.4+
- A Gemini API key (or any LLM provider supported by RubyLLM)

### Install

```bash
bundle install
```

### Configure

```bash
cp .env.example .env
```

Edit `.env` and add your API key:

```
GEMINI_API_KEY=your_key_here
TRANSCRIPTION_MODEL=gemini-2.5-flash
PORT=4567
BIND=0.0.0.0
```

### SSL (required for mobile microphone access)

Browsers require HTTPS for microphone access from non-localhost origins. Generate a self-signed cert:

```bash
mkdir -p certs
openssl req -x509 -newkey rsa:2048 \
  -keyout certs/server.key -out certs/server.crt \
  -days 365 -nodes \
  -subj "/CN=your-hostname" \
  -addext "subjectAltName=DNS:your-hostname,IP:your-ip"
```

Replace `your-hostname` and `your-ip` with your server's hostname and IP address (e.g. Tailscale hostname and IP).

If no certs are present, the server falls back to HTTP (works for localhost testing).

### Run

```bash
./bin/server
```

Open `https://your-server:4567` on your phone. Accept the self-signed cert warning, then tap Record and speak.

## How it works

1. The browser captures audio using the MediaRecorder API
2. Audio chunks are streamed to the server via WebSocket
3. When you tap Stop, the server sends the audio to the configured LLM for transcription
4. The transcribed text is copied to the macOS clipboard and displayed in the browser

## License

MIT

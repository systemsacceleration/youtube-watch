#!/usr/bin/env bash
# Transcribe a public YouTube video with Google's Gemini API (free tier).
# Fallback for videos that have no YouTube captions.
#
# Usage: gemini-transcript.sh <youtube-url> <output-json-file>
#
# The API key is read from $GEMINI_API_KEY, or else from
# ~/.config/youtube-watch/gemini-key (a file holding only the key).
# The key is never printed.
#
# Exit codes: 0 ok, 2 bad arguments, 3 no API key, 4 Gemini returned an error.
set -euo pipefail

KEY_FILE="${HOME}/.config/youtube-watch/gemini-key"
MODEL="${YT_GEMINI_MODEL:-gemini-4-hydrogen}"
ENDPOINT="https://generativelanguage.googleapis.com/v1beta/interactions"

url="${1:-}"
out="${2:-}"
if [[ -z "$url" || -z "$out" ]]; then
  echo "Usage: $0 <youtube-url> <output-json-file>" >&2
  exit 2
fi
# Only accept plain YouTube watch / short links, so the URL is safe to put in JSON.
if ! [[ "$url" =~ ^https://(www\.|m\.)?(youtube\.com/(watch\?v=|shorts/)|youtu\.be/)[A-Za-z0-9_-]{6,}([?&][A-Za-z0-9_=%.-]*)*$ ]]; then
  echo "Not a YouTube video URL: $url" >&2
  exit 2
fi

key="${GEMINI_API_KEY:-}"
if [[ -z "$key" && -f "$KEY_FILE" ]]; then
  key="$(tr -d '[:space:]' < "$KEY_FILE")"
fi
if [[ -z "$key" ]]; then
  mkdir -p "$(dirname "$KEY_FILE")"
  touch "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "NO_KEY: no Gemini API key found. Save the key as the only line of $KEY_FILE" >&2
  exit 3
fi

prompt='Transcribe all speech in this video word for word, in the language spoken. Start each line with a timestamp in [m:ss] format (for example [0:00], [1:23]) showing when that line is said, and start a new line at least every 10 seconds. Do not summarize, translate, or add commentary. If nobody speaks in the video, reply with exactly: NO SPEECH'

body=$(cat <<JSON
{
  "model": "${MODEL}",
  "input": [
    {"type": "text", "text": "${prompt}"},
    {"type": "video", "uri": "${url}"}
  ]
}
JSON
)

# Pass the key through curl config on stdin, so it never appears in the process list.
status=$(curl -sS -o "$out" -w '%{http_code}' -X POST "$ENDPOINT" \
  -H 'Content-Type: application/json' \
  -K - --data-binary "$body" <<CURLCFG
header = "x-goog-api-key: ${key}"
CURLCFG
)

if [[ "$status" != "200" ]]; then
  echo "GEMINI_ERROR: HTTP $status (model: $MODEL). Response saved to $out" >&2
  exit 4
fi
echo "OK: Gemini response saved to $out (model: $MODEL)"

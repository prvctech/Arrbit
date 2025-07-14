#!/usr/bin/with-contenv bash
set -euo pipefail

echo "*** [Arrbit] Installing dependencies ***"

# Install core packages, including FFmpeg (bundles ffprobe)
apk add --no-cache flac jq py3-pip python3 gcc musl-dev libffi-dev uv ffmpeg id3lib

echo "*** [Arrbit] Linking ffmpeg and ffprobe to /app/bin for Tidal plugin compatibility ***"
mkdir -p /app/bin
ln -sf "$(which ffmpeg)" /app/bin/ffmpeg
ln -sf "$(which ffprobe)" /app/bin/ffprobe

echo "*** [Arrbit] Installing Beets via pip ***"
uv pip install --system --upgrade --no-cache-dir --break-system-packages beets

echo "*** [Arrbit] Dependencies installation completed! ***"

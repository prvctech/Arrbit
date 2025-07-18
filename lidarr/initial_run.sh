#!/usr/bin/env bash
set -euo pipefail

DEST="/etc/services.d/run.bash"
SRC_URL="https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/run.bash"

if [ ! -f "$DEST" ]; then
  echo "[Arrbit] Downloading run.bash to $DEST..."
  curl -sfL "$SRC_URL" -o "$DEST" && chmod +x "$DEST"
else
  echo "[Arrbit] run.bash already present; skipping download."
fi

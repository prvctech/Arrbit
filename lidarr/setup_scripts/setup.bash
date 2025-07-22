#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v2.2
# Purpose : Quietly installs all core Arrbit folders into /config/arrbit including config/
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_CONF="/config/arrbit/config/arrbit-config.conf"
DEST_DIR="/config/arrbit"
GITHUB_RAW="https://raw.githubusercontent.com/prvctech/Arrbit/refs/heads/main/lidarr"

mkdir -p "$DEST_DIR"

download_folder() {
  local folder="$1"
  local target="$2"
  local url_base="$GITHUB_RAW/$folder"

  mkdir -p "$target"
  curl -fsSL "$url_base/files.txt" | while read -r file; do
    curl -fsSL "$url_base/$file" -o "$target/$file" >/dev/null 2>&1 || true
  done
}

download_folder "helpers"                   "$DEST_DIR/helpers"
download_folder "connectors"                "$DEST_DIR/connectors"
download_folder "process_scripts/modules"   "$DEST_DIR/process_scripts/modules"
download_folder "process_scripts/services"  "$DEST_DIR/process_scripts/services"
download_folder "process_scripts/setup_scripts" "$DEST_DIR/process_scripts/setup_scripts"
download_folder "config"                    "$DEST_DIR/config"

chmod -R 777 "$DEST_DIR"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

sleep infinity
exit 0

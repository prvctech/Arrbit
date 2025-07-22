#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v2.0
# Purpose : Downloads and installs core Arrbit folders and scripts into /config/arrbit
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# ------------- constants & paths ----------------------------------------------------
ARRBIT_TAG="[Arrbit]"
SERVICE_DIR="/config/arrbit"
LOG_DIR="/config/logs"
SCRIPT_NAME="setup"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
GITHUB_RAW="https://raw.githubusercontent.com/prvctech/Arrbit/refs/heads/main/lidarr"

# ------------- startup -------------------------------------------------------------
mkdir -p "$SERVICE_DIR" "$LOG_DIR"
touch "$LOG_FILE" ; chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 2

log() { 
  local line="[Arrbit] $*"
  echo "$line"
  printf '%s\n' "$line" | arrbitLogClean >> "$LOG_FILE"
}

# ------------- download logic -------------------------------------------------------
download_folder() {
  local folder="$1"
  local url_base="$GITHUB_RAW/$folder"
  local dest="$SERVICE_DIR/$folder"

  mkdir -p "$dest"
  curl -fsSL "$url_base/files.txt" | while read -r file; do
    curl -fsSL "$url_base/$file" -o "$dest/$file" >>"$LOG_FILE" 2>&1 || log "Failed to get $folder/$file"
  done
}

log "Starting setup v2.0"

download_folder "helpers"
download_folder "connectors"
download_folder "process_scripts/modules"
download_folder "process_scripts/services"
download_folder "process_scripts/setup_scripts"

chmod -R 777 "$SERVICE_DIR"

cp -n "$GITHUB_RAW/config/arrbit-config.conf" "$SERVICE_DIR/arrbit-config.conf" 2>/dev/null || true
cp -n "$GITHUB_RAW/config/beets-config.yaml"   "$SERVICE_DIR/beets-config.yaml"   2>/dev/null || true

# ------------- complete -------------------------------------------------------------
if grep -q -i "ENABLE_ARRBIT\s*=\s*false" "$SERVICE_DIR/arrbit-config.conf"; then
  echo "[Arrbit] See config settings to enable Arrbit, everything is off by default." | tee -a "$LOG_FILE"
fi

echo "[Arrbit] Setup complete – log saved in $LOG_FILE"
sleep infinity
exit 0

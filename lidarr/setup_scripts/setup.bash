#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
ARRBIT_CONF="$SERVICE_DIR/config/arrbit-config.conf"

mkdir -p "$TMP_DIR" "$SERVICE_DIR"
cd "$TMP_DIR"
curl -fsSL -o arrbit.zip "$ZIP_URL"
unzip -oq arrbit.zip

# Copy universal folders
cp -r Arrbit-main/universal/helpers     "$SERVICE_DIR/helpers"
cp -r Arrbit-main/universal/connectors  "$SERVICE_DIR/connectors"

# Copy lidarr folders into flattened structure
cp -r Arrbit-main/lidarr/config        "$SERVICE_DIR/config"
cp -r Arrbit-main/lidarr/process_scripts/modules  "$SERVICE_DIR/modules"
cp -r Arrbit-main/lidarr/process_scripts/services "$SERVICE_DIR/services"
# **Fix here:** rename setup_scripts → setup
cp -r Arrbit-main/lidarr/process_scripts/setup_scripts "$SERVICE_DIR/setup"

chmod -R 777 "$SERVICE_DIR"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

sleep infinity
exit 0

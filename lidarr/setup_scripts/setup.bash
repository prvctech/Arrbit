#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v3.1
# Purpose : Quietly installs all Arrbit files into /config/arrbit (flattened structure)
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

SERVICE_DIR="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
ARRBIT_CONF="$SERVICE_DIR/config/arrbit-config.conf"

mkdir -p "$TMP_DIR" "$SERVICE_DIR"
cd "$TMP_DIR"
curl -fsSL -o arrbit.zip "$ZIP_URL"
unzip -q arrbit.zip

# Copy universal folders
cp -r "$TMP_DIR/Arrbit-main/universal/helpers"     "$SERVICE_DIR/helpers"
cp -r "$TMP_DIR/Arrbit-main/universal/connectors"  "$SERVICE_DIR/connectors"

# Copy lidarr folders into flattened structure
cp -r "$TMP_DIR/Arrbit-main/lidarr/config"                         "$SERVICE_DIR/config"
cp -r "$TMP_DIR/Arrbit-main/lidarr/process_scripts/modules"        "$SERVICE_DIR/modules"
cp -r "$TMP_DIR/Arrbit-main/lidarr/process_scripts/services"       "$SERVICE_DIR/services"
cp -r "$TMP_DIR/Arrbit-main/lidarr/process_scripts/setup_scripts"  "$SERVICE_DIR/setup"

chmod -R 777 "$SERVICE_DIR"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

sleep infinity
exit 0

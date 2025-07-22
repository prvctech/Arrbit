#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v3.4
# Purpose : Installs all Arrbit files into /config/arrbit using GitHub ZIP (flattened structure, quiet mode)
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

SERVICE_DIR="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
ARRBIT_CONF="$SERVICE_DIR/config/arrbit-config.conf"

mkdir -p "$TMP_DIR" "$SERVICE_DIR"
cd "$TMP_DIR"
curl -fsSL -o arrbit.zip "$ZIP_URL"
unzip -oq arrbit.zip

# Copy helpers and connectors from universal/
cp -r Arrbit-main/universal/helpers     "$SERVICE_DIR/helpers"
cp -r Arrbit-main/universal/connectors  "$SERVICE_DIR/connectors"

# Copy modules and services from process_scripts
cp -r Arrbit-main/lidarr/process_scripts/modules   "$SERVICE_DIR/modules"
cp -r Arrbit-main/lidarr/process_scripts/services  "$SERVICE_DIR/services"

# Copy setup scripts except 'run'
mkdir -p "$SERVICE_DIR/setup"
find Arrbit-main/lidarr/setup_scripts -type f ! -name "run" -exec cp {} "$SERVICE_DIR/setup/" \;

# Copy config folder only if it doesn't already exist
[[ -d "$SERVICE_DIR/config" ]] || cp -r Arrbit-main/lidarr/config "$SERVICE_DIR/config"

chmod -R 777 "$SERVICE_DIR"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

sleep infinity
exit 0

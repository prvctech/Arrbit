#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v2.3
# Purpose : Quietly installs Arrbit files from GitHub zip to /config/arrbit
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

DEST_DIR="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
ARRBIT_CONF="$DEST_DIR/config/arrbit-config.conf"

mkdir -p "$TMP_DIR" "$DEST_DIR"
cd "$TMP_DIR"
curl -fsSL -o arrbit.zip "$ZIP_URL"
unzip -q arrbit.zip

# Copy top-level helpers and connectors from universal/
cp -r "$TMP_DIR/Arrbit-main/universal/helpers"     "$DEST_DIR/helpers"
cp -r "$TMP_DIR/Arrbit-main/universal/connectors"  "$DEST_DIR/connectors"

# Copy lidarr scripts and config folders
cp -r "$TMP_DIR/Arrbit-main/lidarr/process_scripts/modules"       "$DEST_DIR/process_scripts/modules"
cp -r "$TMP_DIR/Arrbit-main/lidarr/process_scripts/services"      "$DEST_DIR/process_scripts/services"
cp -r "$TMP_DIR/Arrbit-main/lidarr/process_scripts/setup_scripts" "$DEST_DIR/process_scripts/setup_scripts"
cp -r "$TMP_DIR/Arrbit-main/lidarr/config"                        "$DEST_DIR/config"

chmod -R 777 "$DEST_DIR"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

sleep infinity
exit 0

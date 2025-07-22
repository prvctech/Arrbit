#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v2.4
# Purpose : Quietly install all core Arrbit folders into /config/arrbit (no logs, no colours).
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

DEST="/config/arrbit"
TMP="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
CONF_WARN="$DEST/config/arrbit-config.conf"

mkdir -p "$DEST" "$TMP"
curl -fsSL "$ZIP_URL" -o "$TMP/repo.zip"
unzip -q "$TMP/repo.zip" -d "$TMP"

SRC="$TMP/Arrbit-main/lidarr"

cp -rf "$SRC/helpers"                    "$DEST/"
cp -rf "$SRC/connectors"                 "$DEST/"
cp -rf "$SRC/process_scripts/modules"    "$DEST/modules"
cp -rf "$SRC/process_scripts/services"   "$DEST/services"
cp -rf "$SRC/process_scripts/setup_scripts" "$DEST/setup"
cp -rf "$SRC/config"                     "$DEST/config"

chmod -R 777 "$DEST"
rm -rf "$TMP"

[ -f "$CONF_WARN" ] || echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

sleep infinity
exit 0

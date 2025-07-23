#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v4.2
# Purpose : Dynamically installs all Arrbit modules, services, setup scripts, and config to /config/arrbit.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_ROOT="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="Arrbit-main/lidarr"

ARRBIT_CONF="$ARRBIT_ROOT/config/arrbit-config.conf"

mkdir -p "$TMP_DIR" "$ARRBIT_ROOT"
cd "$TMP_DIR"

# --- 1. Download and extract full repo ------------------------------------------
curl -fsSL "$ZIP_URL" -o arrbit.zip
unzip -qqo arrbit.zip   # <- overwrite always, never prompts

# --- 2. Copy modules and services (deep copy, new files auto-included) ----
mkdir -p "$ARRBIT_ROOT/modules" "$ARRBIT_ROOT/services"
cp -rf "$REPO_MAIN/process_scripts/modules/."   "$ARRBIT_ROOT/modules/"
cp -rf "$REPO_MAIN/process_scripts/services/."  "$ARRBIT_ROOT/services/"

# --- 3. Copy setup scripts except setup.bash and run -----------------------------
mkdir -p "$ARRBIT_ROOT/setup"
find "$REPO_MAIN/setup_scripts" -type f ! -name "setup.bash" ! -name "run" -exec cp -f {} "$ARRBIT_ROOT/setup/" \;

# --- 4. Copy config directory only if it does not already exist ------------------
if [[ ! -d "$ARRBIT_ROOT/config" ]]; then
    cp -r "$REPO_MAIN/config" "$ARRBIT_ROOT/"
fi

chmod -R 777 "$ARRBIT_ROOT"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable individual services, everything is off by default."

exit 0

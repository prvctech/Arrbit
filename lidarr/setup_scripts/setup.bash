#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version : v4.0
# Purpose : Dynamically installs all Arrbit modules, services, setup scripts, and config to /config/arrbit.
#           Excludes itself (setup.bash) and run from setup/. Preserves user config if already present.
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
unzip -qq arrbit.zip

# --- 2. Dynamically copy modules and services (deep copy, any new files auto-included) ----
rsync -a "$REPO_MAIN/process_scripts/modules/"   "$ARRBIT_ROOT/modules/"
rsync -a "$REPO_MAIN/process_scripts/services/"  "$ARRBIT_ROOT/services/"

# --- 3. Dynamically copy setup scripts, except setup.bash and run --------------------------
mkdir -p "$ARRBIT_ROOT/setup/"
rsync -a --exclude='setup.bash' --exclude='run' "$REPO_MAIN/setup_scripts/" "$ARRBIT_ROOT/setup/"

# --- 4. Copy config directory only if it does not already exist ----------------------------
if [[ ! -d "$ARRBIT_ROOT/config" ]]; then
    rsync -a "$REPO_MAIN/config/" "$ARRBIT_ROOT/config/"
fi

chmod -R 777 "$ARRBIT_ROOT"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable individual services, everything is off by default."

exit 0

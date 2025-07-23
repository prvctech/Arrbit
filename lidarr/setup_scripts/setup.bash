#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.1
# Purpose: Dynamically installs all Arrbit modules, services, setup scripts, connectors, helpers, and config to /config/arrbit.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_ROOT="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/lidarr"
REPO_UNIVERSAL="$TMP_DIR/Arrbit-main/universal"
ARRBIT_CONF="$ARRBIT_ROOT/config/arrbit-config.conf"

mkdir -p "$TMP_DIR" "$ARRBIT_ROOT"

# --- Start Process ---
echo -e "\033[36m[Arrbit]\033[0m \033[33msetup install\033[0m v4.2 ...."
echo "[Arrbit] Downloading Arrbit repository to temporary folder ..."
cd "$TMP_DIR"

# --- 1. Download and extract full repo ---
if ! curl -fsSL "$ZIP_URL" -o arrbit.zip; then
    echo "[Arrbit] Failed to download repository. Check network and URL."
    exit 1
fi
unzip -qqo arrbit.zip

# --- 2. Copy helpers and connectors ---
cp -r "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/"
cp -r "$REPO_UNIVERSAL/connectors" "$ARRBIT_ROOT/"

# --- 3. Source helpers for logging ---
source "$ARRBIT_ROOT/helpers/logging_utils.bash"
source "$ARRBIT_ROOT/helpers/helpers.bash"

# --- 4. Copy modules and services ---
cp -rf "$REPO_MAIN/process_scripts/modules/."   "$ARRBIT_ROOT/modules/"
cp -rf "$REPO_MAIN/process_scripts/services/."  "$ARRBIT_ROOT/services/"

# --- 5. Copy setup scripts except setup.bash and run ---
mkdir -p "$ARRBIT_ROOT/setup"
find "$REPO_MAIN/setup_scripts" -type f ! -name "setup.bash" ! -name "run" -exec cp -f {} "$ARRBIT_ROOT/setup/" \;

# --- 6. Copy config directory only if it does not already exist ---
if [[ ! -d "$ARRBIT_ROOT/config" ]]; then
    cp -r "$REPO_MAIN/config" "$ARRBIT_ROOT/"
    echo "[Arrbit] Default config folder copied."
else
    echo "[Arrbit] Config folder exists, not overwritten."
fi

chmod -R 777 "$ARRBIT_ROOT"

# --- Logging to file ---
LOG_FILE="/config/logs/arrbit-setup-$(date +'%Y_%m_%d-%H_%M').log"
log_info "Arrbit setup completed successfully." | tee -a "$LOG_FILE"

[[ -f "$ARRBIT_CONF" ]] || echo "[Arrbit] See config settings to enable individual services, everything is off by default."

echo "[Arrbit] Setup complete. All files are in place."

exit 0

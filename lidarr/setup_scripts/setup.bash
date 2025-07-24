#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.2-gs2.6
# Purpose: Bootstraps Arrbit: downloads, installs, and initializes everything into /config/arrbit.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# --------- PRE-HELPERS BOOTSTRAP SECTION (minimal color only) ----------------------------
ARRBIT_ROOT="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/lidarr"
REPO_UNIVERSAL="$TMP_DIR/Arrbit-main/universal"
ARRBIT_CONF="$ARRBIT_ROOT/config/arrbit-config.conf"

# Only minimal color until helpers are copied
CYAN='\033[96m'
GREEN='\033[92m'
NC='\033[0m'

mkdir -p "$TMP_DIR" "$ARRBIT_ROOT"

# --- Initial Banner & Status (echo only, GS exception for setup) ---
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting setup install${NC} v1.2-gs2.6"
echo -e "${CYAN}[Arrbit]${NC} Syncing Arrbit repository..."

cd "$TMP_DIR"

# --- Download and extract full repo ---
if ! curl -fsSL "$ZIP_URL" -o arrbit.zip; then
    echo -e "${CYAN}[Arrbit]${NC} ERROR: Failed to download repository. Check network and URL."
    exit 1
fi
unzip -qqo arrbit.zip

# --- Copy helpers and connectors (so we can use real logging!) ---
cp -r "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/"
cp -r "$REPO_UNIVERSAL/connectors" "$ARRBIT_ROOT/"

# -------------------------------------------------------------------------------------------------------------
# POST-HELPERS SECTION (switch to full Golden Standard logging)
# -------------------------------------------------------------------------------------------------------------
HELPERS_DIR="$ARRBIT_ROOT/helpers"
LOG_DIR="/config/logs"
mkdir -p "$LOG_DIR"
source "$HELPERS_DIR/logging_utils.bash"
source "$HELPERS_DIR/helpers.bash"
arrbitPurgeOldLogs 2

SCRIPT_NAME="setup"
SCRIPT_VERSION="v1.2-gs2.6"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

log_info "Helpers and connectors copied. Proceeding with full module setup..."

# --- Copy modules and services ---
cp -rf "$REPO_MAIN/process_scripts/modules/."   "$ARRBIT_ROOT/modules/"
cp -rf "$REPO_MAIN/process_scripts/services/."  "$ARRBIT_ROOT/services/"

# --- Copy custom process scripts (tagger.bash etc) ---
if [[ -d "$REPO_MAIN/process_scripts/custom" ]]; then
    cp -rf "$REPO_MAIN/process_scripts/custom" "$ARRBIT_ROOT/"
    log_info "Custom process_scripts copied."
fi

# --- Copy setup scripts except setup.bash and run ---
mkdir -p "$ARRBIT_ROOT/setup"
find "$REPO_MAIN/setup_scripts" -type f ! -name "setup.bash" ! -name "run" -exec cp -f {} "$ARRBIT_ROOT/setup/" \;

# --- Copy config directory only if not present ---
if [[ ! -d "$ARRBIT_ROOT/config" ]]; then
    cp -r "$REPO_MAIN/config" "$ARRBIT_ROOT/"
    log_info "Default config folder copied."
else
    log_info "Config folder exists, not overwritten."
fi

chmod -R 777 "$ARRBIT_ROOT"

if [[ -f "$ARRBIT_CONF" ]]; then
    log_info "See config settings to enable individual services; everything is off by default."
fi

log_info "Setup complete. All files are in place."
log_info "Log saved to $LOG_FILE"

exit 0

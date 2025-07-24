#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.3-gs2.6
# Purpose: Bootstraps Arrbit: downloads, installs, and initializes everything into /config/arrbit.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_ROOT="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/lidarr"
REPO_UNIVERSAL="$TMP_DIR/Arrbit-main/universal"

# Minimal color for banner (before helpers exist)
CYAN='\033[96m'
GREEN='\033[92m'
NC='\033[0m'

mkdir -p "$TMP_DIR" "$ARRBIT_ROOT"

# --- Banner & status (echo only, GS exception for setup) ---
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Syncing Arrbit repository...${NC}"

cd "$TMP_DIR"

# --- Download and extract repo ---
if ! curl -fsSL "$ZIP_URL" -o arrbit.zip; then
    echo -e "${CYAN}[Arrbit]${NC} ERROR: Failed to download repository. Check network and URL."
    exit 1
fi
unzip -qqo arrbit.zip

# --- Copy helpers and connectors ---
cp -r "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/"
cp -r "$REPO_UNIVERSAL/connectors" "$ARRBIT_ROOT/"

# --- Switch to Golden Standard logging as soon as helpers are present ---
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

# --- Copy modules and services ---
cp -rf "$REPO_MAIN/process_scripts/modules/."   "$ARRBIT_ROOT/modules/"
cp -rf "$REPO_MAIN/process_scripts/services/."  "$ARRBIT_ROOT/services/"

# --- Copy custom process scripts if they exist ---
if [[ -d "$REPO_MAIN/process_scripts/custom" ]]; then
    cp -rf "$REPO_MAIN/process_scripts/custom" "$ARRBIT_ROOT/"
fi

# --- Copy setup scripts except setup.bash and run ---
mkdir -p "$ARRBIT_ROOT/setup"
find "$REPO_MAIN/setup_scripts" -type f ! -name "setup.bash" ! -name "run" -exec cp -f {} "$ARRBIT_ROOT/setup/" \;

# --- Copy config only if not present ---
if [[ ! -d "$ARRBIT_ROOT/config" ]]; then
    cp -r "$REPO_MAIN/config" "$ARRBIT_ROOT/"
fi

chmod -R 777 "$ARRBIT_ROOT"

# --- FINAL MESSAGE: only log success if everything completed ---
log_info "Setup complete. All files synced."
log_info "Log saved to $LOG_FILE"

exit 0

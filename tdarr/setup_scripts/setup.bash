#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.0.2-gs2.8.2
# Purpose: Bootstraps Arrbit: downloads, installs, and initializes everything into /config/arrbit. SILENT except fatal error.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_ROOT="/app/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/tdarr"
REPO_UNIVERSAL="$TMP_DIR/Arrbit-main/universal"

# --- Ensure Arrbit root and tmp dir exist ---
mkdir -p "$ARRBIT_ROOT" "$ARRBIT_ROOT/tmp"
chmod 777 "$ARRBIT_ROOT/tmp"
mkdir -p "$TMP_DIR"

cd "$TMP_DIR"

# --- Download and extract repo ---
if ! curl -fsSL "$ZIP_URL" -o arrbit.zip; then
    echo "[Arrbit] ERROR: Failed to download repository. Check network and URL."
    exit 1
fi
unzip -qqo arrbit.zip

# --- Copy helpers and connectors from universal ---
cp -r "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/"

# --- Switch to Golden Standard logging as soon as helpers are present ---
HELPERS_DIR="$ARRBIT_ROOT/helpers"
LOG_DIR="/app/logs"
mkdir -p "$LOG_DIR"
source "$HELPERS_DIR/logging_utils.bash"
source "$HELPERS_DIR/helpers.bash"
arrbitPurgeOldLogs 3

SCRIPT_NAME="setup"
SCRIPT_VERSION="v1.1.0-gs2.8.3"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- Copy data (if present) and services (if present) ---
mkdir -p "$ARRBIT_ROOT/data" "$ARRBIT_ROOT/services"
if [[ -d "$REPO_MAIN/data" ]]; then
  cp -rf "$REPO_MAIN/data/." "$ARRBIT_ROOT/data/" 2>/dev/null || true
fi
if [[ -d "$REPO_MAIN/process_scripts/services" ]]; then
  cp -rf "$REPO_MAIN/process_scripts/services/."  "$ARRBIT_ROOT/services/" 2>/dev/null || true
fi

# --- Copy setup scripts except setup.bash and run ---
mkdir -p "$ARRBIT_ROOT/setup"
find "$REPO_MAIN/setup_scripts" -type f ! -name "setup.bash" ! -name "run" -exec cp -f {} "$ARRBIT_ROOT/setup/" \;

# --- Ensure config directory exists ---
mkdir -p "$ARRBIT_ROOT/config"

# --- Copy each config file ONLY if it does NOT already exist ---
if [ -d "$REPO_MAIN/config" ] && compgen -G "$REPO_MAIN/config/*" > /dev/null; then
  for src_file in "$REPO_MAIN/config/"*; do
    filename="$(basename "$src_file")"
    dest_file="$ARRBIT_ROOT/config/$filename"
    if [[ ! -f "$dest_file" ]]; then
      cp -f "$src_file" "$dest_file"
      chmod 777 "$dest_file"
    fi
  done
fi

chmod -R 777 "$ARRBIT_ROOT"

exit 0

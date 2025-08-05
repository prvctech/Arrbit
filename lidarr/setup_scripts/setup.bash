#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.5-gs2.7.1
# Purpose: Bootstraps Arrbit: downloads, installs, and initializes everything into /config/arrbit. SILENT except fatal error.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_ROOT="/config/arrbit"
TMP_DIR="/tmp/arrbit_dl_$$"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/lidarr"
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
cp -r "$REPO_UNIVERSAL/connectors" "$ARRBIT_ROOT/"

# --- Switch to Golden Standard logging as soon as helpers are present ---
HELPERS_DIR="$ARRBIT_ROOT/helpers"
LOG_DIR="/config/logs"
mkdir -p "$LOG_DIR"
source "$HELPERS_DIR/logging_utils.bash"
source "$HELPERS_DIR/helpers.bash"
arrbitPurgeOldLogs 2

SCRIPT_NAME="setup"
SCRIPT_VERSION="v1.5-gs2.7.1"
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

# --- Ensure config directory exists ---
mkdir -p "$ARRBIT_ROOT/config"
mkdir -p /config/plugins
chmod 777 /config/plugins

# --- Copy YAML config file if it doesn't exist ---
if [[ -f "$REPO_MAIN/config/arrbit-config.yaml" ]]; then
  if [[ ! -f "$ARRBIT_ROOT/config/arrbit-config.yaml" ]]; then
    cp -f "$REPO_MAIN/config/arrbit-config.yaml" "$ARRBIT_ROOT/config/"
    chmod 777 "$ARRBIT_ROOT/config/arrbit-config.yaml"
    log_info "Installed arrbit-config.yaml"
  fi
else
  log_warning "arrbit-config.yaml not found in repository"
fi

# --- Remove old .conf file if it exists ---
if [[ -f "$ARRBIT_ROOT/config/arrbit-config.conf" ]]; then
  log_info "Removing deprecated arrbit-config.conf"
  rm -f "$ARRBIT_ROOT/config/arrbit-config.conf"
fi

# --- Copy new configuration utilities ---
# Copy config_utils.bash
if [[ -f "$REPO_MAIN/helpers/config_utils.bash" ]]; then
  cp -f "$REPO_MAIN/helpers/config_utils.bash" "$ARRBIT_ROOT/helpers/"
  chmod 777 "$ARRBIT_ROOT/helpers/config_utils.bash"
  log_info "Installed config_utils.bash"
fi

# Copy config_validator.bash
if [[ -f "$REPO_MAIN/helpers/config_validator.bash" ]]; then
  cp -f "$REPO_MAIN/helpers/config_validator.bash" "$ARRBIT_ROOT/helpers/"
  chmod 777 "$ARRBIT_ROOT/helpers/config_validator.bash"
  log_info "Installed config_validator.bash"
fi

chmod -R 777 "$ARRBIT_ROOT"

exit 0

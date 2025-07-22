#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [setup]
# Version: v1.0
# Purpose: Main setup and update script; prepares folder structure, downloads/updates scripts, and manages config files.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# ------------------ 0. ENV and PATHS (constants) ------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"
SERVICE_DIR="/custom-services.d"          # destination for all Arrbit code
HELPERS_DIR="$SERVICE_DIR/helpers"
CONNECTORS_DIR="$SERVICE_DIR/connectors"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit_update_$$"
SETUP_DIR="$SERVICE_DIR/setup"
SCRIPT_NAME="setup"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# --- Source helpers & logging utils -------------------------------------------------
REMOTE_LOG_UTILS="https://raw.githubusercontent.com/prvctech/Arrbit/refs/heads/main/universal/helpers/logging_utils.bash"
REMOTE_HELPERS="https://raw.githubusercontent.com/prvctech/Arrbit/refs/heads/main/universal/helpers/helpers.bash"

# Source remote versions first; fall back to local copies after repo download
if ! source <(curl -sfL "$REMOTE_LOG_UTILS") 2>/dev/null; then
  source "$HELPERS_DIR/logging_utils.bash" 2>/dev/null || {
    echo "❌  [Arrbit] Unable to load logging_utils.bash"; exit 1; }
fi

if ! source <(curl -sfL "$REMOTE_HELPERS") 2>/dev/null; then
  source "$HELPERS_DIR/helpers.bash" 2>/dev/null || {
    echo "❌  [Arrbit] Unable to load helpers.bash"; exit 1; }
fi

# ------------------ 1. LOGO & HEADER ------------------
LOGO_URL="https://raw.githubusercontent.com/prvctech/Arrbit/refs/heads/main/lidarr/process_scripts/modules/data/arrbit_logo.bash"

# Source remote logo; fall back to local copy if download fails
{ source <(curl -sfL "$LOGO_URL") 2>/dev/null || \
  [[ -f "$SERVICE_DIR/process_scripts/modules/data/arrbit_logo.bash" ]] && \
  source "$SERVICE_DIR/process_scripts/modules/data/arrbit_logo.bash"; }

# Display logo if the function exists
[[ $(type -t arrbit_logo) == "function" ]] && arrbit_logo

log "🚀  $ARRBIT_TAG Running Arrbit setup v1.0..."

# ------------------ Failsafe ------------------
if [[ -f /custom-cont-init.d/initial_run.bash ]]; then
  log "⚠️  $ARRBIT_TAG initial_run.bash found in /custom-cont-init.d. Sleeping to avoid conflict."
  sleep infinity
fi

# ------------------ 2. CREATE FOLDER STRUCTURE ------------------
log "🔨  $ARRBIT_TAG Building folder structure..."
mkdir -p "$SERVICE_DIR" "$HELPERS_DIR" "$CONNECTORS_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$SETUP_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$SETUP_DIR"

# ------------------ 3. DOWNLOAD & UNZIP REPO ------------------
log "🌐  $ARRBIT_TAG Downloading latest Arrbit bundle..."
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip"
log "📦️  $ARRBIT_TAG Archive saved."
unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR"
log "🗃️  $ARRBIT_TAG Archive extracted."

# ------------------ 4. COPY CODE ------------------
# 4a. process_scripts  → /custom-services.d/
cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICE_DIR/"

# 4b. helpers → /custom-services.d/helpers/
if [[ -d "$TMP_DIR/Arrbit-main/universal/helpers" ]]; then
  cp -rf "$TMP_DIR/Arrbit-main/universal/helpers/"* "$HELPERS_DIR/"
fi

# 4c. connectors → /custom-services.d/connectors/
if [[ -d "$TMP_DIR/Arrbit-main/universal/connectors" ]]; then
  cp -rf "$TMP_DIR/Arrbit-main/universal/connectors/"* "$CONNECTORS_DIR/"
fi

chmod -R 777 "$SERVICE_DIR"
log "📋  $ARRBIT_TAG Modules, helpers & connectors copied."

# ----- Strip .bash from service scripts -----
if [[ -d "$SERVICE_DIR/services" ]]; then
  for f in "$SERVICE_DIR/services/"*.bash; do
    [[ -e "$f" ]] || break           # nothing to rename
    mv "$f" "${f%.bash}" && chmod 777 "${f%.bash}"
  done
fi

# ------------------ 5. COPY SETUP SCRIPTS ------------------
for setup_script in start.bash dependencies.bash; do
  src="$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$SETUP_DIR/"
    chmod 777 "$SETUP_DIR/$setup_script"
    log "📋  $ARRBIT_TAG $setup_script copied."
  else
    log "⚠️  $ARRBIT_TAG $setup_script not found; skipping."
  fi
done

# ------------------ 6. COPY CONFIG FILES (IF MISSING) ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  src_cfg="$TMP_DIR/Arrbit-main/lidarr/config/$cfg"
  if [[ -f "$src_cfg" && ! -f "$CONFIG_DIR/$cfg" ]]; then
    cp "$src_cfg" "$CONFIG_DIR/"
    chmod 666 "$CONFIG_DIR/$cfg"
    log "💾  $ARRBIT_TAG $cfg saved."
  fi
done

# ------------------ 7. CLEANUP & FINAL PERMISSIONS ------------------
rm -rf "$TMP_DIR"
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" || true
log "✅  $ARRBIT_TAG Setup complete. Log saved to $log_file_path"

# ------------------ 8. HOLD CONTAINER ------------------
sleep infinity

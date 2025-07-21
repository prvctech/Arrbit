#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit setup
# Version: v3.2
# Purpose: Main setup and update script; prepares folder structure, downloads/updates scripts, and manages config files.
# -------------------------------------------------------------------------------------------------------------

scriptVersion="v3.2"

# ------------------ 0. ENV and PATHS (constants) ------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit_update_$$"
SETUP_DIR="$SERVICE_DIR/setup"
HELPERS_DIR="$SERVICE_DIR/helpers"
SCRIPT_NAME="setup"
LOG_FILE_PATH="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

sleep 8

# ------------------ 1. SOURCE HELPERS ------------------
# These will be sourced AFTER helpers are copied over (see below)

trap 'errorTrap $LINENO' ERR
trap _cleanup EXIT

# ------------------ 2. LOGO & FIRST LOG LINE ------------------
sleep 8  # Let container logs settle before Arrbit logo

# Minimal first log (since helpers are not sourced yet)
echo -e "🚀  $ARRBIT_TAG Starting $SCRIPT_NAME setup v$scriptVersion..." | tee -a "$LOG_FILE_PATH"

# --------------- 3. OLD LOGS CLEANUP (MAX 3) ------------------
mkdir -p "$LOG_DIR"
log_count=$(ls -1 "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log 2>/dev/null | wc -l)
if [[ $log_count -gt 3 ]]; then
  ls -1t "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log | tail -n +4 | xargs rm -f
fi

# ------------------ 4. BUILD FOLDER STRUCTURE ------------------
mkdir -p "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$SETUP_DIR" "$HELPERS_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$SETUP_DIR" "$HELPERS_DIR"

# ------------------ 5. DOWNLOAD SCRIPTS/MODULES ------------------
echo -e "$ARRBIT_TAG 🌐  Downloading latest modules/scripts from GitHub..." | tee -a "$LOG_FILE_PATH"
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip"
if [ $? -ne 0 ]; then
  echo -e "$ARRBIT_TAG ❌  Failed to download scripts/modules from GitHub! Exiting." | tee -a "$LOG_FILE_PATH"
  rm -rf "$TMP_DIR"
  sleep infinity
fi
echo -e "$ARRBIT_TAG 📦  Downloaded archive: $TMP_DIR/arrbit.zip" | tee -a "$LOG_FILE_PATH"

unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR"
if [ $? -ne 0 ]; then
  echo -e "$ARRBIT_TAG ❌  Failed to unzip modules! Exiting." | tee -a "$LOG_FILE_PATH"
  rm -rf "$TMP_DIR"
  sleep infinity
fi
echo -e "$ARRBIT_TAG 📁  Modules unzipped to temp directory." | tee -a "$LOG_FILE_PATH"

# ------------------ 6. COPY universal/helpers/* TO /etc/services.d/arrbit/helpers/ ------------------
cp -rf "$TMP_DIR/Arrbit-main/universal/helpers/"* "$HELPERS_DIR/"
chmod -R 777 "$HELPERS_DIR"
echo -e "$ARRBIT_TAG 📋  Helpers copied to $HELPERS_DIR" | tee -a "$LOG_FILE_PATH"

# ------------------ 7. SOURCE HELPERS ------------------
source "$HELPERS_DIR/logging_utils.bash"
source "$HELPERS_DIR/error_utils.bash"
source "$HELPERS_DIR/helpers.bash"

# ------------------ 8. CHECK FLAGS ------------------
LOG_LEVEL=$(getFlag "LOG_LEVEL")
ENABLE_ARRBIT=$(getFlag "ENABLE_ARRBIT")
[[ -z "$LOG_LEVEL" ]] && LOG_LEVEL=0

if [[ "$ENABLE_ARRBIT" != "true" ]]; then
  [[ "$LOG_LEVEL" -gt 0 ]] && log "⏩  Arrbit is DISABLED (ENABLE_ARRBIT=false); setup.bash will not proceed."
  sleep infinity
fi

# ------------------ 9. COPY process_scripts (modules, services, data, custom) INTO SERVICE_DIR ------------------
log "📁  Copying process_scripts/* to $SERVICE_DIR"
cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICE_DIR/"
if [ $? -ne 0 ]; then
  log "❌  Failed to copy modules to service directory! Exiting."
  rm -rf "$TMP_DIR"
  sleep infinity
fi
chmod -R 777 "$SERVICE_DIR"
log "📋  Modules copied to modules directory."

# ------------------ 10. COPY SETUP SCRIPTS ------------------
for setup_script in start.bash dependencies.bash; do
  if [ -f "$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script" ]; then
    cp -f "$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script" "$SETUP_DIR/$setup_script"
    chmod 777 "$SETUP_DIR/$setup_script"
    log "📋  $setup_script copied to setup directory."
  else
    log "⚠️   $setup_script not found in repo! Skipping."
  fi
done

# ------------------ 11. COPY CONFIG FILES IF MISSING ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  if [ -f "$TMP_DIR/Arrbit-main/lidarr/config/$cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    cp "$TMP_DIR/Arrbit-main/lidarr/config/$cfg" "$CONFIG_DIR/$cfg"
    if [ $? -eq 0 ]; then
      chmod 666 "$CONFIG_DIR/$cfg"
      log "💾  $cfg saved to config directory."
    else
      log "❌  Failed to copy $cfg to config directory!"
    fi
  elif [ -f "$CONFIG_DIR/$cfg" ]; then
    log "⏩  $cfg exists; skipping download."
  fi
done

# ------------------ 12. CLEANUP TEMP FOLDER ------------------
rm -rf "$TMP_DIR"
log "✅  Setup complete. All scripts and config checked."

# ------------------ 13. FINAL PERMISSIONS ------------------
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" "$HELPERS_DIR" || true
log "📄  Log saved to $LOG_FILE_PATH"

# ------------------ 14. AUTO-TRIGGER start.bash IF PRESENT ------------------
if [ -x "$SETUP_DIR/start.bash" ]; then
  log "🚀  Launching start.bash..."
  bash "$SETUP_DIR/start.bash"
  exit $?
else
  log "⚠️   start.bash not found or not executable in setup folder. Setup finished."
  sleep infinity
fi

sleep infinity

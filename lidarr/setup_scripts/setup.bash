#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit setup
# Version: v3.1
# Purpose: Main setup and update script; prepares folder structure, downloads/updates scripts, and manages config files.
# -------------------------------------------------------------------------------------------------------------

scriptVersion="v3.1"

# ------------------ 0. ENV and PATHS (constants) ------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit_update_$$"
SETUP_DIR="$SERVICE_DIR/setup"
SCRIPT_NAME="setup"
LOG_FILE_PATH="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# ------------------ 1. SOURCE HELPERS ------------------
source "$SERVICE_DIR/universal/helpers/logging_utils.bash"
source "$SERVICE_DIR/universal/helpers/error_utils.bash"
source "$SERVICE_DIR/universal/helpers/helpers.bash"

trap 'errorTrap $LINENO' ERR
trap _cleanup EXIT

# ------------------ 2. CONFIG FLAGS & LOGIC ------------------
LOG_LEVEL=$(getFlag "LOG_LEVEL")
ENABLE_ARRBIT=$(getFlag "ENABLE_ARRBIT")

# Safe default if missing
[[ -z "$LOG_LEVEL" ]] && LOG_LEVEL=0

if [[ "$ENABLE_ARRBIT" != "true" ]]; then
  [[ "$LOG_LEVEL" -gt 0 ]] && log "⏩  Arrbit is DISABLED (ENABLE_ARRBIT=false); setup.bash will not proceed."
  sleep infinity
fi

# ------------------ 3. LOGO & FIRST LOG LINE ------------------
sleep 8  # Let container logs settle before Arrbit logo

if [ -f "$SERVICE_DIR/process_scripts/modules/data/arrbit_logo.bash" ]; then
    source "$SERVICE_DIR/process_scripts/modules/data/arrbit_logo.bash"
    arrbit_logo
fi

if [[ "$LOG_LEVEL" -eq 3 ]]; then
  log "🚀  $ARRBIT_TAG Starting $SCRIPT_NAME setup v$scriptVersion..."
else
  echo -e "🚀  $ARRBIT_TAG Starting $SCRIPT_NAME setup v$scriptVersion..." | tee -a "$LOG_FILE_PATH"
fi

# --------------- 4. OLD LOGS CLEANUP (MAX 3) ------------------
if [[ -d "$LOG_DIR" ]]; then
  log_count=$(ls -1 "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log 2>/dev/null | wc -l)
  if [[ $log_count -gt 3 ]]; then
    ls -1t "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log | tail -n +4 | xargs rm -f
  fi
fi

# ------------------ 5. BUILD FOLDER STRUCTURE ------------------
[[ "$LOG_LEVEL" -eq 3 ]] && log "🔧  Building folder structure..."
mkdir -p "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$SETUP_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$SETUP_DIR"

# ------------------ 6. DOWNLOAD SCRIPTS/MODULES ------------------
[[ "$LOG_LEVEL" -eq 3 ]] && log "🌐  Downloading latest modules/scripts from GitHub..."
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip"
if [ $? -ne 0 ]; then
  log "❌  Failed to download scripts/modules from GitHub! Exiting."
  rm -rf "$TMP_DIR"
  sleep infinity
fi
[[ "$LOG_LEVEL" -eq 3 ]] && log "📦  Downloaded archive: $TMP_DIR/arrbit.zip"

unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR"
if [ $? -ne 0 ]; then
  log "❌  Failed to unzip modules! Exiting."
  rm -rf "$TMP_DIR"
  sleep infinity
fi
[[ "$LOG_LEVEL" -eq 3 ]] && log "📁  Modules unzipped to temp directory."

cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICE_DIR/"
if [ $? -ne 0 ]; then
  log "❌  Failed to copy modules to service directory! Exiting."
  rm -rf "$TMP_DIR"
  sleep infinity
fi
chmod -R 777 "$SERVICE_DIR"
[[ "$LOG_LEVEL" -eq 3 ]] && log "📋  Modules copied to modules directory."

# ------------------ 7. COPY SETUP SCRIPTS ------------------
for setup_script in start.bash dependencies.bash; do
  if [ -f "$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script" ]; then
    cp -f "$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script" "$SETUP_DIR/$setup_script"
    chmod 777 "$SETUP_DIR/$setup_script"
    [[ "$LOG_LEVEL" -eq 3 ]] && log "📋  $setup_script copied to setup directory."
  else
    [[ "$LOG_LEVEL" -eq 3 ]] && log "⚠️   $setup_script not found in repo! Skipping."
  fi
done

# ------------------ 8. COPY CONFIG FILES IF MISSING ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  if [ -f "$TMP_DIR/Arrbit-main/lidarr/config/$cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    cp "$TMP_DIR/Arrbit-main/lidarr/config/$cfg" "$CONFIG_DIR/$cfg"
    if [ $? -eq 0 ]; then
      chmod 666 "$CONFIG_DIR/$cfg"
      [[ "$LOG_LEVEL" -eq 3 ]] && log "💾  $cfg saved to config directory."
    else
      log "❌  Failed to copy $cfg to config directory!"
    fi
  elif [ -f "$CONFIG_DIR/$cfg" ]; then
    [[ "$LOG_LEVEL" -eq 3 ]] && log "⏩  $cfg exists; skipping download."
  fi
done

# ------------------ 9. CLEANUP TEMP FOLDER ------------------
rm -rf "$TMP_DIR"
[[ "$LOG_LEVEL" -eq 3 ]] && log "✅  Setup complete. All scripts and config checked."

# ------------------ 10. FINAL PERMISSIONS ------------------
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" || true
[[ "$LOG_LEVEL" -eq 3 ]] && log "📄  Log saved to $LOG_FILE_PATH"

# ------------------ 11. AUTO-TRIGGER start.bash IF PRESENT ------------------
if [ -x "$SETUP_DIR/start.bash" ]; then
  [[ "$LOG_LEVEL" -eq 3 ]] && log "🚀  Launching start.bash..."
  bash "$SETUP_DIR/start.bash"
  exit $?
else
  log "⚠️   start.bash not found or not executable in setup folder. Setup finished."
  sleep infinity
fi

sleep infinity

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [setup]
# Version: 1.4
# Purpose: Main setup and update script; prepares folder structure, downloads/updates scripts, and manages config files.
# -------------------------------------------------------------------------------------------------------------

set +e

# ------------------------------------------------------------
# 0. ENV and PATHS (constants)
# ------------------------------------------------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit_update_$$"
SETUP_DIR="$SERVICE_DIR/setup"

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
SCRIPT_NAME="setup"
logFilePath="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# ------------------------------------------------------------
# LOGGING FUNCTIONS: emoji and color on STDOUT, plain in log file
# ------------------------------------------------------------
logRaw() {
  local stripped
  stripped=$(echo -e "$1" | sed -E $'s/(\\x1B|\\033)\\[[0-9;]*[a-zA-Z]//g; s/[🚀⏩📥🌐🛠️📦📁🔄📋📄✅❌⚠️🔵🟢🔴]//g; s/\\\\n/\\\n/g; s/^[[:space:]]+\\[Arrbit\\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

log() {
  local msg="$1"
  echo -e "$msg"
  logRaw "$msg"
}

timestamp=$(date +"%Y_%m_%d-%H_%M")
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +2 -delete
touch "$logFilePath"
chmod 777 "$logFilePath"

# ------------------------------------------------------------
# 1. SHOW LOGO & HEADER (logo ONLY prints to terminal, never log file)
# ------------------------------------------------------------
sleep 8  # Let container logs settle before Arrbit logo

if [ -f "$SERVICE_DIR/modules/data/arrbit_logo.bash" ]; then
    source "$SERVICE_DIR/modules/data/arrbit_logo.bash"
    arrbit_logo
fi

echo ""  # Terminal spacing

# ------------------------------------------------------------
# 2. CREATE FOLDER STRUCTURE
# ------------------------------------------------------------
log "🛠️    $ARRBIT_TAG Building folder structure..."
mkdir -p "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$SETUP_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$SETUP_DIR"

# ------------------------------------------------------------
# 3. SYNC SCRIPTS/MODULES FROM GITHUB (NO CONNECTORS, NO FULL CONFIG FOLDER)
# ------------------------------------------------------------
log "🌐  $ARRBIT_TAG Downloading latest modules/scripts from GitHub..."
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip"
if [ $? -ne 0 ]; then
  log "❌  $ARRBIT_TAG Failed to download scripts/modules from GitHub! Exiting."
  rm -rf "$TMP_DIR"
  exit 1
fi
log "📦  $ARRBIT_TAG Downloaded archive: $TMP_DIR/arrbit.zip"

unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR"
if [ $? -ne 0 ]; then
  log "❌  $ARRBIT_TAG Failed to unzip modules! Exiting."
  rm -rf "$TMP_DIR"
  exit 1
fi
log "📁  $ARRBIT_TAG Modules unzipped to temp directory."

# Copy process_scripts (modules, services, data, custom) into SERVICE_DIR
cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICE_DIR/"
if [ $? -ne 0 ]; then
  log "❌  $ARRBIT_TAG Failed to copy modules to service directory! Exiting."
  rm -rf "$TMP_DIR"
  exit 1
fi
chmod -R 777 "$SERVICE_DIR"
log "📋  $ARRBIT_TAG Modules copied to service directory."

# ------------------------------------------------------------
# 4. COPY SETUP SCRIPTS: start.bash & dependencies.bash into setup/
# ------------------------------------------------------------
for setup_script in start.bash dependencies.bash; do
  if [ -f "$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script" ]; then
    cp -f "$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script" "$SETUP_DIR/$setup_script"
    chmod 777 "$SETUP_DIR/$setup_script"
    log "✅  $ARRBIT_TAG $setup_script saved to setup folder."
  else
    log "⚠️  $ARRBIT_TAG $setup_script not found in repo! Skipping."
  fi
done

# ------------------------------------------------------------
# 5. COPY INDIVIDUAL CONFIG FILES IF MISSING (NEVER OVERWRITE)
# ------------------------------------------------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  if [ -f "$TMP_DIR/Arrbit-main/lidarr/config/$cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    cp "$TMP_DIR/Arrbit-main/lidarr/config/$cfg" "$CONFIG_DIR/$cfg"
    if [ $? -eq 0 ]; then
      chmod 777 "$CONFIG_DIR/$cfg"
      log "✅  $ARRBIT_TAG $cfg saved to config directory."
    else
      log "❌  $ARRBIT_TAG Failed to copy $cfg to config directory!"
    fi
  elif [ -f "$CONFIG_DIR/$cfg" ]; then
    log "⏩  $ARRBIT_TAG $cfg exists; skipping download."
  fi
done

# ------------------------------------------------------------
# 6. CLEANUP TEMP FOLDER
# ------------------------------------------------------------
rm -rf "$TMP_DIR"
log "✅  $ARRBIT_TAG Setup complete. Modules and config checked."

# ------------------------------------------------------------
# 7. FINAL PERMISSIONS
# ------------------------------------------------------------
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" || true
log "📄  $ARRBIT_TAG Log saved to $logFilePath"
log "✅  $ARRBIT_TAG Exiting setup. Ready for start.bash."

# ------------------------------------------------------------
# 8. AUTO-TRIGGER start.bash IF PRESENT IN setup/
# ------------------------------------------------------------
if [ -x "$SETUP_DIR/start.bash" ]; then
  log "🚀  $ARRBIT_TAG Launching Arrbit services..."
  bash "$SETUP_DIR/start.bash"
  exit $?
else
  log "⚠️  $ARRBIT_TAG start.bash not found or not executable in setup folder. Setup finished; manual start required."
  sleep infinity
fi

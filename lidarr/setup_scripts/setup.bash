#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit setup
# Version: v3.2
# Purpose: Main setup and update script; prepares folder structure, downloads/updates scripts, and manages config files.
# -------------------------------------------------------------------------------------------------------------

SCRIPT_VERSION="v3.2"

# ------------------ 0. CONSTANTS ------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit-$$"
HELPERS_DIR="$SERVICE_DIR/helpers"
SETUP_DIR="$SERVICE_DIR/setup_scripts"
SCRIPT_NAME="setup"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# ------------------ 1. PREPARE DIRECTORIES ------------------
mkdir -p "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$HELPERS_DIR" "$SETUP_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$HELPERS_DIR" "$SETUP_DIR"

# ------------------ 2. DOWNLOAD & EXTRACT REPO ------------------
echo -e "🌐  $ARRBIT_TAG Downloading Arrbit repository..." >&2
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip" || { echo -e "$ARRBIT_TAG ❌  Download failed; sleeping indefinitely."; sleep infinity; }
unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR" || { echo -e "$ARRBIT_TAG ❌  Unzip failed; cleaning up and sleeping indefinitely."; rm -rf "$TMP_DIR"; sleep infinity; }
REPO_ROOT="$TMP_DIR/Arrbit-$GITHUB_BRANCH"

# ------------------ 3. INSTALL HELPERS ------------------
cp -rf "$REPO_ROOT/universal/helpers/"* "$HELPERS_DIR/"
chmod -R 777 "$HELPERS_DIR"

# ------------------ 4. SOURCE HELPERS & SET TRAPS ------------------
source "$HELPERS_DIR/logging_utils.bash"
source "$HELPERS_DIR/error_utils.bash"
source "$HELPERS_DIR/helpers.bash"
trap 'errorTrap $LINENO' ERR
trap _cleanup EXIT

# ------------------ 5. INITIAL LOGGING ------------------
LOG_FILE_PATH="$LOG_DIR/arrbit-$SCRIPT_NAME-$(date +%Y_%m_%d-%H_%M).log"
log "🚀  $ARRBIT_TAG Starting $SCRIPT_NAME v$SCRIPT_VERSION..."

# ------------------ 6. LOG ROTATION ------------------
log_count=$(ls -1 "$LOG_DIR"/arrbit-"$SCRIPT_NAME"-*.log 2>/dev/null | wc -l)
if [ "$log_count" -gt 3 ]; then
  ls -1t "$LOG_DIR"/arrbit-"$SCRIPT_NAME"-*.log | tail -n +4 | xargs rm -f
fi

# ------------------ 7. CHECK FLAGS ------------------
LOG_LEVEL=$(getFlag "LOG_LEVEL"); [ -z "$LOG_LEVEL" ] && LOG_LEVEL=0
ENABLE_ARRBIT=$(getFlag "ENABLE_ARRBIT")
if [ "$ENABLE_ARRBIT" != "true" ]; then
  [ "$LOG_LEVEL" -gt 0 ] && log "⏩  Arrbit disabled (ENABLE_ARRBIT=false); sleeping indefinitely."
  sleep infinity
fi

# ------------------ 8. INSTALL PROCESS SCRIPTS ------------------
log "📦  Copying process scripts to $SERVICE_DIR..."
cp -rf "$REPO_ROOT/lidarr/process_scripts/"* "$SERVICE_DIR/"
if [ $? -ne 0 ]; then
  log "❌  Failed to copy process scripts; sleeping indefinitely."
  sleep infinity
fi
chmod -R 777 "$SERVICE_DIR"

# ------------------ 9. INSTALL SETUP SCRIPTS ------------------
for script in start.bash dependencies.bash; do
  if [ -f "$REPO_ROOT/lidarr/setup_scripts/$script" ]; then
    install -m 777 "$REPO_ROOT/lidarr/setup_scripts/$script" "$SETUP_DIR/$script"
    log "📋  $script installed to $SETUP_DIR."
  else
    log "⚠️   $script not found; skipping."
  fi
done

# ------------------ 10. INSTALL CONFIG FILES ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  if [ -f "$REPO_ROOT/lidarr/config/$cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    install -m 666 "$REPO_ROOT/lidarr/config/$cfg" "$CONFIG_DIR/$cfg"
    log "💾  $cfg saved to config directory."
  else
    log "⏩  $cfg exists; skipping."
  fi
done

# ------------------ 11. CLEANUP ------------------
rm -rf "$TMP_DIR"
log "✅  Setup complete."

# ------------------ 12. FINAL PERMISSIONS ------------------
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" "$HELPERS_DIR" || true
log "📄  Log saved to $LOG_FILE_PATH"

# ------------------ 13. AUTO-TRIGGER start.bash ------------------
if [ -x "$SETUP_DIR/start.bash" ]; then
  log "🚀  Launching start.bash..."
  exec "$SETUP_DIR/start.bash"
else
  log "⚠️   start.bash not found or not executable; sleeping indefinitely."
  sleep infinity
fi

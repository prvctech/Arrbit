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
ARRBIT_LOGO_URL="https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/modules/data/arrbit_logo.bash"

# Delay to allow Hotio and other service logs to finish first
sleep 8

# ------------------ LOGO & HEADER ------------------
# Print Arrbit logo remotely (always latest version)
if curl -sfL "$ARRBIT_LOGO_URL" -o /tmp/arrbit_logo.bash; then
    source /tmp/arrbit_logo.bash
    arrbit_logo
    rm -f /tmp/arrbit_logo.bash
else
    echo -e "$ARRBIT_TAG Starting setup..." >&2
fi

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

# ------------------ 7. INSTALL SETUP SCRIPTS (DYNAMIC) ------------------
if [ -d "$REPO_ROOT/lidarr/setup_scripts" ]; then
  cp -rf "$REPO_ROOT/lidarr/setup_scripts/"* "$SETUP_DIR/" 2>/dev/null || true
  log "📋  All setup scripts copied to $SETUP_DIR."
else
  log "⚠️   No setup scripts found in repo; skipping."
fi
chmod -R 777 "$SETUP_DIR"

# ------------------ 8. INSTALL PROCESS SCRIPTS (DYNAMIC) ------------------
if [ -d "$REPO_ROOT/lidarr/process_scripts" ]; then
  cp -rf "$REPO_ROOT/lidarr/process_scripts/"* "$SERVICE_DIR/" 2>/dev/null || true
  log "📦  All process scripts copied to $SERVICE_DIR."
else
  log "⚠️   No process scripts found in repo; skipping."
fi
chmod -R 777 "$SERVICE_DIR"

# ------------------ 9. INSTALL CONFIG FILES (SAFE) ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  if [ -f "$REPO_ROOT/lidarr/config/$cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    install -m 666 "$REPO_ROOT/lidarr/config/$cfg" "$CONFIG_DIR/$cfg"
    log "💾  $cfg saved to config directory."
  else
    log "⏩  $cfg exists; skipping."
  fi
done

# ------------------ 10. CLEANUP TEMP ------------------
rm -rf "$TMP_DIR"
log "✅  Setup complete."

# ------------------ 11. FINAL PERMISSIONS ------------------
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" "$HELPERS_DIR" || true
log "📄  Log saved to $LOG_FILE_PATH"

# ------------------ 12. AUTO-TRIGGER start.bash ------------------
if [ -x "$SETUP_DIR/start.bash" ]; then
  log "🚀  Launching start.bash..."
  exec "$SETUP_DIR/start.bash"
else
  log "⚠️   start.bash not found or not executable; sleeping indefinitely."
  sleep infinity
fi

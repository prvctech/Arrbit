#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit start.bash
# Version: v1.9
# Purpose: Launches Arrbit services based on config flags. Installs dependencies from local copy. Supervises service modules.
# -------------------------------------------------------------------------------------------------------------

scriptVersion="v1.9"

# ------------------------------------------------------------
# 0. ENV and PATHS (constants)
# ------------------------------------------------------------
SCRIPT_NAME="start"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
SETUP_DIR="$SERVICE_DIR/setup"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
SERVICE_YELLOW="\033[1;33m"

# ------------------------------------------------------------
# 1. INIT LOG FILE, TRACE, CLEAN OLD LOGS, PERMISSIONS
# ------------------------------------------------------------
mkdir -p "$LOG_DIR"

# Clean old logs if > 3 exist
log_count=$(ls -1 "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log 2>/dev/null | wc -l)
if [ "$log_count" -gt 3 ]; then
  ls -1tr "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log | head -n -3 | xargs rm -f
fi

touch "$log_file_path"
chmod 777 "$log_file_path"
chmod -R 777 "$SERVICE_DIR"

# Enable trace to file only
exec 3>&1 4>&2
exec 1>>"$log_file_path" 2>&1
PS4='+ ${BASH_SOURCE}:${LINENO}: '
set -x
exec 1>&3 2>&4

# ------------------------------------------------------------
# LOGGING HELPERS
# ------------------------------------------------------------
logRaw() {
  local stripped
  stripped=$(echo -e "$1" |
    sed -E $'s/(\\x1B|\\033)\\[[0-9;]*[a-zA-Z]//g; \
              s/[🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴]//g; \
              s/^[[:space:]]+\\[Arrbit\\]/[Arrbit]/')
  echo "$stripped" >> "$log_file_path"
}

log() {
  echo -e "$1"
  logRaw "$1"
}

errorTrap() {
  log "❌  ${ARRBIT_TAG} Error at line $1"
}
trap 'errorTrap $LINENO' ERR

_cleanup() {
  rm -rf /tmp/arrbit-* 2>/dev/null || true
}
trap _cleanup EXIT

getFlag() {
  grep -E "^$1=" "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g'
}

# ------------------------------------------------------------
# 2. SCRIPT START LOG
# ------------------------------------------------------------
log "🚀  ${ARRBIT_TAG} Starting ${SERVICE_YELLOW}${SCRIPT_NAME}\033[0m ${scriptVersion}..."

# ------------------------------------------------------------
# 3. CHECK MASTER ARRBIT ENABLE FLAG
# ------------------------------------------------------------
ENABLE_ARRBIT="true"
if [ -f "$CONFIG_DIR/arrbit-config.conf" ]; then
  ENABLE_ARRBIT=$(getFlag "ENABLE_ARRBIT")
fi

if [[ "${ENABLE_ARRBIT,,}" != "true" ]]; then
  log "⚠️   ${ARRBIT_TAG} Arrbit is OFF."
  log "⚠️   ${ARRBIT_TAG} \033[1;33mBefore starting, enable Arrbit by setting ENABLE_ARRBIT=\"true\" in /config/arrbit/arrbit-config.conf.\033[0m"
  log "⚠️   ${ARRBIT_TAG} \033[1;33mAll services are off by default—customize as needed.\033[0m"
  sleep infinity
fi

# ------------------------------------------------------------
# 4. INSTALL DEPENDENCIES IF PRESENT
# ------------------------------------------------------------
if [ -f "$SETUP_DIR/dependencies.bash" ]; then
  chmod 777 "$SETUP_DIR/dependencies.bash"
  log "📥  ${ARRBIT_TAG} Installing dependencies..."
  bash "$SETUP_DIR/dependencies.bash"
  if [ $? -ne 0 ]; then
    log "❌  ${ARRBIT_TAG} dependencies.bash script failed! Exiting."
    sleep infinity
  fi
else
  log "⚠️   ${ARRBIT_TAG} dependencies.bash not found in setup/. Skipping dependency install."
fi

# ------------------------------------------------------------
# 5. PARSE FLAGS FOR SERVICES
# ------------------------------------------------------------
ENABLE_AUTOCONFIG="true"
ENABLE_PLUGINS="false"
if [ -f "$CONFIG_DIR/arrbit-config.conf" ]; then
  ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
  ENABLE_PLUGINS=$(getFlag "ENABLE_PLUGINS")
fi

# ------------------------------------------------------------
# 6. BUILD SERVICE LIST
# ------------------------------------------------------------
ARRBIT_SERVICES=()
if [[ "${ENABLE_PLUGINS,,}" == "true" ]]; then
  ARRBIT_SERVICES+=("plugins.bash")
fi
if [[ "${ENABLE_AUTOCONFIG,,}" == "true" ]]; then
  ARRBIT_SERVICES+=("autoconfig.bash")
fi

# ------------------------------------------------------------
# 7. EXECUTE SERVICES
# ------------------------------------------------------------
for script in "${ARRBIT_SERVICES[@]}"; do
  service_path="$SERVICE_DIR/services/$script"
  if [ -x "$service_path" ]; then
    log "🚀  ${ARRBIT_TAG} Running $script..."
    bash "$service_path"
    ret=$?
    if [ $ret -ne 0 ]; then
      log "❌  ${ARRBIT_TAG} $script exited with errors!"
    else
      log "✅  ${ARRBIT_TAG} $script completed successfully."
    fi
  else
    log "⏩  ${ARRBIT_TAG} $script not found or not executable; skipping."
  fi
done

# ------------------------------------------------------------
# 8. DONE — SLEEP FOREVER
# ------------------------------------------------------------
log "📄  ${ARRBIT_TAG} Log saved to $log_file_path"
log "✅  ${ARRBIT_TAG} All enabled services processed."

sleep infinity

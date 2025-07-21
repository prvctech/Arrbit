#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [start]
# Version: v1.7
# Purpose: Launches Arrbit services based on config flags. Installs dependencies from local copy. Supervises service modules.
# -------------------------------------------------------------------------------------------------------------

set +e

# ------------------------------------------------------------
# 0. ENV and PATHS (constants)
# ------------------------------------------------------------
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
SETUP_DIR="$SERVICE_DIR/setup"
SCRIPT_NAME="start"
logFilePath="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%d-%m-%Y-%H:%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# ------------------------------------------------------------
# LOGGING FUNCTIONS: emoji/color on STDOUT, plain in log file
# ------------------------------------------------------------
logRaw() {
  local msg="$1"
  msg=$(echo -e "$msg" | tr -d "🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴💾")
  msg=$(echo -e "$msg" | sed -E "s/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g")
  msg=$(echo -e "$msg" | sed -E "s/^[[:space:]]+\[Arrbit\]/[Arrbit]/")
  echo "$msg" >> "$logFilePath"
}

log() {
  echo -e "$1"
  logRaw "$1"
}

# ------------------------------------------------------------
# 1. INIT LOG FILE
# ------------------------------------------------------------
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +2 -delete
touch "$logFilePath"
chmod 777 "$logFilePath"

# ------------------------------------------------------------
# 2. CHECK MASTER ARRBIT ENABLE FLAG
# ------------------------------------------------------------
ENABLE_ARRBIT="true"
if [ -f "$CONFIG_DIR/arrbit-config.conf" ]; then
  ENABLE_ARRBIT=$(grep -E '^ENABLE_ARRBIT=' "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g')
fi

if [[ "${ENABLE_ARRBIT,,}" != "true" ]]; then
  log "⚠️   ${ARRBIT_TAG} Arrbit is OFF."
  log "⚠️   ${ARRBIT_TAG} \033[1;33mBefore starting, enable Arrbit by setting ENABLE_ARRBIT=\"true\" in /config/arrbit/arrbit-config.conf.\033[0m"
  log "⚠️   ${ARRBIT_TAG} \033[1;33mAll services are off by default—customize as needed.\033[0m"
  sleep infinity
fi

# ------------------------------------------------------------
# 3. INSTALL DEPENDENCIES IF PRESENT
# ------------------------------------------------------------
if [ -f "$SETUP_DIR/dependencies.bash" ]; then
  chmod 777 "$SETUP_DIR/dependencies.bash"
  bash "$SETUP_DIR/dependencies.bash"
  if [ $? -ne 0 ]; then
    log "❌  ${ARRBIT_TAG} dependencies.bash script failed! Exiting."
    exit 1
  fi
else
  log "⚠️   ${ARRBIT_TAG} dependencies.bash not found in setup/. Skipping dependency install."
fi

# ------------------------------------------------------------
# 4. PARSE ENABLE FLAGS FROM CONFIG
# ------------------------------------------------------------
ENABLE_AUTOCONFIG="true"
ENABLE_PLUGINS="false"
if [ -f "$CONFIG_DIR/arrbit-config.conf" ]; then
  ENABLE_AUTOCONFIG=$(grep -E '^ENABLE_AUTOCONFIG=' "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g')
  ENABLE_PLUGINS=$(grep -E '^ENABLE_PLUGINS=' "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g')
fi

# ------------------------------------------------------------
# 5. BUILD SERVICE EXECUTION LIST
# ------------------------------------------------------------
ARRBIT_SERVICES=()
if [[ "${ENABLE_PLUGINS,,}" == "true" ]]; then
  ARRBIT_SERVICES+=("plugins.bash")
fi
if [[ "${ENABLE_AUTOCONFIG,,}" == "true" ]]; then
  ARRBIT_SERVICES+=("autoconfig.bash")
fi

# ------------------------------------------------------------
# 6. EXECUTE ENABLED SERVICES (from /services/)
# ------------------------------------------------------------
for script in "${ARRBIT_SERVICES[@]}"; do
  if [ -x "$SERVICE_DIR/services/$script" ]; then  
    bash "$SERVICE_DIR/services/$script"
    if [ $? -ne 0 ]; then
      log "❌  ${ARRBIT_TAG} $script exited with errors!"
    fi
  else
    log "⏩  ${ARRBIT_TAG} $script not found or not executable; skipping."
  fi
done

# ------------------------------------------------------------
# 7. FINAL LOGS & SLEEP FOREVER
# ------------------------------------------------------------
log "📄  ${ARRBIT_TAG} Log saved to $logFilePath"
log "✅  ${ARRBIT_TAG} All enabled services processed."

sleep infinity

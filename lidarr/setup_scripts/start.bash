#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [start]
# Version: 1.4
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
logFilePath="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# ------------------------------------------------------------
# LOGGING FUNCTIONS (Golden Standard)
# ------------------------------------------------------------
logRaw() {
  local stripped
  stripped=$(echo -e "$1" | sed -E $'s/(\\x1B|\\033)\\[[0-9;]*[a-zA-Z]//g; s/[🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴]//g; s/\\\\n/\\\n/g; s/^[[:space:]]+\\[Arrbit\\]/[Arrbit]/')
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
# 1. CHECK MASTER ARRBIT ENABLE FLAG
# ------------------------------------------------------------
ENABLE_ARRBIT="true"
if [ -f "$CONFIG_DIR/arrbit-config.conf" ]; then
    ENABLE_ARRBIT=$(grep -E '^ENABLE_ARRBIT=' "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g')
fi

if [[ "${ENABLE_ARRBIT,,}" != "true" ]]; then
    log "⚠️   \033[1;33m$ARRBIT_TAG Arrbit is OFF.\033[0m
\033[1;33mBefore starting, enable Arrbit by setting ENABLE_ARRBIT=\"true\" in /config/arrbit/arrbit-config.conf.\033[0m
\033[1;33mAll services are off by default—customize as needed.\033[0m"

    exit 1
fi

# ------------------------------------------------------------
# 2. INSTALL/UPDATE DEPENDENCIES (LOCAL ONLY, from setup/)
# ------------------------------------------------------------
if [ -f "$SETUP_DIR/dependencies.bash" ]; then
  chmod 777 "$SETUP_DIR/dependencies.bash"
  bash "$SETUP_DIR/dependencies.bash"
  if [ $? -ne 0 ]; then
    log "❌  $ARRBIT_TAG Dependencies script failed! Exiting."
    exit 1
  fi
else
  log "⚠️  $ARRBIT_TAG dependencies.bash not found locally in setup/. Skipping dependency install."
fi

# ------------------------------------------------------------
# 3. PARSE FLAGS FROM CONFIG (robust: strip quotes, spaces, newlines)
# ------------------------------------------------------------
ENABLE_AUTOCONFIG="true"
ENABLE_PLUGINS="false"
if [ -f "$CONFIG_DIR/arrbit-config.conf" ]; then
    ENABLE_AUTOCONFIG=$(grep -E '^ENABLE_AUTOCONFIG=' "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g')
    ENABLE_PLUGINS=$(grep -E '^ENABLE_PLUGINS=' "$CONFIG_DIR/arrbit-config.conf" | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g')
fi

# ------------------------------------------------------------
# 4. BUILD SERVICES TO RUN BASED ON FLAGS
# ------------------------------------------------------------
ARRBIT_SERVICES=()
if [[ "${ENABLE_AUTOCONFIG,,}" == "true" ]]; then
    ARRBIT_SERVICES+=("autoconfig.bash")
fi
if [[ "${ENABLE_PLUGINS,,}" == "true" ]]; then
    ARRBIT_SERVICES+=("plugins.bash")
fi

# ------------------------------------------------------------
# 5. EXECUTE EACH ENABLED SERVICE SCRIPT (DEFENSIVE)
# ------------------------------------------------------------
for script in "${ARRBIT_SERVICES[@]}"; do
    if [ -x "$SERVICE_DIR/$script" ]; then
        log "🚀  $ARRBIT_TAG Running $script..."
        bash "$SERVICE_DIR/$script"
        if [ $? -ne 0 ]; then
          log "❌  $ARRBIT_TAG $script exited with errors!"
        fi
    else
        log "⏩  $ARRBIT_TAG $script not found or not executable, skipping."
    fi
done

# ------------------------------------------------------------
# 6. FINAL LOG AND SLEEP FOREVER (containerized best practice)
# ------------------------------------------------------------
log "📄  $ARRBIT_TAG Log saved to $logFilePath"
log "✅  $ARRBIT_TAG All enabled services processed."

exit 0

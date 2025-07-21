#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [autoconfig]
# Version: v2.4
# Purpose: Orchestrates Arrbit modules to configure Lidarr, only if enabled in config.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
MODULES_DIR="modules"

rawScriptName="autoconfig"
scriptName="autoconfig"
scriptVersion="v2.4"

# ------------------------------------------------------------
# 1. Logging Setup
# ------------------------------------------------------------
logfileSetup() {
  timestamp=$(date +%d-%m-%Y-%H:%M)
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="${LOG_DIR}/${logFileName}"
  mkdir -p "${LOG_DIR}"
  find "${LOG_DIR}" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

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

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}${scriptName} service\033[0m $scriptVersion..."

# ------------------------------------------------------------
# 2. Config Flag Check
# ------------------------------------------------------------
ENABLE_AUTOCONFIG="1"
if [ -f "$CONFIG_FILE" ]; then
  ENABLE_AUTOCONFIG=$(awk -F= '$1=="ENABLE_AUTOCONFIG"{print $2}' "$CONFIG_FILE" | tr -d '\r' || echo "1")
fi

if [ "$ENABLE_AUTOCONFIG" != "1" ] && [[ ! "${ENABLE_AUTOCONFIG,,}" =~ ^(true|yes)$ ]]; then
  log "⏩  ${ARRBIT_TAG} autoconfig is disabled. Skipping."
  exit 0
fi

# ------------------------------------------------------------
# 3. Load Shared Functions
# ------------------------------------------------------------
if [ -f "$MODULES_DIR/functions.bash" ]; then
  source "$MODULES_DIR/functions.bash"
else
  log "❌  ${ARRBIT_TAG} functions.bash missing in modules/. Aborting."
  exit 1
fi

# ------------------------------------------------------------
# 4. Run Enabled Modules
# ------------------------------------------------------------
MODULES_TO_RUN=(
  "custom_formats.bash"
  "custom_scripts.bash"
  "delay_profiles.bash"
  "media_management.bash"
  "metadata_consumer.bash"
  "metadata_plugin.bash"
  "metadata_profiles.bash"
  "metadata_write.bash"
  "quality_profile.bash"
  "track_naming.bash"
  "ui_settings.bash"
)

EXIT_CODE=0

for module in "${MODULES_TO_RUN[@]}"; do
  module_name="${module%.bash}"
  module_path="$MODULES_DIR/$module"
  flag_var="ENABLE_${module_name^^}"

  if [ "${!flag_var:-1}" -eq 0 ]; then
    log "⏩  ${ARRBIT_TAG} Skipping $module_name (flag disabled)"
    continue
  fi

  if [ -f "$module_path" ]; then
    log "🔄  ${ARRBIT_TAG} Running $module_name..."
    module_output=$(bash "$module_path" 2>&1)
    log "$module_output"
    if [ $? -ne 0 ]; then
      log "❌  ${ARRBIT_TAG} $module_name failed"
      EXIT_CODE=1
    else
      log "✅  ${ARRBIT_TAG} $module_name complete"
    fi
  else
    log "⚠️   ${ARRBIT_TAG} $module_name missing, skipping"
  fi
done

# ------------------------------------------------------------
# 5. Wrap Up
# ------------------------------------------------------------
log "📄  ${ARRBIT_TAG} Log saved to $logFilePath"
log "✅  ${ARRBIT_TAG} Done with ${MODULE_YELLOW}${scriptName}\033[0m service!"

exit $EXIT_CODE

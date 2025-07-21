#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [autoconfig]
# Version: v3.3
# Purpose: Orchestrates Arrbit modules to configure Lidarr, Readarr, etc., based on config flags.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
SERVICE_DIR="/etc/services.d/arrbit"
MODULES_DIR="$SERVICE_DIR/modules"

scriptName="autoconfig"
scriptVersion="v3.3"
rawScriptName="autoconfig"

# ------------------------------------------------------------
# 1. Logging Setup
# ------------------------------------------------------------
logfileSetup() {
  timestamp=$(date +%Y_%m_%d-%H_%M)
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
log "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}${scriptName}\033[0m service $scriptVersion..."

# ------------------------------------------------------------
# 2. Master Flag Check: ENABLE_AUTOCONFIG must be "true"
# ------------------------------------------------------------
ENABLE_AUTOCONFIG="true"
if [ -f "$CONFIG_FILE" ]; then
  ENABLE_AUTOCONFIG=$(awk -F= '$1=="ENABLE_AUTOCONFIG"{print $2}' "$CONFIG_FILE" | tr -d '\r"[:space:]')
fi

if [[ "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  log "⏩  ${ARRBIT_TAG} autoconfig is disabled by flag. Skipping service."
  exit 0
fi

# ------------------------------------------------------------
# 3. Execute arr_bridge.bash remotely
# ------------------------------------------------------------
curl -sSfL https://raw.githubusercontent.com/prvctech/Arrbit/refs/heads/main/connectors/arr_bridge.bash | bash
if [ $? -ne 0 ]; then
  log "❌  ${ARRBIT_TAG} Failed to execute remote arr_bridge.bash!"
  exit 1
fi

# ------------------------------------------------------------
# 4. Load CONFIGURE_* flags
# ------------------------------------------------------------
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# ------------------------------------------------------------
# 5. Check if all modules are disabled
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

enabledCount=0
for module in "${MODULES_TO_RUN[@]}"; do
  module_name="${module%.bash}"
  flag_var="CONFIGURE_${module_name^^}"
  if [ "${!flag_var:-true}" == "true" ]; then
    ((enabledCount++))
  fi
done

if [ "$enabledCount" -eq 0 ]; then
  log "⏩  ${ARRBIT_TAG} All modules are disabled. Skipping service (even though ENABLE_AUTOCONFIG is true)."
  exit 0
fi

# ------------------------------------------------------------
# 6. Run Each Enabled Module
# ------------------------------------------------------------
EXIT_CODE=0
for module in "${MODULES_TO_RUN[@]}"; do
  module_name="${module%.bash}"
  module_path="$MODULES_DIR/$module"
  flag_var="CONFIGURE_${module_name^^}"

  if [ "${!flag_var:-true}" != "true" ]; then
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
# 7. Wrap Up
# ------------------------------------------------------------
log "📄  ${ARRBIT_TAG} Log saved to $logFilePath"
log "✅  ${ARRBIT_TAG} Done with ${MODULE_YELLOW}${scriptName}\033[0m service!"

exit $EXIT_CODE

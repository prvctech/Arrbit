#!/usr/bin/env bash
# ------------------------------------------------------------
# Arrbit [autoconfig]
# Version: 2.1
# Purpose: Orchestrates Arrbit modules to configure Lidarr, only if enabled in config.
# ------------------------------------------------------------

set +e

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULES_DIR="modules"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
LOG_DIR="/config/logs"

rawScriptName="autoconfig"
scriptName="autoconfig module"
scriptVersion="v2.1"

# Log setup
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="${LOG_DIR}/${logFileName}"
  mkdir -p "${LOG_DIR}"
  find "${LOG_DIR}" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

log() {
  echo -e "$1"
  logRaw "$1"
}

logRaw() {
  local stripped
  stripped=$(echo -e "$1" \
    | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' \
    | sed -E 's/\033\[[0-9;]*m//g' \
    | sed -E 's/[🔵🟢⚠️📥📄⏩🚀✅❌🔧🔴🟪🟦🟩🟥📁📦]//g' \
    | sed -E 's/\\n/\n/g' \
    | sed -E 's/^[[:space:]]+\[Arrbit\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

# Check ENABLE_AUTOCONFIG flag in config (default to 1 if missing)
ENABLE_AUTOCONFIG=1
if [ -f "$CONFIG_FILE" ]; then
    ENABLE_AUTOCONFIG=$(grep -E '^ENABLE_AUTOCONFIG=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r')
fi

if [ "$ENABLE_AUTOCONFIG" != "1" ] && [[ ! "${ENABLE_AUTOCONFIG,,}" =~ ^(true|yes)$ ]]; then
    log "⏭️   $ARRBIT_TAG autoconfig is disabled by config flag. Exiting."
    exit 0
fi

# Always source functions for utility/log helpers
if [ -f "$MODULES_DIR/functions.bash" ]; then
    source "$MODULES_DIR/functions.bash"
else
    log "❌  $ARRBIT_TAG functions.bash missing! Aborting autoconfig."
    exit 1
fi

# List of modules to run
MODULES_TO_RUN=(
    "media_management.bash"
    "metadata_write.bash"
    "metadata_profiles.bash"
    "metadata_consumer.bash"
    "metadata_plugin.bash"
    "track_naming.bash"
    "ui_settings.bash"
    "custom_scripts.bash"
    "custom_formats.bash"
    "delay_profiles.bash"
    "quality_profile.bash"
)

# Run each module, skip if disabled or missing
for module in "${MODULES_TO_RUN[@]}"; do
    module_name="${module%.bash}"  # Remove extension for nice logs
    module_path="$MODULES_DIR/$module"

    # Flag check for each module (optional, expects variables like ENABLE_MEDIA_MANAGEMENT, etc.)
    flag_var="ENABLE_${module_name^^}"
    if [ "${!flag_var:-1}" -eq 0 ]; then
        log "⏭️   $ARRBIT_TAG Skipping $module_name (flag disabled)"
        continue
    fi

    if [ -f "$module_path" ]; then
        if ! bash "$module_path" | tee -a "$logFilePath"; then
            log "❌  $ARRBIT_TAG $module_name failed"
        else
            log "✅  $ARRBIT_TAG $module_name complete"
        fi
    else
        log "⚠️   $ARRBIT_TAG $module_name missing, skipping"
    fi
done

log "📄  $ARRBIT_TAG Log saved to $logFilePath"
log "✅  $ARRBIT_TAG Done with ${rawScriptName}!"
exit 0

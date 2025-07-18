#!/usr/bin/env bash
# ------------------------------------------------------------
# Arrbit [autoconfig]
# Version: 2.2
# Purpose: Orchestrates Arrbit modules to configure Lidarr, per config flags.
# ------------------------------------------------------------

set +e

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULES_DIR="modules"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
LOG_DIR="/config/logs"

rawScriptName="autoconfig"
scriptName="autoconfig module"
scriptVersion="v2.2"

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

# Always source functions for utility/log helpers
if [ -f "$MODULES_DIR/functions.bash" ]; then
    source "$MODULES_DIR/functions.bash"
else
    log "❌  $ARRBIT_TAG functions.bash missing! Aborting autoconfig."
    exit 1
fi

# Parse all CONFIGURE_* flags from config into environment
if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        if [[ $key == CONFIGURE_* ]]; then
            export "$key"="$(echo "$value" | tr -d '\r')"
        fi
    done < <(grep -E '^CONFIGURE_' "$CONFIG_FILE")
fi

# List of modules to run, using CONFIGURE_ flags if present
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

# Run each module, skip if CONFIGURE_* flag is set to false
for module in "${MODULES_TO_RUN[@]}"; do
    module_name="${module%.bash}"  # Remove extension for logs
    module_path="$MODULES_DIR/$module"
    config_flag="CONFIGURE_${module_name^^}"

    # Only run module if config flag is not set to "false"
    if [[ "${!config_flag:-true}" =~ ^[Ff][Aa][Ll][Ss][Ee]$ ]]; then
        log "⏭️   $ARRBIT_TAG Skipping $module_name (config flag ${config_flag}=false)"
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

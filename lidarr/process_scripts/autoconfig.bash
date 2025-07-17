#!/usr/bin/with-contenv bash
#
# Arrbit auto-configuration script
# Version: v2.1
# Author: prvctech
# Purpose: Run module configurations in Lidarr based on arrbit-config.conf flags
# ---------------------------------------------

set -euo pipefail

# Setup script identity and constants
rawScriptName="autoconfig"
scriptName="autoconfig script"
scriptVersion="v2.1"
ARRBIT_TAG="[Arrbit]"
ARRBIT_CONF="/config/arrbit/config/arrbit-config.conf"

# ---------------------------------------------------------------------
# Log setup (terminal + raw file)
# ---------------------------------------------------------------------
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
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
    | sed -E 's/\\033\[[0-9;]*m//g' \
    | sed -E 's/[🔵🟢⚠️📥📄⏩🚀✅❌🔧🔴🟪🟦🟩🟥📁📦✨]//g' \
    | sed -E 's/\\n/\n/g' \
    | sed -E 's/^[[:space:]]+\[Arrbit\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

logfileSetup

# ---------------------------------------------------------------------
# Begin execution
# ---------------------------------------------------------------------
if [ ! -f "$ARRBIT_CONF" ]; then
  log "✨  ${ARRBIT_TAG} arrbit-config.conf not found at $ARRBIT_CONF. Exiting."
  exit 1
fi

source "$ARRBIT_CONF"
log "✨  ${ARRBIT_TAG} Starting ${scriptName} ${scriptVersion}..."

# Master toggle
if [ "${ENABLE_AUTOCONFIG:-false}" != "true" ]; then
  log "✨  ${ARRBIT_TAG} Auto-configuration disabled (ENABLE_AUTOCONFIG=${ENABLE_AUTOCONFIG}). Exiting."
  exit 0
fi

# ---------------------------------------------------------------------
# Function to run a module
# ---------------------------------------------------------------------
run_module() {
  local module_name="$1"
  local flag="$2"
  local script_path="/config/arrbit/process_scripts/modules/${module_name}.bash"
  local pretty_name="${module_name//_/ }"

  if [ "${flag,,}" = "true" ]; then
    if bash "$script_path"; then
      logRaw "[SUCCESS] ${pretty_name} applied via ${script_path}"
    else
      log "✨  ${ARRBIT_TAG} ${pretty_name}.bash failed"
      logRaw "[FAILURE] ${pretty_name} failed to apply"
    fi
  else
    log "✨  ${ARRBIT_TAG} Skipping ${pretty_name} (flag disabled)"
    logRaw "[SKIP] ${pretty_name} not run (flag disabled)"
  fi
}

# ---------------------------------------------------------------------
# Run all modules
# ---------------------------------------------------------------------
run_module "media_management"        "${CONFIGURE_MEDIA_MANAGEMENT:-false}"
run_module "metadata_consumer"       "${CONFIGURE_METADATA_CONSUMER:-false}"
run_module "metadata_write"          "${CONFIGURE_METADATA_WRITE:-false}"
run_module "metadata_plugin"         "${CONFIGURE_METADATA_PLUGIN:-false}"
run_module "metadata_profiles"       "${CONFIGURE_METADATA_PROFILES:-false}"
run_module "track_naming"            "${CONFIGURE_TRACK_NAMING:-false}"
run_module "ui_settings"             "${CONFIGURE_UI_SETTINGS:-false}"
run_module "custom_scripts"          "${CONFIGURE_CUSTOM_SCRIPTS:-false}"
run_module "custom_formats"          "${CONFIGURE_CUSTOM_FORMATS:-false}"
run_module "delay_profiles"          "${CONFIGURE_DELAY_PROFILES:-false}"
run_module "quality_profile"         "${CONFIGURE_QUALITY_PROFILE:-false}"

# ---------------------------------------------------------------------
# Done!
# ---------------------------------------------------------------------
log "✨  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✨  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

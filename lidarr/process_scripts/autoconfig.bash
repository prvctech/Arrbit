#!/usr/bin/env bash
#
# Arrbit auto-configuration script
# Version: v1.9
# Author: prvctech
# Purpose: Run module configurations in Lidarr based on arrbit-config.conf flags
# ---------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

ARRBIT_CONF="/config/arrbit/config/arrbit-config.conf"
if [ ! -f "$ARRBIT_CONF" ]; then
  echo -e "⚠️  ${ARRBIT_TAG} ERROR: arrbit-config.conf not found at $ARRBIT_CONF. Exiting."
  exit 1
fi

source "$ARRBIT_CONF"

timestamp=$(date +"%Y_%m_%d-%H_%M")
logFileName="arrbit-autoconfig-${timestamp}.log"
logFilePath="/config/logs/${logFileName}"
mkdir -p /config/logs
touch "$logFilePath"
chmod 666 "$logFilePath"

log() {
  local m_time
  m_time=$(date "+%F %T")
  echo -e "${m_time} :: autoconfig :: v1.9 :: $1" | tee -a "$logFilePath"
}

log "🚀  ${ARRBIT_TAG} Starting auto-configuration run"

# Master toggle
if [ "${ENABLE_AUTOCONFIG:-false}" != "true" ]; then
  log "⏩  ${ARRBIT_TAG} Auto-configuration disabled (ENABLE_AUTOCONFIG=${ENABLE_AUTOCONFIG}). Exiting."
  exit 0
fi

# -----------------------------------------------------------------------------
# Function to run each module
# -----------------------------------------------------------------------------
run_module() {
  local module_name="$1"
  local flag="$2"
  local script_path="/config/arrbit/process_scripts/modules/${module_name}.bash"

  if [ "${flag,,}" = "true" ]; then
    log "📥  ${ARRBIT_TAG} Configuring ${module_name//_/ }..."
    if bash "$script_path"; then
      log "✅  ${ARRBIT_TAG} ${module_name//_/ } completed"
    else
      log "⚠️  ${ARRBIT_TAG} ${module_name//_/ }.bash failed"
    fi
  else
    log "⏩  ${ARRBIT_TAG} Skipping ${module_name//_/ } (flag disabled)"
  fi
}

# Combined override for quality profile + custom formats
QUAL_FLAG="false"
if [ "${CONFIGURE_CUSTOM_FORMATS,,}" = "true" ] && [ "${CONFIGURE_QUALITY_PROFILE,,}" = "true" ]; then
  QUAL_FLAG="true"
fi

# -----------------------------------------------------------------------------
# Modules execution
# -----------------------------------------------------------------------------
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

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Auto-configuration run complete!"
exit 0

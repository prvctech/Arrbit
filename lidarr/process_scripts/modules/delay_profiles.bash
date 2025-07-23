#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - delay_profiles.bash
# Version: v2.0
# Purpose: Configure Lidarr delay profiles via API (Golden Standard, no internal flag checks).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="delay_profiles"
SCRIPT_VERSION="v2.0"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# Banner log (yellow for module name, only first log)
log_info "${YELLOW}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

# Determine which delay profile JSON to use (plugin flags)
ENABLE_COMMUNITY_PLUGINS=$(getFlag "ENABLE_COMMUNITY_PLUGINS")
INSTALL_PLUGIN_TIDAL=$(getFlag "INSTALL_PLUGIN_TIDAL")
INSTALL_PLUGIN_DEEZER=$(getFlag "INSTALL_PLUGIN_DEEZER")
INSTALL_PLUGIN_TUBIFARRY=$(getFlag "INSTALL_PLUGIN_TUBIFARRY")

if [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
      "${INSTALL_PLUGIN_TIDAL,,}" == "true" && \
      "${INSTALL_PLUGIN_DEEZER,,}" == "true" && \
      "${INSTALL_PLUGIN_TUBIFARRY,,}" == "true" ]]; then
  log_info "Using Delay Profile: Tidal, Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
        "${INSTALL_PLUGIN_TIDAL,,}" != "true" && \
        "${INSTALL_PLUGIN_DEEZER,,}" == "true" ]]; then
  log_info "Using Delay Profile: Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
        "${INSTALL_PLUGIN_TIDAL,,}" != "true" && \
        "${INSTALL_PLUGIN_DEEZER,,}" != "true" ]]; then
  log_info "Using Delay Profile: Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" != "true" ]]; then
  log_info "Using Delay Profile: Usenet, Torrent only"
  DELAY_JSON='...your payload here...'
else
  log_error "No matching delay profile conditions found. Skipping."
  exit 0
fi

# Apply the selected delay profile
log_info "Applying Delay Profile..."
if arr_api -X PUT --data-raw "${DELAY_JSON}" "${arrUrl}/api/v1/delayProfile" >/dev/null; then
  log_info "Delay Profiles module completed!"
else
  log_error "Failed to apply Delay Profile. (Check API connectivity and payload)"
fi

exit 0

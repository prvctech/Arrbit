#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - delay_profiles.bash
# Version: v2.1-gs2.6
# Purpose: Configure Lidarr delay profiles via API (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Source logging and helpers (Golden Standard order)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="delay_profiles"
SCRIPT_VERSION="v2.1-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

# Determine which delay profile JSON to use (plugin flags)
ENABLE_COMMUNITY_PLUGINS=$(getFlag "ENABLE_PLUGINS")
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
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# Apply the selected delay profile
log_info "Applying Delay Profile..."
log_info "Delay profile payload written to log file (sanitized)"
printf '[Arrbit] Delay Profile payload:\n%s\n' "$DELAY_JSON" | arrbitLogClean >> "$LOG_FILE"

if arr_api -X PUT --data-raw "${DELAY_JSON}" "${arrUrl}/api/v1/delayProfile" >/dev/null; then
  log_info "Delay Profiles module completed!"
else
  log_error "Failed to apply Delay Profile. (Check API connectivity and payload)"
fi

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

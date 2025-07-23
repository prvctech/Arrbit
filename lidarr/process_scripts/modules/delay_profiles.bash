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
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}delay_profiles module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API, sets arr_api)
# ------------------------------------------------------------------------
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Determine which delay profile JSON to use (plugin flags)
# All flag reading and profile selection is here, but no module/on/off logic
# ------------------------------------------------------------------------
ENABLE_COMMUNITY_PLUGINS=$(getFlag "ENABLE_COMMUNITY_PLUGINS")
INSTALL_PLUGIN_TIDAL=$(getFlag "INSTALL_PLUGIN_TIDAL")
INSTALL_PLUGIN_DEEZER=$(getFlag "INSTALL_PLUGIN_DEEZER")
INSTALL_PLUGIN_TUBIFARRY=$(getFlag "INSTALL_PLUGIN_TUBIFARRY")

if [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
      "${INSTALL_PLUGIN_TIDAL,,}" == "true" && \
      "${INSTALL_PLUGIN_DEEZER,,}" == "true" && \
      "${INSTALL_PLUGIN_TUBIFARRY,,}" == "true" ]]; then
  log_info "${ARRBIT_TAG} Using Delay Profile: Tidal, Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
        "${INSTALL_PLUGIN_TIDAL,,}" != "true" && \
        "${INSTALL_PLUGIN_DEEZER,,}" == "true" ]]; then
  log_info "${ARRBIT_TAG} Using Delay Profile: Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
        "${INSTALL_PLUGIN_TIDAL,,}" != "true" && \
        "${INSTALL_PLUGIN_DEEZER,,}" != "true" ]]; then
  log_info "${ARRBIT_TAG} Using Delay Profile: Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" != "true" ]]; then
  log_info "${ARRBIT_TAG} Using Delay Profile: Usenet, Torrent only"
  DELAY_JSON='...your payload here...'
else
  log_error "${ARRBIT_TAG} No matching delay profile conditions found. Skipping." \
    "No delay profile match" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Could not determine delay profile" \
    "Check your config flags"
  exit 0
fi

# ------------------------------------------------------------------------
# Apply the selected delay profile
# ------------------------------------------------------------------------
log_info "${ARRBIT_TAG} Applying Delay Profile..."
if arr_api -X PUT --data-raw "${DELAY_JSON}" "${arrUrl}/api/v1/delayProfile" >/dev/null; then
  log_info "${ARRBIT_TAG} Delay Profiles module completed!"
else
  log_error "${ARRBIT_TAG} Failed to apply Delay Profile." \
    "Delay profile PUT failed" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Delay Profile update failed" \
    "Check API connectivity and payload"
fi

exit 0

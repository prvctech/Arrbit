#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit delay_profiles.bash
# Version: v1.2
# Purpose: Configure Lidarr delay profiles based on plugin flags (Golden Standard).
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="delay_profiles"
SCRIPT_VERSION="v1.2"
LOG_DIR="/config/logs"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
CYAN="\033[1;36m"
RESET="\033[0m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}delay_profiles module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API)
# ------------------------------------------------------------------------
if ! source /etc/services.d/arrbit/connectors/arr_bridge.bash; then
  arrbitErrorLog "❌  " \
    "${CYAN}[Arrbit]${RESET} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Flag checks (always use getFlag for config)
# ------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
: "${ENABLE_AUTOCONFIG:=false}"
if [[ "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} Auto-configuration disabled. Skipping delay_profiles module."
  exit 0
fi

CFG_FLAG=$(getFlag "CONFIGURE_DELAY_PROFILES")
: "${CFG_FLAG:=true}"
if [[ "${CFG_FLAG,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} Skipping delay_profiles module (flag disabled)"
  exit 0
fi

# ------------------------------------------------------------------------
# Assemble JSON payload based on plugin flags
# ------------------------------------------------------------------------
ENABLE_COMMUNITY_PLUGINS=$(getFlag "ENABLE_COMMUNITY_PLUGINS")
INSTALL_PLUGIN_TIDAL=$(getFlag "INSTALL_PLUGIN_TIDAL")
INSTALL_PLUGIN_DEEZER=$(getFlag "INSTALL_PLUGIN_DEEZER")
INSTALL_PLUGIN_TUBIFARRY=$(getFlag "INSTALL_PLUGIN_TUBIFARRY")

if [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
      "${INSTALL_PLUGIN_TIDAL,,}" == "true" && \
      "${INSTALL_PLUGIN_DEEZER,,}" == "true" && \
      "${INSTALL_PLUGIN_TUBIFARRY,,}" == "true" ]]; then
  arrbitLog "🛎️  ${ARRBIT_TAG} Using Delay Profile: Tidal, Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
        "${INSTALL_PLUGIN_TIDAL,,}" != "true" && \
        "${INSTALL_PLUGIN_DEEZER,,}" == "true" ]]; then
  arrbitLog "🛎️  ${ARRBIT_TAG} Using Delay Profile: Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" == "true" && \
        "${INSTALL_PLUGIN_TIDAL,,}" != "true" && \
        "${INSTALL_PLUGIN_DEEZER,,}" != "true" ]]; then
  arrbitLog "🛎️  ${ARRBIT_TAG} Using Delay Profile: Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='...your payload here...'
elif [[ "${ENABLE_COMMUNITY_PLUGINS,,}" != "true" ]]; then
  arrbitLog "🛎️  ${ARRBIT_TAG} Using Delay Profile: Usenet, Torrent only"
  DELAY_JSON='...your payload here...'
else
  arrbitErrorLog "⚠️  " \
    "${CYAN}[Arrbit]${RESET} No matching delay profile conditions found. Skipping." \
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
arrbitLog "⚙️  ${ARRBIT_TAG} Applying Delay Profile..."
if curl -sfX PUT \
      -H "X-Api-Key: ${arrApiKey}" \
      -H "Content-Type: application/json" \
      --data-raw "${DELAY_JSON}" \
      "${arrUrl}/api/v1/delayProfile"; then
  arrbitLog "✅  ${ARRBIT_TAG} Delay Profiles module completed!"
else
  arrbitErrorLog "⚠️  " \
    "${CYAN}[Arrbit]${RESET} Failed to apply Delay Profile." \
    "Delay profile PUT failed" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Delay Profile update failed" \
    "Check API connectivity and payload"
fi

exit 0

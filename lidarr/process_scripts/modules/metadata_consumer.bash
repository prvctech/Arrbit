#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_consumer.bash
# Version: v2.3
# Purpose: Configure Lidarr Metadata Consumer (Kodi/XBMC) via API (Golden Standard, no internal flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="metadata_consumer"
SCRIPT_VERSION="v2.3"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}metadata_consumer module${RESET} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

log_info "[Arrbit] Configuring Metadata Consumer (Kodi/XBMC)..."

payload='{
  "enable": true,
  "name": "Kodi (XBMC) / Emby",
  "fields": [
    {"name": "artistMetadata", "value": true},
    {"name": "albumMetadata", "value": true},
    {"name": "artistImages", "value": true},
    {"name": "albumImages", "value": true}
  ],
  "implementationName": "Kodi (XBMC) / Emby",
  "implementation": "XbmcMetadata",
  "configContract": "XbmcMetadataSettings",
  "infoLink": "https://wiki.servarr.com/lidarr/supported#xbmcmetadata",
  "tags": [],
  "id": 1
}'

# Log payload and response to file ONLY
echo "[Arrbit] Metadata Consumer payload:" >> "$LOG_FILE"
echo "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/metadata/1?apikey=${arrApiKey}"
)

echo "[Arrbit] API Response:" >> "$LOG_FILE"
echo "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.enable' >/dev/null 2>&1; then
  log_info "[Arrbit] Metadata Consumer configured"
else
  log_error "[Arrbit] Metadata Consumer API call failed" \
    "Metadata Consumer API failure" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Metadata Consumer response did not validate" \
    "Check ARR API connectivity and payload"
fi

log_info "[Arrbit] Done with metadata_consumer module!"
exit 0

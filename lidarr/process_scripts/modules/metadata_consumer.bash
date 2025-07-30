#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_consumer.bash
# Version: v2.4-gs2.6
# Purpose: Configure Lidarr Metadata Consumer (Kodi/XBMC) via API (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Source logging and helpers (Golden Standard order)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="metadata_consumer"
SCRIPT_VERSION="v2.4-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

log_info "Configuring Metadata Consumer (Kodi/XBMC)..."

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

# Log sanitized payload to file only (never include secrets)
log_info "Metadata Consumer payload written to log file (sanitized)"
printf '[Arrbit] Metadata Consumer payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/metadata/1?apikey=${arrApiKey}"
)

# Log sanitized API response to file only
log_info "API response written to log file (sanitized)"
printf '[Arrbit] API Response:\n%s\n' "$response" | arrbitLogClean >> "$LOG_FILE"

if echo "$response" | jq -e '.enable' >/dev/null 2>&1; then
  log_info "Metadata Consumer configured"
else
  log_error "Metadata Consumer API call failed (response did not validate, check ARR API connectivity and payload)"
fi

#log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

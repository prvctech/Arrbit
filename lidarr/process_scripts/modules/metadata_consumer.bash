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

# Log payload and response to file ONLY (no color codes)
printf '[Arrbit] Metadata Consumer payload:\n%s\n' "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/metadata/1?apikey=${arrApiKey}"
)

printf '[Arrbit] API Response:\n%s\n' "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.enable' >/dev/null 2>&1; then
  log_info "Metadata Consumer configured"
else
  log_error "Metadata Consumer API call failed (response did not validate, check ARR API connectivity and payload)"
fi

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

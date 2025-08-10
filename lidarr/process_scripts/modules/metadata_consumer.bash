#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_consumer.bash
# Version: v1.0-gs2.7.1
# Purpose: Configure Lidarr Metadata Consumer (Kodi/XBMC) via API (Golden Standard v2.7.1, minimal output)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="metadata_consumer"
SCRIPT_VERSION="v1.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not source arr_bridge.bash
[WHY]: arr_bridge.bash is missing or failed to source.
[FIX]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.
EOF
  exit 1
fi

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

printf '[Arrbit] Metadata Consumer payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/metadata/1"
)

printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

if echo "$response" | jq -e '.enable' >/dev/null 2>&1; then
  log_info "Metadata Consumer has been configured successfully"
else
  log_error "Metadata Consumer API call failed (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Metadata Consumer API call failed
[WHY]: API response did not validate (.enable missing)
[FIX]: Check ARR API connectivity and payload structure. See [API Response] section above for details.
[API Response]
$response
[/API Response]
EOF
fi

log_info "Done."
exit 0

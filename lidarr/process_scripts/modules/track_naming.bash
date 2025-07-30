#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - track_naming.bash
# Version: v1.0-gs2.7
# Purpose: Configure Lidarr Track Naming profile via API (Golden Standard v2.7 compliant).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="track_naming"
SCRIPT_VERSION="v1.0-gs2.7"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  printf '[Arrbit] ERROR Could not source arr_bridge.bash\n[WHAT]: arr_bridge.bash is missing or failed to source\n[WHY]: Script not present or path misconfigured\n[HOW]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.\n' | arrbitLogClean >> "$LOG_FILE"
  exit 1
fi

payload='{
  "renameTracks": true,
  "replaceIllegalCharacters": true,
  "standardTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
  "multiDiscTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
  "artistFolderFormat": "{Artist CleanName} {(Artist Disambiguation)}",
  "includeArtistName": false,
  "includeAlbumTitle": false,
  "includeQuality": false,
  "replaceSpaces": false,
  "id": 1
}'

printf '[Arrbit] Track Naming payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/naming?apikey=${arrApiKey}"
)

printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

if echo "$response" | jq -e '.renameTracks' >/dev/null 2>&1; then
  log_info "Track Naming has been configured successfully"
else
  log_error "Track Naming API call failed (see log at /config/logs)"
  printf '[Arrbit] ERROR Track Naming API call failed\n[WHAT]: Failed to configure Lidarr Track Naming\n[WHY]: API response did not validate (.renameTracks missing)\n[HOW]: Check ARR API connectivity and payload fields. See [API Response] section above for details.\n[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
fi

log_info "Done."
exit 0

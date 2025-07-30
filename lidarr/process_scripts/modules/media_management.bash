#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - media_management.bash
# Version: v2.7-gs2.7
# Purpose: Configure Lidarr Media Management settings via API (Golden Standard v2.7, minimal output)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="media_management"
SCRIPT_VERSION="v2.7-gs2.7"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  printf '[Arrbit] ERROR Could not source arr_bridge.bash\n[WHAT]: arr_bridge.bash is missing or failed to source\n[WHY]: Script not present or path misconfigured\n[HOW]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.\n' | arrbitLogClean >> "$LOG_FILE"
  exit 1
fi

payload='{
  "autoUnmonitorPreviouslyDownloadedTracks": false,
  "recycleBin": "",
  "recycleBinCleanupDays": 7,
  "downloadPropersAndRepacks": "doNotPrefer",
  "createEmptyArtistFolders": true,
  "deleteEmptyFolders": true,
  "fileDate": "albumReleaseDate",
  "watchLibraryForChanges": false,
  "rescanAfterRefresh": "always",
  "allowFingerprinting": "newFiles",
  "setPermissionsLinux": false,
  "chmodFolder": "777",
  "chownGroup": "",
  "skipFreeSpaceCheckWhenImporting": false,
  "minimumFreeSpaceWhenImporting": 100,
  "copyUsingHardlinks": true,
  "importExtraFiles": true,
  "extraFileExtensions": "jpg,png,lrc",
  "id": 1
}'

printf '[Arrbit] Media Management payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/mediamanagement?apikey=${arrApiKey}"
)

printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

if echo "$response" | jq -e '.downloadPropersAndRepacks' >/dev/null 2>&1; then
  log_info "Media Management settings have been applied successfully"
else
  log_error "Media Management API call failed (see log at /config/logs)"
  printf '[Arrbit] ERROR Media Management API call failed\n[WHAT]: Failed to update Lidarr Media Management settings\n[WHY]: API response did not validate (.downloadPropersAndRepacks missing)\n[HOW]: Check ARR API connectivity and payload structure. See [API Response] section above for details.\n[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
fi

log_info "Done."
exit 0

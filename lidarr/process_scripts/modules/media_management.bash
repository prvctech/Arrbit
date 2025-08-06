#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - media_management.bash
# Version: v1.0-gs2.7.1
# Purpose: Configure Lidarr Media Management settings via API (Golden Standard v2.7.1, minimal output)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="media_management"
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
    "${arrUrl}/api/${arrApiVersion}/config/mediamanagement"
)

printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

if echo "$response" | jq -e '.downloadPropersAndRepacks' >/dev/null 2>&1; then
  log_info "Media Management settings have been applied successfully"
else
  log_error "Media Management API call failed (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Media Management API call failed
[WHY]: API response did not validate (.downloadPropersAndRepacks missing)
[FIX]: Check ARR API connectivity and payload structure. See [API Response] section above for details.
[API Response]
$response
[/API Response]
EOF
fi

log_info "Done."
exit 0

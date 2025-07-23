#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - media_management.bash
# Version: v2.2
# Purpose: Configure Lidarr Media Management settings via API (Golden Standard, no internal flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="media_management"
SCRIPT_VERSION="v2.2"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}media_management module${RESET} ${SCRIPT_VERSION}..."

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

log_info "${ARRBIT_TAG} Configuring Media Management..."

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

# Log payload and response to file ONLY
echo "[Arrbit] Media Management payload:" >> "$LOG_FILE"
echo "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/mediamanagement?apikey=${arrApiKey}"
)

echo "[Arrbit] API Response:" >> "$LOG_FILE"
echo "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.downloadPropersAndRepacks' >/dev/null 2>&1; then
  log_info "${ARRBIT_TAG} Media Management settings have been applied successfully"
else
  log_error "${ARRBIT_TAG} Media Management API call failed" \
    "Media Management API failure" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Media Management response did not validate" \
    "Check ARR API connectivity and payload"
fi

log_info "${ARRBIT_TAG} Done with media_management module!"
exit 0

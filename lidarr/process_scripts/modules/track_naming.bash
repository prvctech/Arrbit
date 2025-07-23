#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - track_naming.bash
# Version: v2.10
# Purpose: Configure Lidarr Track Naming profile via API (Golden Standard, no internal flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="track_naming"
SCRIPT_VERSION="v2.10"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}track_naming module${RESET} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (includes wait for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "track_naming.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

log_info "${ARRBIT_TAG} Configuring Track Naming..."

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

# Log payload and response to file ONLY
echo "[Arrbit] Track Naming payload:" >> "$LOG_FILE"
echo "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/naming?apikey=${arrApiKey}"
)

echo "[Arrbit] API Response:" >> "$LOG_FILE"
echo "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.renameTracks' >/dev/null 2>&1; then
  log_info "${ARRBIT_TAG} Track Naming has been configured successfully"
else
  log_error "${ARRBIT_TAG} Track Naming API call failed" \
    "Track Naming API failure" \
    "track_naming.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Track Naming response did not validate" \
    "Check ARR API connectivity and payload"
fi

log_info "${ARRBIT_TAG} Done with track_naming module!"
exit 0

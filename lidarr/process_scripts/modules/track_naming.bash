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

CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

# Golden Standard: override log_info/log_error
log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# Banner (module/script names in yellow for the first log only)
log_info "${YELLOW}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (includes wait for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

log_info "Configuring Track Naming..."

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

# Log payload and response to file ONLY (no color codes)
printf '[Arrbit] Track Naming payload:\n%s\n' "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/naming?apikey=${arrApiKey}"
)

printf '[Arrbit] API Response:\n%s\n' "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.renameTracks' >/dev/null 2>&1; then
  log_info "Track Naming has been configured successfully"
else
  log_error "Track Naming API call failed (response did not validate, check ARR API connectivity and payload)"
fi

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

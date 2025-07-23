#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_write.bash
# Version: v2.3
# Purpose: Configure Lidarr Metadata Write Provider via API (Golden Standard, no internal flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="metadata_write"
SCRIPT_VERSION="v2.3"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

# Golden Standard log_info/log_error overrides
log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# Banner log (module name in yellow, first log only)
log_info "${YELLOW}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

log_info "Configuring Metadata Write Provider..."

payload='{
  "writeAudioTags": "newFiles",
  "scrubAudioTags": false,
  "id": 1
}'

# Log payload and response to file ONLY (no color codes)
printf '[Arrbit] Metadata Write Provider payload:\n%s\n' "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/metadataProvider?apikey=${arrApiKey}"
)

printf '[Arrbit] API Response:\n%s\n' "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.writeAudioTags' >/dev/null 2>&1; then
  log_info "Metadata Write Provider has been configured successfully"
else
  log_error "Metadata Write API call failed (response did not validate, check ARR API connectivity and payload)"
fi

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

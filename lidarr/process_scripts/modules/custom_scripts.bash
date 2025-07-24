#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_scripts.bash
# Version: v2.2
# Purpose: Register tagger.bash as Lidarr custom script (Golden Standard compliant, no flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="custom_scripts"
SCRIPT_VERSION="v2.2"
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

# Register arrbit-tagger as Lidarr custom script if not present
if ! arr_api "${arrUrl}/api/${arrApiVersion}/notification" | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then
  log_info "Registering arrbit-tagger script"

payload='{
  "name": "arrbit-tagger",
  "implementation": "CustomScript",
  "configContract": "CustomScriptSettings",
  "onReleaseImport": true,
  "onUpgrade": true,
  "fields": [
    { "name": "path", "value": "/config/arrbit/custom/tagger.bash" }
  ]
}'

  # Log payload and response only to file
  printf '[Arrbit] Registering arrbit-tagger\n[Payload]\n%s\n[/Payload]\n' "$payload" >> "$LOG_FILE"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}")

  printf '[Response]\n%s\n[/Response]\n' "$response" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS arrbit-tagger registered\n' >> "$LOG_FILE"
  else
    log_error "Failed to register arrbit-tagger script"
    printf '[Arrbit] ERROR Failed to register arrbit-tagger\n' >> "$LOG_FILE"
  fi
else
  log_info "arrbit-tagger already registered; skipping"
  printf '[Arrbit] SKIP arrbit-tagger already exists\n' >> "$LOG_FILE"
fi

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v2.2
# Purpose: Import custom formats from JSON into Lidarr. Golden Standard compliant.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="custom_formats"
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

JSON_PATH="/config/arrbit/modules/data/custom_formats_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH}"
  printf '[Arrbit] ERROR: custom_formats_master.json not found at %s\n' "$JSON_PATH" >> "$LOG_FILE"
  exit 1
fi

log_info "Reading custom formats from: ${JSON_PATH}"

existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')

  # Only log payload/response to file
  printf '[Arrbit] Format: %s\n[Payload]\n%s\n[/Payload]\n' "$format_name" "$payload" >> "$LOG_FILE"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "Custom format already exists, skipping: ${format_name}"
    printf '[Arrbit] SKIP Custom format already exists: %s\n' "$format_name" >> "$LOG_FILE"
    continue
  fi

  log_info "Importing custom format: ${format_name}"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}")

  printf '[Response]\n%s\n[/Response]\n' "$response" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Custom format created: %s\n' "$format_name" >> "$LOG_FILE"
  else
    log_error "Failed to import format: ${format_name}"
    printf '[Arrbit] ERROR Failed to create custom format: %s\n' "$format_name" >> "$LOG_FILE"
  fi
done

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

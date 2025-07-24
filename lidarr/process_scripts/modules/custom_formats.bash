#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v2.3-gs2.6
# Purpose: Import custom formats from JSON into Lidarr (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Golden Standard: log_utils first, then helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="custom_formats"
SCRIPT_VERSION="v2.3-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
JSON_PATH="/config/arrbit/modules/data/custom_formats_master.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH}"
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

log_info "Reading custom formats from: ${JSON_PATH}"
printf '[Arrbit] Reading custom formats from: %s\n' "$JSON_PATH" | arrbitLogClean >> "$LOG_FILE"

existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')

  # Removed "Processing..." message to reduce terminal clutter

  # Log payload only to file
  printf '[Arrbit] Format: %s\n[Payload]\n%s\n[/Payload]\n' "$format_name" "$payload" | arrbitLogClean >> "$LOG_FILE"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "Custom format already exists, skipping: ${format_name}"
    printf '[Arrbit] SKIP Custom format already exists: %s\n' "$format_name" | arrbitLogClean >> "$LOG_FILE"
    continue
  fi

  log_info "Importing custom format: ${format_name}"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}")

  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Custom format created: %s\n' "$format_name" | arrbitLogClean >> "$LOG_FILE"
  else
    log_error "Failed to import format: ${format_name}"
    printf '[Arrbit] ERROR Failed to create custom format: %s\n' "$format_name" | arrbitLogClean >> "$LOG_FILE"
  fi
done

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

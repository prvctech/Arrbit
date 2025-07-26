#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v2.4-gs2.6
# Purpose: Import custom formats from JSON into Lidarr (Golden Standard v2.6, with quiet skip logic)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="custom_formats"
SCRIPT_VERSION="v2.4-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
JSON_PATH="/config/arrbit/modules/data/payload-custom_formats.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

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

# Get all existing custom format names, lowercase
existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

# Pass 1: check if ALL exist
all_exist=true
mapfile -t JSON_FORMATS < <(jq -c '.[]' "$JSON_PATH")
for format in "${JSON_FORMATS[@]}"; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  if ! echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    all_exist=false
    break
  fi
done

if $all_exist; then
  log_info "Custom formats already present - skipping."
  printf '[Arrbit] Custom formats already present - skipping.\n' | arrbitLogClean >> "$LOG_FILE"
  log_info "Done with ${SCRIPT_NAME} module!"
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# Pass 2: only import missing
for format in "${JSON_FORMATS[@]}"; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')
  printf '[Arrbit] Format: %s\n[Payload]\n%s\n[/Payload]\n' "$format_name" "$payload" | arrbitLogClean >> "$LOG_FILE"
  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
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

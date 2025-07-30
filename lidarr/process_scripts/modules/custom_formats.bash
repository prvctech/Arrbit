#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v2.7-gs2.7
# Purpose: Import custom formats from JSON into Lidarr (Golden Standard v2.7, ultra-minimal output)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="custom_formats"
SCRIPT_VERSION="v2.7-gs2.7"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
JSON_PATH="/config/arrbit/modules/data/payload-custom_formats.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  printf '[Arrbit] ERROR Could not source arr_bridge.bash\n[WHAT]: arr_bridge.bash is missing or failed to source\n[WHY]: Script not present or path misconfigured\n[HOW]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.\n' | arrbitLogClean >> "$LOG_FILE"
  exit 1
fi

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH} (see log at /config/logs)"
  printf '[Arrbit] ERROR File not found: %s\n[WHAT]: Could not find required payload JSON file\n[WHY]: The file does not exist at the specified path\n[HOW]: Place a valid payload-custom_formats.json in %s\n' "$JSON_PATH" "$(dirname "$JSON_PATH")" | arrbitLogClean >> "$LOG_FILE"
  exit 1
fi

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
  log_info "Custom formats already exists - skipping."
  log_info "Done."
  exit 0
fi

# Pass 2: only import missing
for format in "${JSON_FORMATS[@]}"; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')
  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    continue
  fi
  log_info "Importing custom format: ${format_name}"
  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Custom format created: %s\n' "$format_name" | arrbitLogClean >> "$LOG_FILE"
  else
    log_error "Failed to import format: ${format_name} (see log at /config/logs)"
    printf '[Arrbit] ERROR Failed to create custom format: %s\n[WHAT]: Could not import custom format: %s\n[WHY]: API failed to return an id. Likely cause: payload invalid or API/server error.\n[HOW]: Check payload JSON fields for correctness, or see [Response] section below for more info.\n[Response]\n%s\n[/Response]\n' "$format_name" "$format_name" "$response" | arrbitLogClean >> "$LOG_FILE"
  fi
done

log_info "Done."
exit 0

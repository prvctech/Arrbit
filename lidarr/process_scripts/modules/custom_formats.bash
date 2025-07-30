#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v1-gs2.7
# Purpose: Import custom formats from JSON into Lidarr (Golden Standard v2.7, ultra-minimal output)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="custom_formats"
SCRIPT_VERSION="v1-gs2.7"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
JSON_PATH="/config/arrbit/modules/data/payload-custom_formats.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

log_info "Starting ${SCRIPT_NAME} module ${SCRIPT_VERSION}..."

# Source arr_bridge for API variables and arr_api wrapper (may overwrite LOG_FILE)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not source arr_bridge.bash
[WHAT]: arr_bridge.bash is missing or failed to source
[WHY]: Script not present or path misconfigured
[HOW]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.
EOF
  exit 1
fi

# --- CRITICAL! Restore LOG_FILE for this module ---
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH} (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR File not found: $JSON_PATH
[WHAT]: Could not find required payload JSON file
[WHY]: The file does not exist at the specified path
[HOW]: Place a valid payload-custom_formats.json in $(dirname "$JSON_PATH")
EOF
  exit 1
fi

# Get all existing custom format names, lowercase (guard for empty response)
existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')
if [[ -z "$existing_names" ]]; then
  log_error "Failed to retrieve existing custom format names (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not retrieve custom format list from API
[WHAT]: Failed to query custom formats from Lidarr
[WHY]: API may be unreachable or returned invalid data
[HOW]: Check your Lidarr API status and network connection.
EOF
  exit 1
fi

# Read all custom formats from JSON
mapfile -t JSON_FORMATS < <(jq -c '.[]' "$JSON_PATH")

# Check if all exist already
all_exist=true
for format in "${JSON_FORMATS[@]}"; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  if ! echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    all_exist=false
    break
  fi
done

if $all_exist; then
  log_info "Custom formats already exist - skipping."
  log_info "Done."
  exit 0
fi

# Import only missing formats
for format in "${JSON_FORMATS[@]}"; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')
  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    continue
  fi
  log_info "Importing custom format: ${format_name}"
  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/customformat")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Custom format created: %s\n' "$format_name" | arrbitLogClean >> "$LOG_FILE"
  else
    log_error "Failed to import format: ${format_name} (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to create custom format: $format_name
[WHAT]: Could not import custom format: $format_name
[WHY]: API failed to return an id. Likely cause: payload invalid or API/server error.
[HOW]: Check payload JSON fields for correctness, or see [Response] section below for more info.
[Response]
$response
[/Response]
EOF
  fi
done

log_info "Done."
exit 0

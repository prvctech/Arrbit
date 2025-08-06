#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v2.0-gs2.7.1
# Purpose: Import custom formats from JSON into Lidarr (Golden Standard v2.7.1 strict)
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="custom_formats"
SCRIPT_VERSION="v2.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Source required helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/config_utils.bash

arrbitPurgeOldLogs

# Banner (only one echo allowed)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- 1. Source arr_bridge for API variables and arr_api wrapper ---
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not source arr_bridge.bash
[WHY]: arr_bridge.bash is missing or failed to source.
[FIX]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.
EOF
  exit 1
fi

# --- 2. Get module-specific configuration ---
# Get custom JSON path from YAML
JSON_PATH=$(get_yaml_value "autoconfig.paths.custom_formats_json")
if [[ -z "$JSON_PATH" || "$JSON_PATH" == "null" ]]; then
  JSON_PATH="/config/arrbit/modules/data/payload-custom_formats.json"
  log_info "Using default JSON path: $JSON_PATH"
else
  log_info "Using configured JSON path: $JSON_PATH"
fi

# --- 3. Check that payload JSON exists ---
if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH} (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR File not found: $JSON_PATH
[WHY]: The file does not exist at the specified path.
[FIX]: Place a valid payload-custom_formats.json in $(dirname "$JSON_PATH") or update the path in configuration:
      autoconfig:
        paths:
          custom_formats_json: "/path/to/your/custom_formats.json"
EOF
  exit 1
fi

# --- 4. Query custom formats API, robust error detection ---
log_info "Querying API for existing custom formats..."
api_response=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat")
if ! echo "$api_response" | jq . >/dev/null 2>&1; then
  log_error "Failed to parse custom format list from API (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Invalid response from Lidarr API for customformat
[WHY]: API unreachable, misconfigured, or returned invalid data.
[FIX]: Check your Lidarr API status, config, or permissions.
[Response]
$api_response
[/Response]
EOF
  exit 1
fi

# --- 5. Extract names (can be empty if no custom formats exist) ---
existing_names=$(echo "$api_response" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')
existing_count=$(echo "$existing_names" | grep -v '^$' | wc -l)
log_info "Found $existing_count existing custom formats"

# --- 6. Read all custom formats from JSON ---
log_info "Reading custom formats from JSON file: $JSON_PATH"
if ! mapfile -t JSON_FORMATS < <(jq -c '.[]' "$JSON_PATH" 2>/dev/null); then
  log_error "Failed to parse JSON file: $JSON_PATH (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to parse JSON file: $JSON_PATH
[WHY]: The file is not valid JSON or jq encountered an error.
[FIX]: Verify the JSON file is properly formatted.
EOF
  exit 1
fi

# --- 7. Check if all exist already ---
format_count=${#JSON_FORMATS[@]}
log_info "Found $format_count custom formats in JSON file"

if [[ $format_count -eq 0 ]]; then
  log_warning "No custom formats found in JSON file. Nothing to import."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

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
  log_info "All custom formats already exist - skipping."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# --- 8. Import only missing formats ---
log_info "Importing missing custom formats..."
success_count=0
failure_count=0

for format in "${JSON_FORMATS[@]}"; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  
  # Skip if format already exists
  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "Custom format already exists: ${format_name} - skipping"
    continue
  fi
  
  # Prepare payload (remove id field if present)
  payload=$(echo "$format" | jq 'del(.id)')
  
  # Import format
  log_info "Importing custom format: ${format_name}"
  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/customformat")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  
  # Check if import was successful
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    log_success "Custom format created: ${format_name}"
    printf '[Arrbit] SUCCESS Custom format created: %s\n' "$format_name" | arrbitLogClean >> "$LOG_FILE"
    ((success_count++))
  else
    log_error "Failed to import format: ${format_name} (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to create custom format: $format_name
[WHY]: API failed to return an id. Likely cause: payload invalid or API/server error.
[FIX]: Check payload JSON fields for correctness, or see [Response] section below for more info.
[Response]
$response
[/Response]
EOF
    ((failure_count++))
  fi
done

# --- 9. Log summary and exit ---
if [[ $success_count -gt 0 ]]; then
  log_success "Successfully imported $success_count custom format(s)"
fi

if [[ $failure_count -gt 0 ]]; then
  log_warning "Failed to import $failure_count custom format(s)"
fi

log_info "Log saved to $LOG_FILE"
log_info "Done with ${SCRIPT_NAME} module"
exit 0

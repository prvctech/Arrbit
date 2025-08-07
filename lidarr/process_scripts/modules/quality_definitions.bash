#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_definitions.bash
# Version: v2.1-gs2.7.1
# Purpose: Configure Lidarr Quality Definitions via API (Golden Standard v2.7.1 compliant)
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="quality_definitions"
SCRIPT_VERSION="v2.1-gs2.7.1"
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
# Get payload path from YAML if available, otherwise use default
PAYLOAD_PATH=$(get_yaml_value "autoconfig.paths.quality_definitions_payload")
if [[ -z "$PAYLOAD_PATH" || "$PAYLOAD_PATH" == "null" ]]; then
  PAYLOAD_PATH="/config/arrbit/modules/data/payload-quality_definitions.json"
fi

# --- 3. Check if payload file exists ---
if [[ ! -f "$PAYLOAD_PATH" ]]; then
  log_error "Payload file not found: ${PAYLOAD_PATH} (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Payload file not found: $PAYLOAD_PATH
[WHY]: The file does not exist at the specified path.
[FIX]: Place a valid payload-quality_definitions.json in $(dirname "$PAYLOAD_PATH") or update the path in configuration:
      autoconfig:
        paths:
          quality_definitions_payload: "/path/to/your/payload-quality_definitions.json"
EOF
  exit 1
fi

# --- 4. Read payload from file ---
# Log to file only, not terminal
payload=$(cat "$PAYLOAD_PATH")
printf '[Arrbit] Quality Definitions payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

# --- 5. Check if settings already match ---
# Log to file only, not terminal
printf '[Arrbit] Checking current quality definitions\n' | arrbitLogClean >> "$LOG_FILE"
current_settings=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualitydefinition")
printf '[Arrbit] Current settings:\n%s\n' "$current_settings" | arrbitLogClean >> "$LOG_FILE"

# Compare current settings with payload
# Note: Quality definitions are typically an array of quality items
if [[ $(echo "$payload" | jq 'type') == '"array"' ]]; then
  # Check if all quality definitions match
  all_match=true
  
  # Get the number of quality definitions in the payload
  quality_count=$(echo "$payload" | jq 'length')
  
  for ((i=0; i<quality_count; i++)); do
    quality_item=$(echo "$payload" | jq ".[$i]")
    quality_id=$(echo "$quality_item" | jq -r '.id')
    quality_name=$(echo "$quality_item" | jq -r '.quality.name')
    
    # Find the corresponding quality definition in current settings
    current_quality=$(echo "$current_settings" | jq ".[] | select(.quality.name == &quot;$quality_name&quot;)")
    
    if [[ -z "$current_quality" ]]; then
      all_match=false
      break
    fi
    
    # Compare the quality settings (ignoring id)
    current_quality_filtered=$(echo "$current_quality" | jq 'del(.id)')
    quality_item_filtered=$(echo "$quality_item" | jq 'del(.id)')
    
    if [[ "$current_quality_filtered" != "$quality_item_filtered" ]]; then
      all_match=false
      break
    fi
  done
  
  if $all_match; then
    log_info "Predefined settings already present. Skipping..."
    log_info "Log saved to $LOG_FILE"
    log_info "Done."
    exit 0
  fi
  
  # Update quality definitions
  log_info "Importing predefined settings."
  response=$(arr_api -X PUT --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualitydefinition/update")
  
  # Log response to file only, not terminal
  printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  
  # Check if operation was successful
  if [[ $(echo "$response" | jq 'length') -gt 0 ]]; then
    log_info "The module was configured successfully."
  else
    log_error "Quality Definitions API call failed (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Quality Definitions API call failed
[WHY]: API response did not validate (expected array of quality definitions)
[FIX]: Check ARR API connectivity and payload structure. See [API Response] section above for details.
[API Response]
$response
[/API Response]
EOF
    exit 1
  fi
else
  # Single quality definition (unusual, but handle it)
  quality_name=$(echo "$payload" | jq -r '.quality.name')
  quality_id=$(echo "$payload" | jq -r '.id')
  
  # Find the corresponding quality definition in current settings
  current_quality=$(echo "$current_settings" | jq ".[] | select(.quality.name == &quot;$quality_name&quot;)")
  
  if [[ -n "$current_quality" ]]; then
    # Compare the quality settings (ignoring id)
    current_quality_filtered=$(echo "$current_quality" | jq 'del(.id)')
    payload_filtered=$(echo "$payload" | jq 'del(.id)')
    
    if [[ "$current_quality_filtered" == "$payload_filtered" ]]; then
      log_info "Predefined settings already present. Skipping..."
      log_info "Log saved to $LOG_FILE"
      log_info "Done."
      exit 0
    fi
  }
  
  # Update the quality definition
  log_info "Importing predefined settings."
  response=$(arr_api -X PUT --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualitydefinition/$quality_id")
  
  # Log response to file only, not terminal
  printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  
  # Check if operation was successful
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    log_info "The module was configured successfully."
  else
    log_error "Quality Definition API call failed (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Quality Definition API call failed
[WHY]: API response did not validate (expected fields missing)
[FIX]: Check ARR API connectivity and payload structure. See [API Response] section above for details.
[API Response]
$response
[/API Response]
EOF
    exit 1
  fi
fi

# --- 6. Log completion and exit ---
log_info "Log saved to $LOG_FILE"
log_info "Done."
exit 0

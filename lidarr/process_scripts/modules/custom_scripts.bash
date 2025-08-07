#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_scripts.bash
# Version: v2.1-gs2.7.1
# Purpose: Configure Lidarr Custom Scripts via API (Golden Standard v2.7.1 compliant)
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="custom_scripts"
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
PAYLOAD_PATH=$(get_yaml_value "autoconfig.paths.custom_scripts_payload")
if [[ -z "$PAYLOAD_PATH" || "$PAYLOAD_PATH" == "null" ]]; then
  PAYLOAD_PATH="/config/arrbit/modules/data/payload-custom_scripts_tagger.json"
fi

# --- 3. Check if payload file exists ---
if [[ ! -f "$PAYLOAD_PATH" ]]; then
  log_error "Payload file not found: ${PAYLOAD_PATH} (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Payload file not found: $PAYLOAD_PATH
[WHY]: The file does not exist at the specified path.
[FIX]: Place a valid payload-custom_scripts.json in $(dirname "$PAYLOAD_PATH") or update the path in configuration:
      autoconfig:
        paths:
          custom_scripts_payload: "/path/to/your/payload-custom_scripts.json"
EOF
  exit 1
fi

# --- 4. Read payload from file ---
# Log to file only, not terminal
payload=$(cat "$PAYLOAD_PATH")
printf '[Arrbit] Custom Scripts payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

# --- 5. Check if settings already match ---
# Log to file only, not terminal
printf '[Arrbit] Checking current custom scripts\n' | arrbitLogClean >> "$LOG_FILE"
current_scripts=$(arr_api "${arrUrl}/api/${arrApiVersion}/notification")
printf '[Arrbit] Current scripts:\n%s\n' "$current_scripts" | arrbitLogClean >> "$LOG_FILE"

# Parse the payload to determine if it's a single object or an array
if [[ $(echo "$payload" | jq 'type') == '"array"' ]]; then
  # It's an array of custom scripts
  # Check if all scripts already exist with the same settings
  all_exist=true
  script_count=$(echo "$payload" | jq 'length')
  
  for ((i=0; i<script_count; i++)); do
    script=$(echo "$payload" | jq ".[$i]")
    script_name=$(echo "$script" | jq -r '.name')
    
    # Check if script exists
    existing_script=$(echo "$current_scripts" | jq ".[] | select(.name == &quot;$script_name&quot;)")
    if [[ -z "$existing_script" ]]; then
      all_exist=false
      break
    fi
    
    # Compare settings (ignoring id)
    existing_without_id=$(echo "$existing_script" | jq 'del(.id)')
    script_without_id=$(echo "$script" | jq 'del(.id)')
    
    if [[ "$existing_without_id" != "$script_without_id" ]]; then
      all_exist=false
      break
    fi
  done
  
  if $all_exist; then
    log_info "Predefined settings already present. Skipping..."
    log_info "Log saved to $LOG_FILE"
    log_info "Done."
    exit 0
  fi
  
  # Import scripts
  log_info "Importing predefined settings."
  success_count=0
  failure_count=0
  
  for ((i=0; i<script_count; i++)); do
    script=$(echo "$payload" | jq ".[$i]")
    script_name=$(echo "$script" | jq -r '.name')
    
    # Check if script exists
    existing_script=$(echo "$current_scripts" | jq ".[] | select(.name == &quot;$script_name&quot;)")
    if [[ -n "$existing_script" ]]; then
      existing_id=$(echo "$existing_script" | jq -r '.id')
      
      # Update existing script
      log_info "Updating custom script: ${script_name}"
      response=$(arr_api -X PUT --data-raw "$script" "${arrUrl}/api/${arrApiVersion}/notification/$existing_id")
    else
      # Create new script
      log_info "Creating custom script: ${script_name}"
      script_without_id=$(echo "$script" | jq 'del(.id)')
      response=$(arr_api -X POST --data-raw "$script_without_id" "${arrUrl}/api/${arrApiVersion}/notification")
    fi
    
    # Log response to file only, not terminal
    printf '[API Response for %s]\n%s\n[/API Response]\n' "$script_name" "$response" | arrbitLogClean >> "$LOG_FILE"
    
    # Check if operation was successful
    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
      ((success_count++))
    else
      log_error "Failed to configure custom script: ${script_name} (see log at /config/logs)"
      ((failure_count++))
    fi
  done
  
  # Log summary
  if [[ $success_count -gt 0 && $failure_count -eq 0 ]]; then
    log_info "The module was configured successfully."
  elif [[ $failure_count -gt 0 ]]; then
    log_warning "Failed to configure $failure_count custom script(s)"
  fi
else
  # It's a single custom script
  script_name=$(echo "$payload" | jq -r '.name')
  
  # Check if script exists
  existing_script=$(echo "$current_scripts" | jq ".[] | select(.name == &quot;$script_name&quot;)")
  
  if [[ -n "$existing_script" ]]; then
    existing_id=$(echo "$existing_script" | jq -r '.id')
    
    # Compare settings (ignoring id)
    existing_without_id=$(echo "$existing_script" | jq 'del(.id)')
    payload_without_id=$(echo "$payload" | jq 'del(.id)')
    
    if [[ "$existing_without_id" == "$payload_without_id" ]]; then
      log_info "Predefined settings already present. Skipping..."
      log_info "Log saved to $LOG_FILE"
      log_info "Done."
      exit 0
    fi
    
    # Update existing script
    log_info "Importing predefined settings."
    response=$(arr_api -X PUT --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/notification/$existing_id")
  else
    # Create new script
    log_info "Importing predefined settings."
    payload_without_id=$(echo "$payload" | jq 'del(.id)')
    response=$(arr_api -X POST --data-raw "$payload_without_id" "${arrUrl}/api/${arrApiVersion}/notification")
  fi
  
  # Log response to file only, not terminal
  printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  
  # Check if operation was successful
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    log_info "The module was configured successfully."
  else
    log_error "Custom Scripts API call failed (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Custom Scripts API call failed
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

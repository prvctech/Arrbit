#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - ui_settings.bash
# Version: v2.1-gs2.7.1
# Purpose: Configure Lidarr UI settings via API (Golden Standard v2.7.1 compliant)
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="ui_settings"
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
PAYLOAD_PATH=$(get_yaml_value "autoconfig.paths.ui_settings_payload")
if [[ -z "$PAYLOAD_PATH" || "$PAYLOAD_PATH" == "null" ]]; then
  PAYLOAD_PATH="/config/arrbit/modules/data/payload-ui_settings.json"
fi

# --- 3. Check if payload file exists ---
if [[ ! -f "$PAYLOAD_PATH" ]]; then
  log_error "Payload file not found: ${PAYLOAD_PATH} (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Payload file not found: $PAYLOAD_PATH
[WHY]: The file does not exist at the specified path.
[FIX]: Place a valid payload-ui_settings.json in $(dirname "$PAYLOAD_PATH") or update the path in configuration:
      autoconfig:
        paths:
          ui_settings_payload: "/path/to/your/payload-ui_settings.json"
EOF
  exit 1
fi

# --- 4. Read payload from file ---
# Log to file only, not terminal
payload=$(cat "$PAYLOAD_PATH")
printf '[Arrbit] UI Settings payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

# --- 5. Check if settings already match ---
# Log to file only, not terminal
printf '[Arrbit] Checking current UI settings\n' | arrbitLogClean >> "$LOG_FILE"
current_settings=$(arr_api "${arrUrl}/api/${arrApiVersion}/config/ui")
printf '[Arrbit] Current settings:\n%s\n' "$current_settings" | arrbitLogClean >> "$LOG_FILE"

# Compare current settings with payload (ignoring id field)
current_without_id=$(echo "$current_settings" | jq 'del(.id)')
payload_without_id=$(echo "$payload" | jq 'del(.id)')

if [[ "$current_without_id" == "$payload_without_id" ]]; then
  log_info "Predefined settings already present. Skipping..."
  log_info "Log saved to $LOG_FILE"
  log_info "Done."
  exit 0
fi

# --- 6. Execute API call ---
log_info "Importing predefined settings."
response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/ui"
)

# Log response to file only, not terminal
printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

# --- 7. Check response ---
if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
  log_info "The module was configured successfully."
else
  log_error "UI Settings API call failed (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR UI Settings API call failed
[WHY]: API response did not validate (expected fields missing)
[FIX]: Check ARR API connectivity and payload structure. See [API Response] section above for details.
[API Response]
$response
[/API Response]
EOF
  exit 1
fi

# --- 8. Log completion and exit ---
log_info "Log saved to $LOG_FILE"
log_info "Done."
exit 0

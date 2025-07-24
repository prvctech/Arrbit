#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - ui_settings.bash
# Version: v1.1-gs2.5
# Purpose: Configure Lidarr UI Settings via API (Golden Standard 2.5 compliant).
# -------------------------------------------------------------------------------------------------------------

# Source logging and helpers (Golden Standard order)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

# Always purge old logs before anything else
arrbitPurgeOldLogs

# Set script constants
SCRIPT_NAME="ui_settings"
SCRIPT_VERSION="v1.1-gs2.5"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Ensure log directory exists and file is writable
mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner (first line only; GREEN in terminal, plain in log file)
echo -e "${GREEN}[Arrbit] Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (provides arr_api, arrUrl, arrApiKey, arrApiVersion)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

log_info "Configuring UI Settings..."

payload='{
  "firstDayOfWeek": 0,
  "calendarWeekColumnHeader": "ddd M/D",
  "shortDateFormat": "MMM D YYYY",
  "longDateFormat": "dddd, MMMM D YYYY",
  "timeFormat": "h(:mm)a",
  "showRelativeDates": true,
  "enableColorImpairedMode": true,
  "uiLanguage": 1,
  "expandAlbumByDefault": true,
  "expandSingleByDefault": true,
  "expandEPByDefault": true,
  "expandBroadcastByDefault": true,
  "expandOtherByDefault": true,
  "theme": "auto",
  "id": 1
}'

# Log sanitized payload to file only (never include secrets)
log_info "UI Settings payload written to log file (sanitized)"
printf '[Arrbit] UI Settings payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

# Make API call via arr_api (use real API key in the call)
response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/ui?apikey=${arrApiKey}"
)

# Log sanitized API response to file only
log_info "API response written to log file (sanitized)"
printf '[Arrbit] API Response:\n%s\n' "$response" | arrbitLogClean >> "$LOG_FILE"

# Check if API call was successful (theme field in response)
if echo "$response" | jq -e '.theme' >/dev/null 2>&1; then
  log_info "UI Settings have been configured successfully"
else
  log_error "UI Settings API call failed (response did not validate, check ARR API connectivity and payload)"
fi

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

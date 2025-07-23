#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - ui_settings.bash
# Version: v2.3
# Purpose: Configure Lidarr UI Settings via API (Golden Standard, no internal flag check, uses arr_api).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="ui_settings"
SCRIPT_VERSION="v2.3"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}ui_settings module${RESET} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

log_info "${ARRBIT_TAG} Configuring UI Settings..."

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

# Log payload and response to file ONLY
echo "[Arrbit] UI Settings payload:" >> "$LOG_FILE"
echo "$payload" >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/ui?apikey=${arrApiKey}"
)

echo "[Arrbit] API Response:" >> "$LOG_FILE"
echo "$response" >> "$LOG_FILE"

if echo "$response" | jq -e '.theme' >/dev/null 2>&1; then
  log_info "${ARRBIT_TAG} UI Settings have been configured successfully"
else
  log_error "${ARRBIT_TAG} UI Settings API call failed" \
    "UI Settings API failure" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "UI Settings response did not validate" \
    "Check ARR API connectivity and payload"
fi

log_info "${ARRBIT_TAG} Done with ui_settings module!"
exit 0

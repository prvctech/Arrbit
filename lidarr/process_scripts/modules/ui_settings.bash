#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - ui_settings.bash
# Version: v1.0-gs2.7
# Purpose: Configure Lidarr UI Settings via API (Golden Standard v2.7 compliant).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="ui_settings"
SCRIPT_VERSION="v1.0-gs2.7"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  printf '[Arrbit] ERROR Could not source arr_bridge.bash\n[WHAT]: arr_bridge.bash is missing or failed to source\n[WHY]: Script not present or path misconfigured\n[HOW]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.\n' | arrbitLogClean >> "$LOG_FILE"
  exit 1
fi

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

printf '[Arrbit] UI Settings payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

response=$(
  arr_api -X PUT --data-raw "$payload" \
    "${arrUrl}/api/${arrApiVersion}/config/ui?apikey=${arrApiKey}"
)

printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

if echo "$response" | jq -e '.theme' >/dev/null 2>&1; then
  log_info "UI Settings have been configured successfully"
else
  log_error "UI Settings API call failed (see log at /config/logs)"
  printf '[Arrbit] ERROR UI Settings API call failed\n[WHAT]: Failed to configure Lidarr UI settings\n[WHY]: API response did not validate (.theme missing)\n[HOW]: Check ARR API connectivity and payload fields. See [API Response] section above for details.\n[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
fi

log_info "Done."
exit 0

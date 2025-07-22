#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit ui_settings.bash
# Version: v2.1
# Purpose: Configure Lidarr UI Settings via API (Golden Standard).
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="ui_settings"
SCRIPT_VERSION="v2.1"
LOG_DIR="/config/logs"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
CYAN="\033[1;36m"
RESET="\033[0m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}ui_settings module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API)
# ------------------------------------------------------------------------
if ! source /etc/services.d/arrbit/connectors/arr_bridge.bash; then
  arrbitErrorLog "❌  " \
    "${CYAN}[Arrbit]${RESET} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Check CONFIGURE_UI_SETTINGS (always use flag helpers)
# ------------------------------------------------------------------------
CFG_FLAG=$(getFlag "CONFIGURE_UI_SETTINGS")
: "${CFG_FLAG:=true}"

if [[ "${CFG_FLAG,,}" == "true" ]]; then
  arrbitLog "📥  ${ARRBIT_TAG} Configuring UI Settings..."

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
  echo "[Arrbit] UI Settings payload:" >> "$log_file_path"
  echo "$payload" >> "$log_file_path"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/ui?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  echo "[Arrbit] API Response:" >> "$log_file_path"
  echo "$response" >> "$log_file_path"

  if echo "$response" | jq -e '.theme' >/dev/null 2>&1; then
    arrbitLog "✅  ${ARRBIT_TAG} UI Settings have been configured successfully"
  else
    arrbitErrorLog "⚠️  " \
      "${CYAN}[Arrbit]${RESET} UI Settings API call failed" \
      "UI Settings API failure" \
      "${SCRIPT_NAME}.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "UI Settings response did not validate" \
      "Check ARR API connectivity and payload"
  fi
else
  arrbitLog "⏩  ${ARRBIT_TAG} Skipping ui_settings module (flag disabled)"
fi

arrbitLog "✅  ${ARRBIT_TAG} Done with ui_settings module!"
exit 0

#!/usr/bin/env bash
#
# Arrbit Module - Configure UI Settings
# Version: v1.0
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

scriptName="ui_settings"
scriptVersion="v1.0"

# Setup log file
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${scriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${scriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

log() {
  local m_time
  m_time=$(date "+%F %T")
  echo -e "${m_time} :: ${scriptName} :: ${scriptVersion} :: $1" | tee -a "$logFilePath"
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting ${scriptName}.bash..."

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

# UI settings flag
if [[ "${CONFIGURE_UI_SETTINGS,,}" == "true" ]]; then
  log "📥  ${ARRBIT_TAG} Configuring UI Settings..."

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

  {
    echo -e "\n[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$payload"
    echo "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/ui?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  {
    echo -e "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$response"
    echo "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  if echo "$response" | jq -e '.theme' >/dev/null 2>&1; then
    log "✅  ${ARRBIT_TAG} UI Settings configured successfully"
  else
    log "⚠️  ${ARRBIT_TAG} UI Settings API call failed"
  fi
else
  log "⏩  ${ARRBIT_TAG} Skipping UI Settings"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

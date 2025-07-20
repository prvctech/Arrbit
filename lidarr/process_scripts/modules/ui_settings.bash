#!/usr/bin/env bash
#
# Arrbit Module - Configure UI Settings
# Version: v2.0
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

rawScriptName="$(basename "${BASH_SOURCE[0]}" .bash)"
scriptName="${rawScriptName//_/ } module"
scriptVersion="v2.0"

logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

log() {
  echo -e "$1"
  logRaw "$1"
}

logRaw() {
  local stripped
  stripped=$(echo -e "$1" \
    | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' \
    | sed -E 's/\\033\[[0-9;]*m//g' \
    | sed -E 's/[🔵🟢⚠️📥📄⏩🚀✅❌🔧🔴🟪🟦🟩🟥]//g' \
    | sed -E 's/\\n/\n/g' \
    | sed -E 's/^[[:space:]]+\[Arrbit\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

getArrAppInfo
verifyApiAccess

if [[ "${CONFIGURE_UI_SETTINGS,,}" == "true" ]]; then
  log "📥  ${ARRBIT_TAG} Configuring UI Settings..."
  logRaw "[Arrbit] Configuring UI Settings..."

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

  logRaw "[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$payload" >> "$logFilePath"
  logRaw "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/ui?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  logRaw "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$response" >> "$logFilePath"
  logRaw "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  if echo "$response" | jq -e '.theme' >/dev/null 2>&1; then
    logRaw "[SUCCESS] UI Settings updated"
    log "✅  ${ARRBIT_TAG} UI Settings have been configured successfully"
  else
    log "⚠️  ${ARRBIT_TAG} UI Settings API call failed"
    logRaw "[ERROR] Failed to apply UI Settings"
  fi
else
  log "⏩  ${ARRBIT_TAG} Skipping UI Settings"
  logRaw "[SKIP] CONFIGURE_UI_SETTINGS=false; skipping"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

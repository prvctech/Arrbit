#!/usr/bin/env bash
#
# Arrbit Module - Register tagger.bash as Lidarr custom script
# Version: v1.8
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared functions
source /config/arrbit/process_scripts/functions.bash

scriptName="custom_scripts"
scriptVersion="v1.8"

# Override logfileSetup for custom filename format
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${scriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${scriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

# Custom logger to both screen and log file
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

# Check if tagger.bash is already registered
if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
  | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then

  log "📥  ${ARRBIT_TAG} Registering arrbit-tagger (tagger.bash)..."

  # Define the JSON payload
  payload=$(cat <<EOF
{
  "name": "arrbit-tagger",
  "implementation": "CustomScript",
  "configContract": "CustomScriptSettings",
  "onReleaseImport": true,
  "onUpgrade": true,
  "fields": [
    { "name": "path", "value": "/config/arrbit/process_scripts/tagger.bash" }
  ]
}
EOF
)

  # Save raw payload and response to log (no emojis)
  {
    echo -e "\n[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$payload"
    echo -e "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
  } >> "$logFilePath"

  response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  {
    echo -e "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$response"
    echo -e "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
  } >> "$logFilePath"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    log "✅  ${ARRBIT_TAG} Registered arrbit-tagger script"
  else
    log "⚠️  ${ARRBIT_TAG} Failed to register arrbit-tagger script"
  fi

else
  log "⏩  ${ARRBIT_TAG} arrbit-tagger already registered; skipping"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

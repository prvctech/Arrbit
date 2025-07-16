#!/usr/bin/env bash
#
# Arrbit Module - Register tagger.bash as Lidarr custom script
# Version: v1.4
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared functions
source /config/arrbit/process_scripts/functions.bash

scriptName="custom_scripts"
scriptVersion="v1.4"

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

# Initialize log
logfileSetup
log "🟢  ${ARRBIT_TAG} Starting ${scriptName}.bash..."

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

# Register arrbit-tagger only if not already there
if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
  | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then

  log "🔧  ${ARRBIT_TAG} Registering arrbit-tagger (tagger.bash)..."

  curl -s -X POST "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw '{
      "name": "arrbit-tagger",
      "implementation": "CustomScript",
      "configContract": "CustomScriptSettings",
      "onReleaseImport": true,
      "onUpgrade": true,
      "fields": [
        { "name": "path", "value": "/config/arrbit/process_scripts/tagger.bash" }
      ]
    }' >> "$logFilePath" 2>&1

  if grep -q '"id":' "$logFilePath"; then
    log "✅  ${ARRBIT_TAG} Registered arrbit-tagger script"
  else
    log "❌  ${ARRBIT_TAG} Failed to register arrbit-tagger script"
  fi

else
  log "⏭️   ${ARRBIT_TAG} arrbit-tagger already registered; skipping"
fi

log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

#!/usr/bin/env bash
#
# Arrbit Module - Register tagger.bash as Lidarr custom script
# Version: v1.9
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared functions
source /config/arrbit/process_scripts/functions.bash

# Extract module name for display
rawScriptName="$(basename "${BASH_SOURCE[0]}" .bash)"
scriptName="${rawScriptName//_/ } module"
scriptVersion="v1.9"

# Logfile setup
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

# Clean logger
log() {
  echo -e "$1" | tee -a "$logFilePath"
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

# Check if arrbit-tagger already registered
if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
  | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then

  log "📥  ${ARRBIT_TAG} Registering arrbit-tagger (tagger.bash)..."

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

  {
    echo -e "\n[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$payload"
    echo "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  {
    echo -e "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$response"
    echo "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
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
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

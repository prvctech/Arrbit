#!/usr/bin/env bash
#
# Arrbit Module - Register tagger.bash as Lidarr custom script
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

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

# Check if already registered
if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
  | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then

  log "📥  ${ARRBIT_TAG} Registering arrbit-tagger script"

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

  logRaw "[Arrbit] Registering arrbit-tagger"
  logRaw "[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$payload" >> "$logFilePath"
  logRaw "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  logRaw "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$response" >> "$logFilePath"
  logRaw "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    logRaw "[SUCCESS] arrbit-tagger registered"
  else
    log "⚠️  ${ARRBIT_TAG} Failed to register arrbit-tagger script"
    logRaw "[ERROR] Failed to register arrbit-tagger"
  fi

else
  log "⏩  ${ARRBIT_TAG} arrbit-tagger already registered; skipping"
  logRaw "[SKIP] arrbit-tagger already exists"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Custom script has been registered successfully"
exit 0

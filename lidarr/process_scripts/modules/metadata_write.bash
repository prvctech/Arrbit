#!/usr/bin/env bash
#
# Arrbit Module - Configure Metadata Write Provider
# Version: v1.1
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

rawScriptName="$(basename "${BASH_SOURCE[0]}" .bash)"
scriptName="${rawScriptName//_/ } module"
scriptVersion="v1.1"

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
  echo -e "$1" | tee -a "$logFilePath"
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

if [[ "${CONFIGURE_METADATA_WRITE,,}" == "true" ]]; then
  log "📥  ${ARRBIT_TAG} Configuring Metadata Write Provider..."

  payload='{
    "writeAudioTags":"newFiles",
    "scrubAudioTags":false,
    "id":1
  }'

  {
    echo -e "\n[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$payload"
    echo "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/metadataProvider?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  {
    echo -e "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$response"
    echo "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  if echo "$response" | jq -e '.writeAudioTags' >/dev/null 2>&1; then
    log "✅  ${ARRBIT_TAG} Metadata Write Provider configured successfully"
  else
    log "⚠️  ${ARRBIT_TAG} Metadata Write API call failed"
  fi
else
  log "⏩  ${ARRBIT_TAG} Skipping Metadata Write Provider"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

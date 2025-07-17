#!/usr/bin/env bash
#
# Arrbit Module - Configure Metadata Write Provider
# Version: v1.0
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

scriptName="metadata_write"
scriptVersion="v1.0"

# Setup golden standard log file
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
log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

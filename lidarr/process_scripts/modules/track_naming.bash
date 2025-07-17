#!/usr/bin/env bash
#
# Arrbit Module - Configure Track Naming
# Version: v1.0
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared Arrbit functions
source /config/arrbit/process_scripts/functions.bash

scriptName="track_naming"
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

# Check flag before configuring
if [[ "${CONFIGURE_TRACK_NAMING,,}" == "true" ]]; then
  log "📥  ${ARRBIT_TAG} Configuring Track Naming..."

  payload='{
    "renameTracks": true,
    "replaceIllegalCharacters": true,
    "standardTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
    "multiDiscTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
    "artistFolderFormat": "{Artist CleanName} {(Artist Disambiguation)}",
    "includeArtistName": false,
    "includeAlbumTitle": false,
    "includeQuality": false,
    "replaceSpaces": false,
    "id": 1
  }'

  {
    echo -e "\n[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$payload"
    echo "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/naming?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  {
    echo -e "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$response"
    echo "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  if echo "$response" | jq -e '.renameTracks' >/dev/null 2>&1; then
    log "✅  ${ARRBIT_TAG} Track Naming configured successfully"
  else
    log "⚠️  ${ARRBIT_TAG} Track Naming API call failed"
  fi

else
  log "⏩  ${ARRBIT_TAG} Skipping Track Naming"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

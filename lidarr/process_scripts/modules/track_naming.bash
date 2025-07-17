#!/usr/bin/env bash
#
# Arrbit Module - Configure Track Naming
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
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

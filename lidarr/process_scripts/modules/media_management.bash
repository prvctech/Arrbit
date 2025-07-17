#!/usr/bin/env bash
#
# Arrbit Module - Configure Media Management Settings
# Version: v1.0
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

scriptName="media_management"
scriptVersion="v1.0"

# Logfile standard
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

if [[ "${CONFIGURE_MEDIA_MANAGEMENT,,}" == "true" ]]; then
  log "📥  ${ARRBIT_TAG} Configuring Media Management..."

  payload='{
    "autoUnmonitorPreviouslyDownloadedTracks":false,
    "recycleBin":"",
    "recycleBinCleanupDays":7,
    "downloadPropersAndRepacks":"doNotPrefer",
    "createEmptyArtistFolders":true,
    "deleteEmptyFolders":true,
    "fileDate":"albumReleaseDate",
    "watchLibraryForChanges":false,
    "rescanAfterRefresh":"always",
    "allowFingerprinting":"newFiles",
    "setPermissionsLinux":false,
    "chmodFolder":"777",
    "chownGroup":"",
    "skipFreeSpaceCheckWhenImporting":false,
    "minimumFreeSpaceWhenImporting":100,
    "copyUsingHardlinks":true,
    "importExtraFiles":true,
    "extraFileExtensions":"jpg,png,lrc",
    "id":1
  }'

  {
    echo -e "\n[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$payload"
    echo "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/mediamanagement?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  {
    echo -e "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$response"
    echo "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  } >> "$logFilePath"

  if echo "$response" | jq -e '.downloadPropersAndRepacks' >/dev/null 2>&1; then
    log "✅  ${ARRBIT_TAG} Media Management configured successfully"
  else
    log "⚠️  ${ARRBIT_TAG} Media Management API call failed"
  fi

else
  log "⏩  ${ARRBIT_TAG} Skipping Media Management"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

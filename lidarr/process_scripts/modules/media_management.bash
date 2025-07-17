#!/usr/bin/env bash
#
# Arrbit Module - Configure Media Management Settings
# Version: v1.2
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

# Dynamically format script name to look like "media management module"
rawScriptName="$(basename "${BASH_SOURCE[0]}" .bash)"
scriptName="${rawScriptName//_/ } module"
scriptVersion="v1.2"

# Golden standard log setup
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
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

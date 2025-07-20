#!/usr/bin/env bash
#
# Arrbit Module - Import metadata profiles from JSON into Lidarr
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

if [[ "${CONFIGURE_METADATA_PROFILES,,}" != "true" ]]; then
  log "⏩  ${ARRBIT_TAG} Skipping metadata profile import (flag disabled)"
  exit 0
fi

getArrAppInfo
verifyApiAccess

JSON_PATH="/config/arrbit/process_scripts/modules/json_values/metadata_profiles_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log "⚠️  ${ARRBIT_TAG} File not found: ${JSON_PATH}"
  logRaw "[ERROR] metadata_profiles_master.json not found at ${JSON_PATH}"
  exit 1
fi

log "📄  ${ARRBIT_TAG} Reading metadata profiles from: ${JSON_PATH}"
logRaw "[INFO] Reading JSON from: ${JSON_PATH}"

existing_names=$(curl -s "${arrUrl}/api/${arrApiVersion}/metadataprofile?apikey=${arrApiKey}" \
  | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r profile; do
  profile_name=$(echo "$profile" | jq -r '.name')
  profile_id=$(echo "$profile" | jq -r '.id')
  payload=$(echo "$profile" | jq 'del(.id)')
  lowercase_name=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]')

  logRaw "\n[START] Profile: $profile_name (ID: $profile_id)"
  logRaw "[ACTION] Checking if profile name already exists in Lidarr"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log "⏩  ${ARRBIT_TAG} Metadata profile already exists, skipping: ${profile_name}"
    logRaw "[SKIP] Profile already exists in Lidarr: $profile_name"
    continue
  fi

  log "📥  ${ARRBIT_TAG} Importing metadata profile: ${profile_name}"
  logRaw "[Arrbit] Importing metadata profile: $profile_name"
  logRaw "[CREATE] Sending POST to: ${arrUrl}/api/${arrApiVersion}/metadataprofile"

  logRaw "[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$payload" >> "$logFilePath"
  logRaw "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X POST "${arrUrl}/api/${arrApiVersion}/metadataprofile?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  logRaw "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$response" >> "$logFilePath"
  logRaw "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    logRaw "[SUCCESS] Metadata profile created: $profile_name"
  else
    log "⚠️  ${ARRBIT_TAG} Failed to create metadata profile: ${profile_name}"
    logRaw "[ERROR] Failed to create profile: $profile_name"
  fi
done

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} All metadata profiles have been imported successfully"
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

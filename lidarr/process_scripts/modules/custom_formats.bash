#!/usr/bin/env bash
#
# Arrbit Module - Import custom formats from JSON into Lidarr
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

getArrAppInfo
verifyApiAccess

JSON_PATH="/config/arrbit/process_scripts/modules/json_values/custom_formats_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log "⚠️  ${ARRBIT_TAG} File not found: ${JSON_PATH}"
  logRaw "[ERROR] custom_formats_master.json not found at ${JSON_PATH}"
  exit 1
fi

log "📄  ${ARRBIT_TAG} Reading custom formats from: ${JSON_PATH}"
logRaw "[INFO] Reading JSON from: ${JSON_PATH}"

existing_names=$(curl -s "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
  | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')
  format_id=$(echo "$format" | jq -r '.id')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')

  logRaw "\n[START] Format: $format_name (ID: $format_id)"
  logRaw "[ACTION] Checking if format name already exists in Lidarr"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log "⏩  ${ARRBIT_TAG} Format already exists, skipping: ${format_name}"
    logRaw "[SKIP] Custom format already exists in Lidarr: $format_name"
    continue
  fi

  log "📥  ${ARRBIT_TAG} Importing custom format: ${format_name}"
  logRaw "[Arrbit] Importing custom format: $format_name"
  logRaw "[CREATE] Sending POST to: ${arrUrl}/api/${arrApiVersion}/customformat"

  logRaw "[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$payload" >> "$logFilePath"
  logRaw "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    -d "$payload")

  logRaw "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "$response" >> "$logFilePath"
  logRaw "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    logRaw "[SUCCESS] Custom format created: $format_name"
  else
    log "⚠️  ${ARRBIT_TAG} Failed to import format: ${format_name}"
    logRaw "[ERROR] Failed to create custom format: $format_name"
  fi
done

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} All custom formats have been imported successfully"
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

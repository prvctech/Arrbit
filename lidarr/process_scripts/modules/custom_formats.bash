#!/usr/bin/env bash
#
# Arrbit Module - Import custom formats from JSON into Lidarr
# Version: v1.6
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Load Arrbit functions
source /config/arrbit/process_scripts/functions.bash

# Format module name: "custom formats module"
rawScriptName="$(basename "${BASH_SOURCE[0]}" .bash)"
scriptName="${rawScriptName//_/ } module"
scriptVersion="v1.6"

# Log setup
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

# Emoji-aligned logger
log() {
  echo -e "$1" | tee -a "$logFilePath"
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

# Custom formats file
JSON_PATH="/config/arrbit/process_scripts/modules/json_values/custom_formats_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log "⚠️  ${ARRBIT_TAG} File not found: ${JSON_PATH}"
  exit 1
fi

log "📄  ${ARRBIT_TAG} Reading custom formats from: ${JSON_PATH}"

# Loop through each custom format
jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')

  # Check if format exists
  existing=$(curl -s "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
    | jq -r --arg NAME "$format_name" '.[] | select(.name == $NAME)')

  if [[ -z "$existing" ]]; then
    new_format=$(echo "$format" | jq 'del(.id)')

    {
      echo -e "\n[Payload - ${format_name}] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
      echo "$new_format"
      echo "[/Payload - ${format_name}] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    } >> "$logFilePath"

    response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
      -H "Content-Type: application/json" \
      -d "$new_format")

    {
      echo -e "[Response - ${format_name}] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
      echo "$response"
      echo "[/Response - ${format_name}] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    } >> "$logFilePath"

    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
      log "📥  ${ARRBIT_TAG} Imported new custom format: ${format_name}"
    else
      log "⚠️  ${ARRBIT_TAG} Failed to import format: ${format_name}"
    fi
  else
    log "⏩  ${ARRBIT_TAG} Format already exists, skipping: ${format_name}"
  fi
done

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

#!/usr/bin/env bash
#
# Arrbit Module - Import custom formats from JSON into Lidarr
# Version: v1.5
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared Arrbit functions
source /config/arrbit/process_scripts/functions.bash

scriptName="custom_formats"
scriptVersion="v1.5"

# Setup golden log format
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

# Get Lidarr connection info
getArrAppInfo
verifyApiAccess

# Custom formats JSON file
JSON_PATH="/config/arrbit/process_scripts/modules/json_values/custom_formats_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log "⚠️  ${ARRBIT_TAG} File not found: ${JSON_PATH}"
  exit 1
fi

log "📄  ${ARRBIT_TAG} Reading custom formats from: ${JSON_PATH}"

jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')

  # Check if format already exists in Lidarr
  existing=$(curl -s "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
    | jq -r --arg NAME "$format_name" '.[] | select(.name == $NAME)')

  if [[ -z "$existing" ]]; then
    # Add new format (POST)
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
    # Format exists — skip re-importing
    log "⏩  ${ARRBIT_TAG} Format already exists, skipping: ${format_name}"
  fi
done

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${scriptName}.bash!"
exit 0

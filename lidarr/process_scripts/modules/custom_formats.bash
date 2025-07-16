#!/usr/bin/env bash
#
# Arrbit Custom Formats Importer Module
# Imports custom formats from JSON into Lidarr
# Version: v1.4
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared Arrbit functions
source /config/arrbit/process_scripts/functions.bash

scriptName="custom_formats"
scriptVersion="v1.4"

# Setup logging
logfileSetup

log "🚀  ${ARRBIT_TAG} Starting custom formats module..."

# Get API info and verify connection
getArrAppInfo
verifyApiAccess

# Path to custom formats JSON
JSON_PATH="/config/arrbit/process_scripts/modules/json_values/custom_formats_master.json"

# Check if JSON file exists
if [[ ! -f "$JSON_PATH" ]]; then
  log "❌  ${ARRBIT_TAG} File not found: ${JSON_PATH}"
  exit 1
fi

log "📄  ${ARRBIT_TAG} Reading custom formats from: ${JSON_PATH}"

# Read and loop through each format
jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')

  # Check if format already exists in Lidarr
  existing=$(curl -s "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" | jq -r --arg NAME "$format_name" '.[] | select(.name == $NAME)')

  if [[ -z "$existing" ]]; then
    # Format doesn't exist, remove ID before POST
    new_format=$(echo "$format" | jq 'del(.id)')
    response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
      -H "Content-Type: application/json" \
      -d "$new_format")

    if [[ "$(echo "$response" | jq -r '.id')" != "null" ]]; then
      log "✨  ${ARRBIT_TAG} Imported new custom format: ${format_name}"
    else
      log "⚠️  ${ARRBIT_TAG} Failed to import format: ${format_name} :: Response: ${response}"
    fi
  else
    # Format exists, update using PUT
    existing_id=$(echo "$existing" | jq -r '.id')
    response=$(curl -s -X PUT "${arrUrl}/api/${arrApiVersion}/customformat/${existing_id}?apikey=${arrApiKey}" \
      -H "Content-Type: application/json" \
      -d "$format")

    if [[ "$(echo "$response" | jq -r '.id')" != "null" ]]; then
      log "♻️  ${ARRBIT_TAG} Updated existing custom format: ${format_name}"
    else
      log "⚠️  ${ARRBIT_TAG} Failed to update format: ${format_name} :: Response: ${response}"
    fi
  fi
done

log "🎉  ${ARRBIT_TAG} Finished importing custom formats!"

#!/usr/bin/env bash
# ------------------------------------------------------------
# Arrbit [custom_formats]
# Version: 2.3
# Purpose: Import custom formats from JSON into Lidarr via API (idempotent).
# ------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
rawScriptName="custom_formats"
scriptName="custom formats module"
scriptVersion="v2.3"

MODULES_DIR="/etc/services.d/arrbit/modules"
DATA_DIR="$MODULES_DIR/data"
LOG_DIR="/config/logs"
CONFIG_DIR="/config/arrbit"
JSON_PATH="$DATA_DIR/custom_formats_master.json"
FUNCTIONS_PATH="$MODULES_DIR/functions.bash"

# ------------------------------------------------------------
# 1. Logging Setup
# ------------------------------------------------------------
logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="${LOG_DIR}/${logFileName}"
  mkdir -p "${LOG_DIR}"
  find "${LOG_DIR}" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +2 -delete
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
    | sed -E 's/\033\[[0-9;]*m//g' \
    | sed -E 's/[🔵🟢⚠️📥📄⏩🚀✅❌🔧🔴🟪🟦🟩🟥📁📦]//g' \
    | sed -E 's/\\n/\n/g' \
    | sed -E 's/^[[:space:]]+\[Arrbit\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

logfileSetup

# ------------------------------------------------------------
# 2. Source Functions, Show Header
# ------------------------------------------------------------
if [ -f "$FUNCTIONS_PATH" ]; then
    source "$FUNCTIONS_PATH"
else
    log "❌  $ARRBIT_TAG functions.bash missing! Aborting custom_formats."
    exit 1
fi

log "🚀  $ARRBIT_TAG Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

# ------------------------------------------------------------
# 3. Arrbit API/Config Setup
# ------------------------------------------------------------
getArrAppInfo
verifyApiAccess

# ------------------------------------------------------------
# 4. Locate Custom Formats JSON
# ------------------------------------------------------------
if [[ ! -f "$JSON_PATH" ]]; then
  log "⚠️  $ARRBIT_TAG File not found: $JSON_PATH"
  logRaw "[ERROR] custom_formats_master.json not found at $JSON_PATH"
  exit 1
fi

log "📄  $ARRBIT_TAG Reading custom formats from: $JSON_PATH"
logRaw "[INFO] Reading JSON from: $JSON_PATH"

# ------------------------------------------------------------
# 5. Get existing Custom Formats (by name)
# ------------------------------------------------------------
existing_names=$(curl -s "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
  | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

# ------------------------------------------------------------
# 6. Import Each Custom Format (skip if exists)
# ------------------------------------------------------------
jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')
  format_id=$(echo "$format" | jq -r '.id')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')

  logRaw "\n[START] Format: $format_name (ID: $format_id)"
  logRaw "[ACTION] Checking if format name already exists in Lidarr"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log "⏭️  $ARRBIT_TAG Format already exists, skipping: $format_name"
    logRaw "[SKIP] Custom format already exists in Lidarr: $format_name"
    continue
  fi

  log "📥  $ARRBIT_TAG Importing custom format: $format_name"
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
    log "⚠️  $ARRBIT_TAG Failed to import format: $format_name"
    logRaw "[ERROR] Failed to create custom format: $format_name"
  fi
done

log "📄  $ARRBIT_TAG Log saved to $logFilePath"
log "✅  $ARRBIT_TAG All custom formats have been imported successfully"
log "✅  $ARRBIT_TAG Done with $rawScriptName!"
exit 0

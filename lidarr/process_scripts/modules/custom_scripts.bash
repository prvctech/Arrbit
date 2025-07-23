#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_scripts.bash
# Version: v2.2
# Purpose: Register tagger.bash as Lidarr custom script (Golden Standard compliant, no flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="custom_scripts"
SCRIPT_VERSION="v2.2"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}custom_scripts module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API, sets arr_api)
# ------------------------------------------------------------------------
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Register arrbit-tagger as Lidarr custom script if not present
# ------------------------------------------------------------------------
if ! arr_api "${arrUrl}/api/${arrApiVersion}/notification" | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then
  log_info "${ARRBIT_TAG} Registering arrbit-tagger script"

  payload='{
    "name": "arrbit-tagger",
    "implementation": "CustomScript",
    "configContract": "CustomScriptSettings",
    "onReleaseImport": true,
    "onUpgrade": true,
    "fields": [
      { "name": "path", "value": "/config/arrbit/process_scripts/tagger.bash" }
    ]
  }'

  # Log payload and response only to file
  echo "[Arrbit] Registering arrbit-tagger" >> "$LOG_FILE"
  echo "[Payload]" >> "$LOG_FILE"
  echo "$payload" >> "$LOG_FILE"
  echo "[/Payload]" >> "$LOG_FILE"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}")

  echo "[Response]" >> "$LOG_FILE"
  echo "$response" >> "$LOG_FILE"
  echo "[/Response]" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo "[SUCCESS] arrbit-tagger registered" >> "$LOG_FILE"
  else
    log_error "${ARRBIT_TAG} Failed to register arrbit-tagger script" \
      "register arrbit-tagger POST failed" \
      "${SCRIPT_NAME}.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "Tagger script registration failed" \
      "Check API connectivity and payload"
    echo "[ERROR] Failed to register arrbit-tagger" >> "$LOG_FILE"
  fi
else
  log_info "${ARRBIT_TAG} arrbit-tagger already registered; skipping"
  echo "[SKIP] arrbit-tagger already exists" >> "$LOG_FILE"
fi

log_info "${ARRBIT_TAG} Done with custom_scripts module!"
exit 0

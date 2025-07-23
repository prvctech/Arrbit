#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_formats.bash
# Version: v2.2
# Purpose: Import custom formats from JSON into Lidarr. Golden Standard compliant.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="custom_formats"
SCRIPT_VERSION="v2.2"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}custom_formats module${RESET} ${SCRIPT_VERSION}..."

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

JSON_PATH="/config/arrbit/modules/data/custom_formats_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "${ARRBIT_TAG} File not found: ${JSON_PATH}" \
    "custom_formats_master.json missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required JSON not found" \
    "Check Arrbit data"
  exit 1
fi

log_info "${ARRBIT_TAG} Reading custom formats from: ${JSON_PATH}"

existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')

  # Only log payload/response to file
  echo "[Arrbit] Format: $format_name" >> "$LOG_FILE"
  echo "[Payload]" >> "$LOG_FILE"
  echo "$payload" >> "$LOG_FILE"
  echo "[/Payload]" >> "$LOG_FILE"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "${ARRBIT_TAG} Custom format already exists, skipping: ${format_name}"
    echo "[SKIP] Custom format already exists: $format_name" >> "$LOG_FILE"
    continue
  fi

  log_info "${ARRBIT_TAG} Importing custom format: ${format_name}"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}")

  echo "[Response]" >> "$LOG_FILE"
  echo "$response" >> "$LOG_FILE"
  echo "[/Response]" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo "[SUCCESS] Custom format created: $format_name" >> "$LOG_FILE"
  else
    log_error "${ARRBIT_TAG} Failed to import format: ${format_name}" \
      "custom format POST failed" \
      "${SCRIPT_NAME}.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "Custom format creation failed" \
      "Check API connectivity and payload"
    echo "[ERROR] Failed to create custom format: $format_name" >> "$LOG_FILE"
  fi
done

log_info "${ARRBIT_TAG} Done with custom_formats module!"
exit 0

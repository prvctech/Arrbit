#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_profiles.bash
# Version: v2.2
# Purpose: Import metadata profiles from JSON into Lidarr via API (Golden Standard, no internal flag check).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="metadata_profiles"
SCRIPT_VERSION="v2.2"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}metadata_profiles module${RESET} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

JSON_PATH="/config/arrbit/modules/json_values/metadata_profiles_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "${ARRBIT_TAG} File not found: ${JSON_PATH}"
  echo "[ERROR] metadata_profiles_master.json not found at ${JSON_PATH}" >> "$LOG_FILE"
  exit 1
fi

log_info "[Arrbit] Reading metadata profiles from: ${JSON_PATH}"
echo "[INFO] Reading JSON from: ${JSON_PATH}" >> "$LOG_FILE"

existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/metadataprofile" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r profile; do
  profile_name=$(echo "$profile" | jq -r '.name')
  payload=$(echo "$profile" | jq 'del(.id)')
  lowercase_name=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]')

  echo "[START] Profile: $profile_name" >> "$LOG_FILE"
  echo "[ACTION] Checking if profile name already exists in Lidarr" >> "$LOG_FILE"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "[Arrbit] Metadata profile already exists, skipping: ${profile_name}"
    echo "[SKIP] Profile already exists in Lidarr: $profile_name" >> "$LOG_FILE"
    continue
  fi

  log_info "[Arrbit] Importing metadata profile: ${profile_name}"
  echo "[Arrbit] Importing metadata profile: $profile_name" >> "$LOG_FILE"
  echo "[CREATE] Sending POST to: ${arrUrl}/api/${arrApiVersion}/metadataprofile" >> "$LOG_FILE"
  echo "[Payload] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" >> "$LOG_FILE"
  echo "$payload" >> "$LOG_FILE"
  echo "[/Payload] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >> "$LOG_FILE"

  response=$(
    arr_api -X POST --data-raw "$payload" \
      "${arrUrl}/api/${arrApiVersion}/metadataprofile?apikey=${arrApiKey}"
  )

  echo "[Response] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" >> "$LOG_FILE"
  echo "$response" >> "$LOG_FILE"
  echo "[/Response] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo "[SUCCESS] Metadata profile created: $profile_name" >> "$LOG_FILE"
  else
    log_error "[Arrbit] Failed to create metadata profile: ${profile_name}"
    echo "[ERROR] Failed to create profile: $profile_name" >> "$LOG_FILE"
  fi
done

log_info "[Arrbit] Log saved to $LOG_FILE"
log_info "[Arrbit] All metadata profiles have been imported successfully"
log_info "[Arrbit] Done with ${SCRIPT_NAME} module!"
exit 0

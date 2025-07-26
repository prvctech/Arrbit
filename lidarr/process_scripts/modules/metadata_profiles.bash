#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_profiles.bash
# Version: v2.4-gs2.6
# Purpose: Import metadata profiles from JSON into Lidarr via API (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Source logging and helpers (Golden Standard order)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="metadata_profiles"
SCRIPT_VERSION="v2.4-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

# Updated JSON path and filename
JSON_PATH="/config/arrbit/modules/json_values/metadata_profiles.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH}"
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

log_info "Reading metadata profiles from: ${JSON_PATH}"
printf '[Arrbit] Reading JSON from: %s\n' "$JSON_PATH" | arrbitLogClean >> "$LOG_FILE"

existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/metadataprofile" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r profile; do
  profile_name=$(echo "$profile" | jq -r '.name')
  payload=$(echo "$profile" | jq 'del(.id)')
  lowercase_name=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]')

  log_info "Processing metadata profile: ${profile_name}"
  printf '[Arrbit] START Profile: %s\n' "$profile_name" | arrbitLogClean >> "$LOG_FILE"
  printf '[Arrbit] ACTION Checking if profile name already exists in Lidarr\n' | arrbitLogClean >> "$LOG_FILE"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "Metadata profile already exists, skipping: ${profile_name}"
    printf '[Arrbit] SKIP Profile already exists in Lidarr: %s\n' "$profile_name" | arrbitLogClean >> "$LOG_FILE"
    continue
  fi

  log_info "Importing metadata profile: ${profile_name}"
  printf '[Arrbit] Importing metadata profile: %s\n' "$profile_name" | arrbitLogClean >> "$LOG_FILE"
  printf '[Arrbit] CREATE Sending POST to: %s/api/%s/metadataprofile\n' "$arrUrl" "$arrApiVersion" | arrbitLogClean >> "$LOG_FILE"
  printf '[Arrbit] [Payload]\n%s\n[/Payload]\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

  response=$(
    arr_api -X POST --data-raw "$payload" \
      "${arrUrl}/api/${arrApiVersion}/metadataprofile?apikey=${arrApiKey}"
  )

  printf '[Arrbit] [Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Metadata profile created: %s\n' "$profile_name" | arrbitLogClean >> "$LOG_FILE"
  else
    log_error "Failed to create metadata profile: ${profile_name}"
    printf '[Arrbit] ERROR Failed to create profile: %s\n' "$profile_name" | arrbitLogClean >> "$LOG_FILE"
  fi
done

log_info "All metadata profiles have been imported successfully"
log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

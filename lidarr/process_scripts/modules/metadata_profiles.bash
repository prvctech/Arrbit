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

CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# Banner (first log only, yellow module name)
log_info "${YELLOW}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

JSON_PATH="/config/arrbit/modules/json_values/metadata_profiles_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH}"
  printf '[Arrbit] ERROR: metadata_profiles_master.json not found at %s\n' "$JSON_PATH" >> "$LOG_FILE"
  exit 1
fi

log_info "Reading metadata profiles from: ${JSON_PATH}"
printf '[Arrbit] Reading JSON from: %s\n' "$JSON_PATH" >> "$LOG_FILE"

existing_names=$(arr_api "${arrUrl}/api/${arrApiVersion}/metadataprofile" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r profile; do
  profile_name=$(echo "$profile" | jq -r '.name')
  payload=$(echo "$profile" | jq 'del(.id)')
  lowercase_name=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]')

  printf '[Arrbit] START Profile: %s\n' "$profile_name" >> "$LOG_FILE"
  printf '[Arrbit] ACTION Checking if profile name already exists in Lidarr\n' >> "$LOG_FILE"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    log_info "Metadata profile already exists, skipping: ${profile_name}"
    printf '[Arrbit] SKIP Profile already exists in Lidarr: %s\n' "$profile_name" >> "$LOG_FILE"
    continue
  fi

  log_info "Importing metadata profile: ${profile_name}"
  printf '[Arrbit] Importing metadata profile: %s\n' "$profile_name" >> "$LOG_FILE"
  printf '[Arrbit] CREATE Sending POST to: %s/api/%s/metadataprofile\n' "$arrUrl" "$arrApiVersion" >> "$LOG_FILE"
  printf '[Arrbit] [Payload]\n%s\n[/Payload]\n' "$payload" >> "$LOG_FILE"

  response=$(
    arr_api -X POST --data-raw "$payload" \
      "${arrUrl}/api/${arrApiVersion}/metadataprofile?apikey=${arrApiKey}"
  )

  printf '[Arrbit] [Response]\n%s\n[/Response]\n' "$response" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Metadata profile created: %s\n' "$profile_name" >> "$LOG_FILE"
  else
    log_error "Failed to create metadata profile: ${profile_name}"
    printf '[Arrbit] ERROR Failed to create profile: %s\n' "$profile_name" >> "$LOG_FILE"
  fi
done

log_info "Log saved to $LOG_FILE"
log_info "All metadata profiles have been imported successfully"
log_info "Done with ${SCRIPT_NAME} module!"
exit 0

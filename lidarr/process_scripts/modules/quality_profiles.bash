#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.4-gs2.6
# Purpose: Import new quality profiles, then delete Lidarr's default ones by NAME only (no file needed).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.4-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
REPLACE_JSON="/config/arrbit/modules/data/payload-quality_profiles-no_custom_formats.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

if [[ ! -f "$REPLACE_JSON" ]]; then
  log_error "File not found: ${REPLACE_JSON}"
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

log_info "Reading replacement profiles from: ${REPLACE_JSON}"

existing_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")
if [[ -z "$existing_profiles" ]]; then
  log_error "Could not retrieve existing quality profiles from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

# --- Step 1: Import replacements FIRST ---
mapfile -t REPLACEMENTS < <(jq -c '.[]' "$REPLACE_JSON")
for profile in "${REPLACEMENTS[@]}"; do
  name=$(echo "$profile" | jq -r '.name')
  payload=$(echo "$profile" | jq 'del(.id)')
  log_info "Importing replacement quality profile: $name"
  printf '[Arrbit] Importing replacement profile: %s\n[Payload]\n%s\n[/Payload]\n' "$name" "$payload" | arrbitLogClean >> "$LOG_FILE"
  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualityprofile?apikey=${arrApiKey}")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Replacement profile created: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
  else
    log_error "Failed to create replacement profile: $name"
    printf '[Arrbit] ERROR Failed to create replacement profile: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
  fi
done

# Refresh existing_profiles for accurate deletion!
existing_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")

# --- Step 2: Delete Lidarr defaults by NAME only ---
DEFAULT_NAMES=("any" "lossless" "standard")
for row in $(echo "$existing_profiles" | jq -c '.[]'); do
  ex_id=$(echo "$row" | jq -r '.id')
  ex_name=$(echo "$row" | jq -r '.name' | tr '[:upper:]' '[:lower:]')
  for del_lname in "${DEFAULT_NAMES[@]}"; do
    if [[ "$ex_name" == "$del_lname" ]]; then
      log_info "Deleting quality profile by name: $ex_name (ID: $ex_id)"
      printf '[Arrbit] Deleting quality profile: %s (ID: %s)\n' "$ex_name" "$ex_id" | arrbitLogClean >> "$LOG_FILE"
      del_response=$(arr_api -X DELETE "${arrUrl}/api/${arrApiVersion}/qualityprofile/$ex_id?apikey=${arrApiKey}")
      printf '[Response]\n%s\n[/Response]\n' "$del_response" | arrbitLogClean >> "$LOG_FILE"
    fi
  done
done

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

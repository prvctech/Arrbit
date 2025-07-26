#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.0-gs2.6
# Purpose: Safely delete Lidarr default quality profiles if 1:1 match, then import replacements.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.0-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
DEFAULT_JSON="/config/arrbit/modules/data/payload-quality_profiles-lidarr_default_values.json"
REPLACE_JSON="/config/arrbit/modules/data/payload-quality_profiles-no_custom_formats.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

if [[ ! -f "$DEFAULT_JSON" ]]; then
  log_error "File not found: ${DEFAULT_JSON}"
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

if [[ ! -f "$REPLACE_JSON" ]]; then
  log_error "File not found: ${REPLACE_JSON}"
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

log_info "Reading default profiles from: ${DEFAULT_JSON}"
log_info "Reading replacement profiles from: ${REPLACE_JSON}"

existing_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")
if [[ -z "$existing_profiles" ]]; then
  log_error "Could not retrieve existing quality profiles from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

mapfile -t DEFAULTS < <(jq -c '.[]' "$DEFAULT_JSON")

# --- Step 1: Find and DELETE default-matching profiles ---
for default_profile in "${DEFAULTS[@]}"; do
  def_name=$(echo "$default_profile" | jq -r '.name')
  def_payload=$(echo "$default_profile" | jq 'del(.id)')
  def_lname=$(echo "$def_name" | tr '[:upper:]' '[:lower:]')
  found_id=""
  found_payload=""

  for row in $(echo "$existing_profiles" | jq -c '.[]'); do
    ex_id=$(echo "$row" | jq -r '.id')
    ex_name=$(echo "$row" | jq -r '.name' | tr '[:upper:]' '[:lower:]')
    if [[ "$ex_name" == "$def_lname" ]]; then
      found_id="$ex_id"
      found_payload=$(echo "$row" | jq 'del(.id)')
      break
    fi
  done

  # Only delete if 1:1 match with default
  if [[ -n "$found_id" ]] && [[ "$(echo "$def_payload" | jq -S .)" == "$(echo "$found_payload" | jq -S .)" ]]; then
    log_info "Deleting default quality profile: $def_name (ID: $found_id)"
    printf '[Arrbit] Deleting default profile: %s (ID: %s)\n' "$def_name" "$found_id" | arrbitLogClean >> "$LOG_FILE"
    del_response=$(arr_api -X DELETE "${arrUrl}/api/${arrApiVersion}/qualityprofile/$found_id?apikey=${arrApiKey}")
    printf '[Response]\n%s\n[/Response]\n' "$del_response" | arrbitLogClean >> "$LOG_FILE"
  fi
done

# --- Step 2: Import replacements ---
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

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.7-gs2.6
# Purpose: Import new quality profiles, skip duplicates, patch custom formats inside quality items dynamically.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.7-gs2.6"
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

# Fetch existing profiles & custom formats from Lidarr
existing_profiles_json=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")
if [[ -z "$existing_profiles_json" ]]; then
  log_error "Could not retrieve existing quality profiles from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

custom_formats_json=$(arr_api "${arrUrl}/api/${arrApiVersion}/customFormat")
if [[ -z "$custom_formats_json" ]]; then
  log_error "Could not retrieve custom formats from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

# Build custom format name -> id map
declare -A CF_NAME_TO_ID
while IFS=$'\t' read -r id name; do
  CF_NAME_TO_ID["$name"]=$id
done < <(echo "$custom_formats_json" | jq -r '.[] | "\(.id)\t\(.name)"')

# Read replacement profiles from JSON
mapfile -t REPLACEMENTS < <(jq -c '.[]' "$REPLACE_JSON")

# Lowercase existing profile names for skip checking
mapfile -t EXISTING_NAMES < <(echo "$existing_profiles_json" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

SKIPPED_NAMES=()

for profile in "${REPLACEMENTS[@]}"; do
  name=$(echo "$profile" | jq -r '.name')
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  # Skip if profile exists
  if printf '%s\n' "${EXISTING_NAMES[@]}" | grep -Fxq "$lname"; then
    SKIPPED_NAMES+=("$name")
    continue
  fi

  # Patch custom formats inside each quality item's formatItems
  # Strategy:
  # - For each .items[] element:
  #   - Replace formatItems with current custom format objects by matching name
  patched_profile=$(echo "$profile" | jq --argjson cf "$custom_formats_json" '
    del(.id) |  # remove root id only

    # For each item in items array, patch formatItems by name lookup in current CF
    .items |= map(
      if has("formatItems") and (.formatItems | length > 0) then
        .formatItems = (
          .formatItems
          | map(
            # match by name in current CF list and replace whole object
            .name as $fmtName
            | $cf
            | map(select(.name == $fmtName))
            | first
            // .
          )
        )
      else
        .
      end
    )
  ')

  log_info "Importing replacement quality profile: $name"
  printf '[Arrbit] Importing replacement profile: %s\n[Payload]\n%s\n[/Payload]\n' "$name" "$patched_profile" | arrbitLogClean >> "$LOG_FILE"
  response=$(arr_api -X POST --data-raw "$patched_profile" "${arrUrl}/api/${arrApiVersion}/qualityprofile?apikey=${arrApiKey}")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Replacement profile created: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
    EXISTING_NAMES+=("$lname")
  else
    log_error "Failed to create replacement profile: $name"
    printf '[Arrbit] ERROR Failed to create replacement profile: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
  fi
done

if (( ${#SKIPPED_NAMES[@]} > 0 )); then
  log_info "Quality profiles already exist - skipping import for all"
fi

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

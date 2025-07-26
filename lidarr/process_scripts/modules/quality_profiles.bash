#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.6-gs2.6
# Purpose: Import new quality profiles, skip duplicates, dynamically patch custom formats to match current Lidarr instance
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.6-gs2.6"
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

# Fetch existing quality profiles and existing custom formats from Lidarr API
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

# Build map from custom format name to ID for current instance
declare -A CF_NAME_TO_ID
while IFS=$'\t' read -r id name; do
  CF_NAME_TO_ID["$name"]=$id
done < <(echo "$custom_formats_json" | jq -r '.[] | "\(.id)\t\(.name)"')

# Read replacement profiles from static JSON
mapfile -t REPLACEMENTS < <(jq -c '.[]' "$REPLACE_JSON")

# Build lowercase existing profile names array for skip check
mapfile -t EXISTING_NAMES < <(echo "$existing_profiles_json" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

SKIPPED_NAMES=()

for profile in "${REPLACEMENTS[@]}"; do
  name=$(echo "$profile" | jq -r '.name')
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  # Skip if profile name exists
  if printf '%s\n' "${EXISTING_NAMES[@]}" | grep -Fxq "$lname"; then
    SKIPPED_NAMES+=("$name")
    continue
  fi

  # Now we patch the profile payload to dynamically map formatItems/custom formats to current IDs

  # Extract the formatItems from the profile JSON, if present
  # If no formatItems, then we pass as is (should be empty or [])
  # We replace IDs with current ones by matching name

  patched_profile=$(echo "$profile" | jq --argjson cf "$custom_formats_json" '
    # function to map old custom format IDs to current IDs by name
    def map_custom_formats:
      if has("formatItems") and (.formatItems | length > 0) then
        .formatItems |= map(
          # Find matching custom format by name from $cf
          . as $old |
          $cf
          | map(select(.name == $old.name)) | first
          // $old  # fallback to old if not found
        )
      else
        .
      end;

    # For compatibility, also patch any custom formats inside items[].formatItems or formatItems if present (some profiles may have these)
    def recursive_patch:
      (.items? // []) |= map(
        if has("formatItems") then
          .formatItems |= map(
            . as $old |
            $cf
            | map(select(.name == $old.name)) | first
            // $old
          )
        else
          .
        end
      );

    map_custom_formats | recursive_patch
  ')

  # Remove id fields at root and inside items for Lidarr to assign new IDs
  patched_profile=$(echo "$patched_profile" | jq 'del(.id) | .items |= map(del(.id))')

  log_info "Importing replacement quality profile: $name"
  printf '[Arrbit] Importing replacement profile: %s\n[Payload]\n%s\n[/Payload]\n' "$name" "$patched_profile" | arrbitLogClean >> "$LOG_FILE"
  response=$(arr_api -X POST --data-raw "$patched_profile" "${arrUrl}/api/${arrApiVersion}/qualityprofile?apikey=${arrApiKey}")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Replacement profile created: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
    EXISTING_NAMES+=("$lname") # Add to skip list
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

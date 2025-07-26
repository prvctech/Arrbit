#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.7-gs2.6
# Purpose: Import quality profiles replacing each quality item's formatItems with current Lidarr custom formats
#          (including IDs), removing all other IDs to avoid conflicts.
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

# Fetch current Lidarr custom formats (full array with IDs)
custom_formats_json=$(arr_api "${arrUrl}/api/${arrApiVersion}/customFormat")
if [[ -z "$custom_formats_json" ]]; then
  log_error "Could not retrieve custom formats from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

# Fetch existing quality profiles
existing_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")
if [[ -z "$existing_profiles" ]]; then
  log_error "Could not retrieve existing quality profiles from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

# Prepare lowercase list of existing profile names
mapfile -t EXISTING_NAMES < <(echo "$existing_profiles" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

# Read replacement profiles into array
mapfile -t REPLACEMENTS < <(jq -c '.[]' "$REPLACE_JSON")

SKIPPED_NAMES=()

for profile in "${REPLACEMENTS[@]}"; do
  name=$(echo "$profile" | jq -r '.name')
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  if printf '%s\n' "${EXISTING_NAMES[@]}" | grep -Fxq "$lname"; then
    SKIPPED_NAMES+=("$name")
    continue
  fi

  # Patch profile:
  # - Remove all "id" fields recursively EXCEPT those under formatItems (keep IDs of custom formats)
  # - Replace each quality item's formatItems with the current custom formats JSON (which includes IDs)
  patched_profile=$(echo "$profile" | jq --argjson cf "$custom_formats_json" '
    # Remove all ids except those in formatItems
    walk(
      if type == "object" then
        with_entries(
          if .key == "id" then
            # Keep id only if parent object is inside formatItems array
            if (path | index("formatItems")) then . else empty end
          else
            .
          end
        )
      else
        .
      end
    )
    |
    # Replace each quality item formatItems with current custom formats array
    .items |= map(
      if has("formatItems") then
        .formatItems = $cf
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
  log_info "Quality profiles already exist - skipping import: ${SKIPPED_NAMES[*]}"
fi

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

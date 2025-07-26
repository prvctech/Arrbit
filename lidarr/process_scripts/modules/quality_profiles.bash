#!/usr/bin/env bash
################################################################################
# Arrbit: Quality Profile Importer v1.6-gs2.6 (FULL GOLDEN STANDARD)
################################################################################
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="arrbit-quality_profiles-importer"
SCRIPT_VERSION="v1.6-gs2.6"
LOG_FILE="/config/logs/arrbit-quality_profiles-$(date +'%Y_%m_%d-%H_%M').log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "[Arrbit] Starting quality_profiles module $SCRIPT_VERSION..."

source /config/arrbit/connectors/arr_bridge.bash || {
  log_error "[Arrbit] arr_bridge.bash missing or failed to source!"
  exit 1
}

# Config paths
REPLACEMENTS_JSON="/config/arrbit/modules/data/payload-quality_profiles-no_custom_formats.json"
log_info "[Arrbit] Reading replacement profiles from: $REPLACEMENTS_JSON"

if [[ ! -s "$REPLACEMENTS_JSON" ]]; then
  log_error "[Arrbit] Replacement profiles JSON missing or empty: $REPLACEMENTS_JSON"
  exit 1
fi

REPLACEMENTS=($(jq -c '.[]' "$REPLACEMENTS_JSON"))
if [[ ${#REPLACEMENTS[@]} -eq 0 ]]; then
  log_error "[Arrbit] No replacement profiles found in: $REPLACEMENTS_JSON"
  exit 1
fi

# Fetch qualities from Lidarr
qualities_json=$(arr_api "${arrUrl}/api/${arrApiVersion}/quality")
if [[ -z "$qualities_json" ]]; then
  log_error "[Arrbit] Failed to fetch qualities from Lidarr API."
  exit 1
fi

quality_items=$(echo "$qualities_json" | jq '[.[] | {allowed:true, quality:{id:.id, name:.name, source:(.source // "scene")}, id:.id}]')
if [[ -z "$quality_items" || "$quality_items" == "null" ]]; then
  log_error "[Arrbit] Unable to build quality items array for profiles."
  exit 1
fi

# Fetch existing profile names for duplicate skipping
existing_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityProfile")
EXISTING_NAMES=($(echo "$existing_profiles" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]'))

SKIPPED_NAMES=()
CREATED_NAMES=()
FAILED_NAMES=()

for profile in "${REPLACEMENTS[@]}"; do
  name=$(echo "$profile" | jq -r '.name')
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  if printf '%s\n' "${EXISTING_NAMES[@]}" | grep -Fxq "$lname"; then
    log_warning "[Arrbit] Profile already exists, skipping: $name"
    SKIPPED_NAMES+=("$name")
    continue
  fi

  log_info "[Arrbit] Importing replacement quality profile: $name"

  # Remove .id, set .items and .cutoff dynamically
  first_cutoff=$(echo "$quality_items" | jq '.[0].quality.id')
  patched_profile=$(echo "$profile" | jq --argjson items "$quality_items" --argjson cutoff "$first_cutoff" '
    del(.id)
    | .items = $items
    | .cutoff = $cutoff
    | del(.formatItems)
  ')

  # Always redact sensitive info before logging
  arrbitLogClean "$patched_profile"

  # Send POST request
  response=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityProfile" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$patched_profile"
  )

  # Check for success (created profile should echo .name, or response id)
  if echo "$response" | jq -e '.id, .name' >/dev/null 2>&1; then
    log_info "[Arrbit] SUCCESS: Created profile: $name"
    CREATED_NAMES+=("$name")
  else
    log_error "[Arrbit] ERROR: Failed to create replacement profile: $name"
    log_error "[Arrbit] API Response: $(echo "$response" | head -c 400)"
    FAILED_NAMES+=("$name")
  fi
done

log_info "[Arrbit] Import complete."
if [[ ${#CREATED_NAMES[@]} -gt 0 ]]; then
  log_info "[Arrbit] Created: ${CREATED_NAMES[*]}"
fi
if [[ ${#SKIPPED_NAMES[@]} -gt 0 ]]; then
  log_warning "[Arrbit] Skipped (already existed): ${SKIPPED_NAMES[*]}"
fi
if [[ ${#FAILED_NAMES[@]} -gt 0 ]]; then
  log_error "[Arrbit] Failed: ${FAILED_NAMES[*]}"
fi

arrbitLogClean "$LOG_FILE"

################################################################################
# END OF FILE - GOLDEN STANDARD v2.6 (DO NOT EDIT BELOW THIS LINE)
################################################################################

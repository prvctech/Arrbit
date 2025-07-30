#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.7-gs2.6
# Purpose: Import new quality profiles, always map live custom format IDs, skip duplicates, no deletion logic.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.7-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

CUSTOM_FORMATS_ENABLED=$(getFlag "CONFIGURE_CUSTOM_FORMATS")
if [[ "${CUSTOM_FORMATS_ENABLED,,}" == "true" ]]; then
  # Payloads WITH custom formats
  REPLACE_JSON="/config/arrbit/modules/data/payload-quality_profiles-with_custom_formats.json"

  # Get custom formats from Lidarr
  log_info "Fetching live custom format IDs from Lidarr..."
  CUSTOM_FORMATS_RAW=$(arr_api "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}")
  if [[ -z "$CUSTOM_FORMATS_RAW" ]]; then
    log_error "Could not retrieve custom formats from Lidarr."
    log_info "Log saved to $LOG_FILE"
    exit 1
  fi

  # Build a jq map for name → id
  CF_JQ_MAP=$(echo "$CUSTOM_FORMATS_RAW" | jq -r 'map({(.name): .id}) | add')

  # Check that all names from payload exist in live formats
  REMAPPED_JSON=$(jq --argjson cfmap "$CF_JQ_MAP" '
    map(
      .formatItems |= map(
        .format = ($cfmap[.name] // -1)
      )
    )
  ' "$REPLACE_JSON")

  # Validate: if any .format == -1, error!
  if echo "$REMAPPED_JSON" | jq '.[]|.formatItems[]|select(.format == -1)' | grep -q .; then
    log_error "Mismatch: One or more custom formats in your profile payload do not exist in Lidarr. Check for typos or import order."
    log_info "Log saved to $LOG_FILE"
    exit 1
  fi

  REPLACEMENTS_JSON="$REMAPPED_JSON"
else
  # Payloads WITHOUT custom formats
  REPLACE_JSON="/config/arrbit/modules/data/payload-quality_profiles-no_custom_formats.json"
  if [[ ! -f "$REPLACE_JSON" ]]; then
    log_error "File not found: ${REPLACE_JSON}"
    log_info "Log saved to $LOG_FILE"
    exit 1
  fi
  REPLACEMENTS_JSON=$(cat "$REPLACE_JSON")
fi

log_info "Reading replacement profiles from: ${REPLACE_JSON}"

existing_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")
if [[ -z "$existing_profiles" ]]; then
  log_error "Could not retrieve existing quality profiles from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

mapfile -t EXISTING_NAMES < <(echo "$existing_profiles" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')
mapfile -t REPLACEMENTS < <(echo "$REPLACEMENTS_JSON" | jq -c '.[]')

skipped_any=false

for profile in "${REPLACEMENTS[@]}"; do
  name=$(echo "$profile" | jq -r '.name')
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  if printf '%s\n' "${EXISTING_NAMES[@]}" | grep -Fxq "$lname"; then
    skipped_any=true
    continue
  fi

  payload=$(echo "$profile" | jq 'del(.id)')

  log_info "Importing replacement quality profile: $name"
  printf '[Arrbit] Importing replacement profile: %s\n[Payload]\n%s\n[/Payload]\n' "$name" "$payload" | arrbitLogClean >> "$LOG_FILE"
  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualityprofile?apikey=${arrApiKey}")
  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Replacement profile created: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
    EXISTING_NAMES+=("$lname")
  else
    log_error "Failed to create replacement profile: $name"
    printf '[Arrbit] ERROR Failed to create replacement profile: %s\n' "$name" | arrbitLogClean >> "$LOG_FILE"
  fi
done

if $skipped_any; then
  log_info "Quality profiles already exists - skipping."
fi

#log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

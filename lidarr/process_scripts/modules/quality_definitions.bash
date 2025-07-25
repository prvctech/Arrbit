#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_definitions.bash
# Version: v1.3-gs2.6
# Purpose: Overwrite quality definitions in Lidarr with those from JSON—skip process if all are 1:1 (Golden Standard)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_definitions"
SCRIPT_VERSION="v1.3-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
JSON_PATH="/config/arrbit/modules/data/quality_definitions.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

if [[ ! -f "$JSON_PATH" ]]; then
  log_error "File not found: ${JSON_PATH}"
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

log_info "Reading quality definitions from: ${JSON_PATH}"
printf '[Arrbit] Reading quality definitions from: %s\n' "$JSON_PATH" | arrbitLogClean >> "$LOG_FILE"

# Get all existing quality definitions from Lidarr
existing_defs=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualitydefinition")
if [[ -z "$existing_defs" ]]; then
  log_error "Could not retrieve existing quality definitions from Lidarr."
  log_info "Log saved to $LOG_FILE"
  exit 1
fi

mapfile -t EXISTING_IDS < <(echo "$existing_defs" | jq -r '.[] | "\(.id)|\(.quality.id)|\(.title|ascii_downcase)"')

# --- Pass 1: Compare all entries; only proceed if at least one differs ---
all_match=true
mapfile -t JSON_DEFS < <(jq -c '.[]' "$JSON_PATH")

for definition in "${JSON_DEFS[@]}"; do
  q_id=$(echo "$definition" | jq -r '.quality.id')
  title=$(echo "$definition" | jq -r '.title')
  l_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$definition" | jq 'del(.id)')
  match_id=""
  match_payload=""

  for entry in "${EXISTING_IDS[@]}"; do
    IFS="|" read -r eid eqid etitle <<< "$entry"
    if [[ "$eqid" == "$q_id" || "$etitle" == "$l_title" ]]; then
      match_id="$eid"
      match_payload=$(echo "$existing_defs" | jq --arg eid "$eid" '.[] | select(.id == ($eid|tonumber)) | del(.id)')
      break
    fi
  done

  if [[ -n "$match_payload" ]]; then
    if [[ "$(echo "$payload" | jq -S .)" != "$(echo "$match_payload" | jq -S .)" ]]; then
      all_match=false
      break
    fi
  else
    all_match=false
    break
  fi
done

if $all_match; then
  log_info "Quality definitions already set. Skipping process."
  printf '[Arrbit] Quality definitions already set. Skipping process.\n' | arrbitLogClean >> "$LOG_FILE"
  log_info "Done with ${SCRIPT_NAME} module!"
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# --- Pass 2: Only update the ones that are different ---
for definition in "${JSON_DEFS[@]}"; do
  q_id=$(echo "$definition" | jq -r '.quality.id')
  title=$(echo "$definition" | jq -r '.title')
  l_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$definition" | jq 'del(.id)')
  match_id=""
  match_payload=""

  for entry in "${EXISTING_IDS[@]}"; do
    IFS="|" read -r eid eqid etitle <<< "$entry"
    if [[ "$eqid" == "$q_id" || "$etitle" == "$l_title" ]]; then
      match_id="$eid"
      match_payload=$(echo "$existing_defs" | jq --arg eid "$eid" '.[] | select(.id == ($eid|tonumber)) | del(.id)')
      break
    fi
  done

  # Only update if different or missing
  if [[ -n "$match_payload" ]]; then
    if [[ "$(echo "$payload" | jq -S .)" != "$(echo "$match_payload" | jq -S .)" ]]; then
      log_info "Updating quality definition: ${title} (ID: ${match_id})"
      printf '[Arrbit] Updating Quality Definition: %s (Lidarr ID: %s)\n[Payload]\n%s\n[/Payload]\n' "$title" "$match_id" "$payload" | arrbitLogClean >> "$LOG_FILE"
      response=$(arr_api -X PUT --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualitydefinition/$match_id?apikey=${arrApiKey}")

      printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

      if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        printf '[Arrbit] SUCCESS: Quality definition processed: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
      else
        log_error "Failed to process quality definition: ${title}"
        printf '[Arrbit] ERROR Failed to process quality definition: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
      fi
    fi
  else
    log_info "No match found, creating new quality definition: ${title}"
    printf '[Arrbit] Creating NEW Quality Definition: %s\n[Payload]\n%s\n[/Payload]\n' "$title" "$payload" | arrbitLogClean >> "$LOG_FILE"
    response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualitydefinition?apikey=${arrApiKey}")

    printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
      printf '[Arrbit] SUCCESS: Quality definition created: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
    else
      log_error "Failed to create quality definition: ${title}"
      printf '[Arrbit] ERROR Failed to create quality definition: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
    fi
  fi
done

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

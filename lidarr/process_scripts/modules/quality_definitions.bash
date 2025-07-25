#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_definitions.bash
# Version: v1.0-gs2.6
# Purpose: Import quality definitions from JSON into Lidarr (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Golden Standard: log_utils first, then helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_definitions"
SCRIPT_VERSION="v1.0-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
JSON_PATH="/config/arrbit/modules/data/quality_definitions.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
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

# Get existing titles (case-insensitive)
existing_titles=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualitydefinition" | jq -r '.[].title' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r definition; do
  title=$(echo "$definition" | jq -r '.title')
  lowercase_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
  # Always let Lidarr assign the ID
  payload=$(echo "$definition" | jq 'del(.id)')
  
  # Log only to file
  printf '[Arrbit] Quality Definition: %s\n[Payload]\n%s\n[/Payload]\n' "$title" "$payload" | arrbitLogClean >> "$LOG_FILE"

  if echo "$existing_titles" | grep -Fxq "$lowercase_title"; then
    log_info "Quality definition already exists, skipping: ${title}"
    printf '[Arrbit] SKIP Quality definition already exists: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
    continue
  fi

  log_info "Importing quality definition: ${title}"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/qualitydefinition?apikey=${arrApiKey}")

  printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    printf '[Arrbit] SUCCESS Quality definition created: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
  else
    log_error "Failed to import quality definition: ${title}"
    printf '[Arrbit] ERROR Failed to create quality definition: %s\n' "$title" | arrbitLogClean >> "$LOG_FILE"
  fi
done

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

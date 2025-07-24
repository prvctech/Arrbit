#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_scripts.bash
# Version: v2.3
# Purpose: Registers custom scripts for Lidarr using modular JSON payloads. Golden Standard enforced.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="custom_scripts"
SCRIPT_VERSION="v2.3"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

PAYLOAD_JSON="/config/arrbit/modules/data/custom_script_tagger.json"

log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# --- Startup banner ---
log_info "${YELLOW}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# --- Connect to arr_bridge (required for arr_api) ---
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

# --- Check payload file exists ---
if [[ ! -f "$PAYLOAD_JSON" ]]; then
  log_error "Payload JSON not found: $PAYLOAD_JSON"
  exit 1
fi

# --- Extract, clean, and POST each script in payload ---
count=0
jq -c '.[]' "$PAYLOAD_JSON" | while read -r raw; do
  # Remove "id" property to let Lidarr assign new ID
  payload=$(echo "$raw" | jq 'del(.id)')

  # Get the name (for logs)
  name=$(echo "$payload" | jq -r '.name // .fields[]? | select(.name == "name") | .value')

  # Check if already exists in Lidarr (by name)
  if arr_api "${arrUrl}/api/${arrApiVersion}/notification" | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
    log_info "Custom script '$name' already registered; skipping."
    printf '[Arrbit] SKIP custom script "%s" already exists\n' "$name" >> "$LOG_FILE"
    continue
  fi

  log_info "Registering custom script: $name"
  printf '[Arrbit] Registering custom script "%s"\n[Payload]\n%s\n[/Payload]\n' "$name" "$payload" >> "$LOG_FILE"

  response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}")

  printf '[Response]\n%s\n[/Response]\n' "$response" >> "$LOG_FILE"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    log_info "SUCCESS: Custom script '$name' registered."
    printf '[Arrbit] SUCCESS custom script "%s" registered\n' "$name" >> "$LOG_FILE"
    count=$((count + 1))
  else
    log_error "Failed to register custom script: $name"
    printf '[Arrbit] ERROR Failed to register custom script "%s"\n' "$name" >> "$LOG_FILE"
  fi
done

log_info "Done with ${SCRIPT_NAME} module! ($count new scripts registered)"
exit 0

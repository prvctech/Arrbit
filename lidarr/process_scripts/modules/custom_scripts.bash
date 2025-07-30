#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_scripts.bash
# Version: v2.6-gs2.6
# Purpose: Registers all custom scripts found in /config/arrbit/modules/data/custom_script_*.json (modular, bulletproof, Golden Standard v2.6 compliant)
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# Golden Standard: log_utils first, then helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="custom_scripts"
SCRIPT_VERSION="v2.6-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
PAYLOAD_DIR="/config/arrbit/modules/data"
PATTERN="custom_script_*.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- Startup banner ---
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# --- Connect to arr_bridge (required for arr_api) ---
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

files_found=0
scripts_registered=0

for file in "$PAYLOAD_DIR"/$PATTERN; do
  if [[ ! -f "$file" ]]; then
    continue
  fi
  files_found=1

  jq -c '. as $in | (if type=="array" then $in[] else $in end)' "$file" | while read -r raw; do
    # --- Validate: Only process objects ---
    is_obj=$(echo "$raw" | jq -er 'type == "object"' 2>/dev/null || echo "false")
    if [[ "$is_obj" != "true" ]]; then
      log_error "Payload in $file is not a valid object: $raw"
      printf '[Arrbit] ERROR Invalid payload in %s: %s\n' "$file" "$raw" | arrbitLogClean >> "$LOG_FILE"
      continue
    fi

    payload=$(echo "$raw" | jq 'del(.id)')
    name=$(echo "$payload" | jq -r '.name // empty')

    # --- Validate: Name is required ---
    if [[ -z "$name" ]]; then
      log_error "Payload missing .name property in $file: $payload"
      printf '[Arrbit] ERROR Payload missing .name property in %s: %s\n' "$file" "$payload" | arrbitLogClean >> "$LOG_FILE"
      continue
    fi

    # --- Skip if already registered ---
    if arr_api "${arrUrl}/api/${arrApiVersion}/notification" | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
      log_info "Custom script '$name' already registered; skipping."
      printf '[Arrbit] SKIP custom script "%s" already exists\n' "$name" | arrbitLogClean >> "$LOG_FILE"
      continue
    fi

    log_info "Registering custom script: $name"
    printf '[Arrbit] Registering custom script "%s"\n[Payload]\n%s\n[/Payload]\n' "$name" "$payload" | arrbitLogClean >> "$LOG_FILE"

    response=$(arr_api -X POST --data-raw "$payload" "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}")

    printf '[Response]\n%s\n[/Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"

    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
      log_info "SUCCESS: Custom script '$name' registered."
      printf '[Arrbit] SUCCESS custom script "%s" registered\n' "$name" | arrbitLogClean >> "$LOG_FILE"
      scripts_registered=$((scripts_registered + 1))
    else
      log_error "Failed to register custom script: $name"
      printf '[Arrbit] ERROR Failed to register custom script "%s"\n' "$name" | arrbitLogClean >> "$LOG_FILE"
    fi
  done
done

if [[ $files_found -eq 0 ]]; then
  log_error "No payload files found matching $PAYLOAD_DIR/$PATTERN"
fi

#log_info "Done with ${SCRIPT_NAME} module! ($scripts_registered scripts registered)"
log_info "Log saved to $LOG_FILE"
exit 0

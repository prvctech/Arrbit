#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - custom_scripts.bash
# Version: v2.7-gs2.7
# Purpose: Registers all custom scripts found in /config/arrbit/modules/data/custom_script_*.json (GS2.7, minimal)
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="custom_scripts"
SCRIPT_VERSION="v2.7-gs2.7"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
PAYLOAD_DIR="/config/arrbit/modules/data"
PATTERN="custom_script_*.json"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  printf '[Arrbit] ERROR Could not source arr_bridge.bash\n[WHAT]: arr_bridge.bash is missing or failed to source\n[WHY]: Script not present or path misconfigured\n[HOW]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.\n' | arrbitLogClean >> "$LOG_FILE"
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
    is_obj=$(echo "$raw" | jq -er 'type == "object"' 2>/dev/null || echo "false")
    if [[ "$is_obj" != "true" ]]; then
      log_error "Payload in $file is not a valid object (see log at /config/logs)"
      printf '[Arrbit] ERROR Invalid payload in %s: %s\n[WHAT]: Payload is not a JSON object\n[WHY]: File contains malformed or non-object JSON\n[HOW]: Check structure of %s, must be array/object of scripts.\n' "$file" "$raw" "$file" | arrbitLogClean >> "$LOG_FILE"
      continue
    fi

    payload=$(echo "$raw" | jq 'del(.id)')
    name=$(echo "$payload" | jq -r '.name // empty')

    if [[ -z "$name" ]]; then
      log_error "Payload missing .name property in $file (see log at /config/logs)"
      printf '[Arrbit] ERROR Payload missing .name property in %s: %s\n[WHAT]: Script entry is missing .name\n[WHY]: JSON object is missing required "name" field\n[HOW]: Edit %s to ensure every object has "name".\n' "$file" "$payload" "$file" | arrbitLogClean >> "$LOG_FILE"
      continue
    fi

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
      printf '[Arrbit] SUCCESS custom script "%s" registered\n' "$name" | arrbitLogClean >> "$LOG_FILE"
      scripts_registered=$((scripts_registered + 1))
    else
      log_error "Failed to register custom script: $name (see log at /config/logs)"
      printf '[Arrbit] ERROR Failed to register custom script "%s"\n[WHAT]: Could not register custom script: %s\n[WHY]: API did not return id (bad payload, duplicate, or server error)\n[HOW]: Check payload fields and ARR server health. See [Response] below.\n[Response]\n%s\n[/Response]\n' "$name" "$name" "$response" | arrbitLogClean >> "$LOG_FILE"
    fi
  done
done

if [[ $files_found -eq 0 ]]; then
  log_error "No payload files found matching $PAYLOAD_DIR/$PATTERN (see log at /config/logs)"
  printf '[Arrbit] ERROR No payload files found matching %s\n[WHAT]: No JSON files matching pattern found\n[WHY]: No scripts to import; missing files or bad pattern\n[HOW]: Place your custom_script_*.json files in %s\n' "$PAYLOAD_DIR/$PATTERN" "$PAYLOAD_DIR" | arrbitLogClean >> "$LOG_FILE"
fi

log_info "Done."
exit 0

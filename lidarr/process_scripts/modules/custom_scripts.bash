#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit custom_scripts.bash
# Version: v2.1
# Purpose: Register tagger.bash as Lidarr custom script (Golden Standard compliant).
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="custom_scripts"
SCRIPT_VERSION="v2.1"
LOG_DIR="/config/logs"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
CYAN="\033[1;36m"
RESET="\033[0m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}custom_scripts module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API)
# ------------------------------------------------------------------------
if ! source /etc/services.d/arrbit/connectors/arr_bridge.bash; then
  arrbitErrorLog "❌  " \
    "${CYAN}[Arrbit]${RESET} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Check CONFIGURE_CUSTOM_SCRIPTS (always use flag helpers)
# ------------------------------------------------------------------------
CFG_FLAG=$(getFlag "CONFIGURE_CUSTOM_SCRIPTS")
: "${CFG_FLAG:=true}"

if [[ "${CFG_FLAG,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} Skipping custom_scripts module (flag disabled)"
  exit 0
fi

# ------------------------------------------------------------------------
# Check if already registered
# ------------------------------------------------------------------------
if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then
  arrbitLog "📥  ${ARRBIT_TAG} Registering arrbit-tagger script"

  payload='{
    "name": "arrbit-tagger",
    "implementation": "CustomScript",
    "configContract": "CustomScriptSettings",
    "onReleaseImport": true,
    "onUpgrade": true,
    "fields": [
      { "name": "path", "value": "/config/arrbit/process_scripts/tagger.bash" }
    ]
  }'

  # Log payload and response only to file
  echo "[Arrbit] Registering arrbit-tagger" >> "$log_file_path"
  echo "[Payload]" >> "$log_file_path"
  echo "$payload" >> "$log_file_path"
  echo "[/Payload]" >> "$log_file_path"

  response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  echo "[Response]" >> "$log_file_path"
  echo "$response" >> "$log_file_path"
  echo "[/Response]" >> "$log_file_path"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo "[SUCCESS] arrbit-tagger registered" >> "$log_file_path"
  else
    arrbitErrorLog "⚠️  " \
      "${CYAN}[Arrbit]${RESET} Failed to register arrbit-tagger script" \
      "register arrbit-tagger POST failed" \
      "${SCRIPT_NAME}.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "Tagger script registration failed" \
      "Check API connectivity and payload"
    echo "[ERROR] Failed to register arrbit-tagger" >> "$log_file_path"
  fi
else
  arrbitLog "⏩  ${ARRBIT_TAG} arrbit-tagger already registered; skipping"
  echo "[SKIP] arrbit-tagger already exists" >> "$log_file_path"
fi

arrbitLog "✅  ${ARRBIT_TAG} Done with custom_scripts module!"
exit 0

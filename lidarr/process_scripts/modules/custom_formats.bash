#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit custom_formats.bash
# Version: v2.1
# Purpose: Import custom formats from JSON into Lidarr. Golden Standard compliant.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="custom_formats"
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

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}custom_formats module${RESET} ${SCRIPT_VERSION}..."

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
# Check CONFIGURE_CUSTOM_FORMATS (always use flag helpers)
# ------------------------------------------------------------------------
CFG_FLAG=$(getFlag "CONFIGURE_CUSTOM_FORMATS")
: "${CFG_FLAG:=true}"

if [[ "${CFG_FLAG,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} Skipping custom_formats module (flag disabled)"
  exit 0
fi

JSON_PATH="/etc/services.d/arrbit/modules/data/custom_formats_master.json"

if [[ ! -f "$JSON_PATH" ]]; then
  arrbitErrorLog "⚠️  " \
    "${CYAN}[Arrbit]${RESET} File not found: ${JSON_PATH}" \
    "custom_formats_master.json missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required JSON not found" \
    "Check Arrbit data"
  exit 1
fi

arrbitLog "📄  ${ARRBIT_TAG} Reading custom formats from: ${JSON_PATH}"

existing_names=$(curl -s "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]')

jq -c '.[]' "$JSON_PATH" | while IFS= read -r format; do
  format_name=$(echo "$format" | jq -r '.name')
  format_id=$(echo "$format" | jq -r '.id')
  lowercase_name=$(echo "$format_name" | tr '[:upper:]' '[:lower:]')
  payload=$(echo "$format" | jq 'del(.id)')

  # Only log payload/response to file (not terminal), if needed for debugging
  echo "[Arrbit] Format: $format_name (ID: $format_id)" >> "$log_file_path"
  echo "[Payload]" >> "$log_file_path"
  echo "$payload" >> "$log_file_path"
  echo "[/Payload]" >> "$log_file_path"

  if echo "$existing_names" | grep -Fxq "$lowercase_name"; then
    arrbitLog "⏩  ${ARRBIT_TAG} Format already exists, skipping: ${format_name}"
    echo "[SKIP] Custom format already exists: $format_name" >> "$log_file_path"
    continue
  fi

  arrbitLog "📥  ${ARRBIT_TAG} Importing custom format: ${format_name}"

  response=$(curl -s -X POST "${arrUrl}/api/${arrApiVersion}/customformat?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    -d "$payload")

  echo "[Response]" >> "$log_file_path"
  echo "$response" >> "$log_file_path"
  echo "[/Response]" >> "$log_file_path"

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo "[SUCCESS] Custom format created: $format_name" >> "$log_file_path"
  else
    arrbitErrorLog "⚠️  " \
      "${CYAN}[Arrbit]${RESET} Failed to import format: ${format_name}" \
      "custom format POST failed" \
      "${SCRIPT_NAME}.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "Custom format creation failed" \
      "Check API connectivity and payload"
    echo "[ERROR] Failed to create custom format: $format_name" >> "$log_file_path"
  fi
done

arrbitLog "✅  ${ARRBIT_TAG} Done with custom_formats module!"
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v2.0-gs2.7.1
# Purpose: Golden Standard ARR API connector with dynamic API URL, port, and version detection.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="arr_bridge"
SCRIPT_VERSION="v2.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Banner (only one echo allowed)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} connector${NC} ${SCRIPT_VERSION}..."

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  log_error "ARR config.xml not found at $CONFIG_XML"
  exit 11
fi

# --- Check for required tools ---
if ! command -v jq &>/dev/null; then
  log_error "jq is not installed. Please install it with: apt-get update && apt-get install -y jq"
  exit 12
fi

# --- Function to extract value from XML using grep/sed fallback if xq is not available ---
extract_xml_value() {
  local xml_file="$1"
  local element="$2"
  
  # Try using xq if available
  if command -v xq &>/dev/null; then
    local value=$(cat "$xml_file" | xq | jq -r ".Config.$element")
    if [[ "$value" != "null" && -n "$value" ]]; then
      echo "$value"
      return 0
    fi
  fi
  
  # Fallback to grep/sed
  local value=$(grep -o "<$element>[^<]*</$element>" "$xml_file" | sed -e "s/<$element>//" -e "s/<\/$element>//")
  echo "$value"
}

# --- Extract ARR config values (url base, key, port) ---
arr_url_base=$(extract_xml_value "$CONFIG_XML" "UrlBase")
if [[ -n "$arr_url_base" ]]; then
  arr_url_base="/$(echo "$arr_url_base" | sed 's|^/||;s|/$||')"
else
  arr_url_base=""
fi

arr_api_key=$(extract_xml_value "$CONFIG_XML" "ApiKey")
if [[ -z "$arr_api_key" ]]; then
  log_error "API key not found in $CONFIG_XML"
  exit 13
fi

arr_port=$(extract_xml_value "$CONFIG_XML" "Port")
if [[ -z "$arr_port" ]]; then
  log_error "Port not found in $CONFIG_XML"
  exit 14
fi

# Allow ARR_URL override, else build from config
arrUrl="${ARR_URL:-http://127.0.0.1:${arr_port}${arr_url_base}}"
arrApiKey="$arr_api_key"

# --- API version auto-detection (tries v3, then v1) ---
arrApiVersion=""
for ver in v3 v1; do
  response="$(curl -s --fail "${arrUrl}/api/${ver}/system/status?apikey=${arrApiKey}" 2>/dev/null)"
  if echo "$response" | jq -e '.instanceName' >/dev/null 2>&1; then
    arrApiVersion="$ver"
    break
  fi
done

if [[ -z "$arrApiVersion" ]]; then
  log_error "Unable to detect working API version at $arrUrl (tried v3, v1)."
  exit 15
fi

export arrApiKey arrUrl arrApiVersion

# --- Wait for ARR API to become available ---
waitForArrApi() {
  local retries=12
  local url="${arrUrl}/api/${arrApiVersion}/system/status?apikey=REDACTED"
  for ((i=1; i<=retries; i++)); do
    if curl -s --fail "${arrUrl}/api/${arrApiVersion}/system/status?apikey=${arrApiKey}" >/dev/null; then
      return 0
    fi
    sleep 5
  done
  log_error "Could not connect to Arr API after $retries attempts. (Checked: $url)"
  exit 16
}
waitForArrApi

# --- Universal Arrbit API call wrapper ---
arr_api() {
  curl -s --fail --retry 3 --retry-delay 2 \
    -H "X-Api-Key: $arrApiKey" \
    -H "Content-Type: application/json" \
    "$@"
}
export -f arr_api

# Get instance name for logging
instance_response="$(arr_api "${arrUrl}/api/${arrApiVersion}/system/status")"
instance_name="$(echo "$instance_response" | jq -r '.instanceName // "ARR Service"')"

log_info "Connected to ${instance_name}"

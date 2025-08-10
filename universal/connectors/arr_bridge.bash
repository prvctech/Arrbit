#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v1.0.0-gs2.8.2
# Purpose: Golden Standard ARR API connector with fully dynamic API URL, port, and version detection.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="arr_bridge"
SCRIPT_VERSION="v1.0.0-gs2.8.2"
# Respect caller's LOG_FILE if already set, otherwise initialize our own
if [[ -z "${LOG_FILE:-}" ]]; then
  LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
fi

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  log_error "ARR config.xml not found (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR ARR config.xml not found
[WHY]: The config.xml file does not exist at $CONFIG_XML
[FIX]: Verify your ARR application is properly installed and configured
EOF
  return 11 2>/dev/null || exit 11
fi

# --- Extract ARR config values (url base, key, instance, port) ---
arr_url_base="$(cat "$CONFIG_XML" | xq | jq -r .Config.UrlBase)"
if [[ "$arr_url_base" == "null" || -z "$arr_url_base" ]]; then
  arr_url_base=""
else
  arr_url_base="/$(echo "$arr_url_base" | sed 's|^/||;s|/$||')"
fi

arr_api_key="$(cat "$CONFIG_XML" | xq | jq -r .Config.ApiKey)"
if [[ -z "$arr_api_key" || "$arr_api_key" == "null" ]]; then
  log_error "API key not found (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR API key not found in $CONFIG_XML
[WHY]: The ApiKey field is missing or empty in the config.xml file
[FIX]: Check your ARR application configuration and ensure the API key is properly set
EOF
  return 12 2>/dev/null || exit 12
fi

arr_instance_name="$(cat "$CONFIG_XML" | xq | jq -r .Config.InstanceName)"
if [[ "$arr_instance_name" == "null" || -z "$arr_instance_name" ]]; then
  arr_instance_name="Lidarr"  # fallback
fi

arr_port="$(cat "$CONFIG_XML" | xq | jq -r .Config.Port)"
if [[ -z "$arr_port" || "$arr_port" == "null" ]]; then
  case "${arr_instance_name,,}" in
    *sonarr*)  arr_port="8989";  log_warning "API port not found, falling back to :8989 (Sonarr default)" ;;
    *radarr*)  arr_port="7878";  log_warning "API port not found, falling back to :7878 (Radarr default)" ;;
    *)         arr_port="8686";  log_warning "API port not found, falling back to :8686 (Lidarr default)" ;;
  esac
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
  log_error "Unable to detect working API version (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Unable to detect working API version at $arrUrl
[WHY]: API calls to both v3 and v1 endpoints failed or returned invalid responses
[FIX]: Check your ARR application status, network connectivity, and API configuration
[Tested URLs]
${arrUrl}/api/v3/system/status
${arrUrl}/api/v1/system/status
[/Tested URLs]
EOF
  return 13 2>/dev/null || exit 13
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
  log_error "Could not connect to ARR API after $retries attempts (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not connect to ARR API after $retries attempts
[WHY]: API endpoint is not responding after multiple connection attempts
[FIX]: Check if your ARR application is running and accessible at $url
[Connection Details]
URL: $arrUrl
Port: $arr_port
Instance: $arr_instance_name
[/Connection Details]
EOF
  return 14 2>/dev/null || exit 14
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

log_info "Connected to ${arr_instance_name}"
# If sourced, return; if executed directly, exit
return 0 2>/dev/null || exit 0

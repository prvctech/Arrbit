#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v1.1.0-gs3.1.0
# Purpose: Golden Standard ARR API connector with fully dynamic API URL, port, and version detection.
# -------------------------------------------------------------------------------------------------------------

# Fixed base path model (auto-detection deprecated gs3.1.0)
ARRBIT_BASE="/app/arrbit"
source "$ARRBIT_BASE/universal/helpers/logging_utils.bash"
source "$ARRBIT_BASE/universal/helpers/helpers.bash"

arrbitPurgeOldLogs

SCRIPT_NAME="arr_bridge"
SCRIPT_VERSION="v1.0.0-gs3.0.0"

# Initialize logging
if [[ -z "${LOG_FILE:-}" ]]; then
  LOG_FILE="${ARRBIT_LOGS_DIR}/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
fi
mkdir -p "${ARRBIT_LOGS_DIR}" && touch "$LOG_FILE" && chmod 644 "$LOG_FILE"

CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  log_error "ARR config.xml not found (see log at ${ARRBIT_LOGS_DIR})"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR ARR config.xml not found
CAUSE: The config.xml file does not exist at $CONFIG_XML
RESOLUTION: Verify your ARR application is properly installed and configured
CONTEXT: This file is required for ARR API connectivity and configuration
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
  log_error "API key not found (see log at ${ARRBIT_LOGS_DIR})"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR API key not found in $CONFIG_XML
CAUSE: The ApiKey field is missing or empty in the config.xml file
RESOLUTION: Check your ARR application configuration and ensure the API key is properly set
CONTEXT: The API key is required for authenticated access to the ARR API
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
  log_error "Unable to detect working API version (see log at ${ARRBIT_LOGS_DIR})"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Unable to detect working API version at $arrUrl
CAUSE: API calls to both v3 and v1 endpoints failed or returned invalid responses
RESOLUTION: Check your ARR application status, network connectivity, and API configuration
CONTEXT: Tested endpoints: ${arrUrl}/api/v3/system/status and ${arrUrl}/api/v1/system/status
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
  log_error "Could not connect to ARR API after $retries attempts (see log at ${ARRBIT_LOGS_DIR})"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not connect to ARR API after $retries attempts
CAUSE: API endpoint is not responding after multiple connection attempts
RESOLUTION: Check if your ARR application is running and accessible at ${arrUrl}/api/${arrApiVersion}/system/status
CONTEXT: URL: $arrUrl, Port: $arr_port, Instance: $arr_instance_name
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
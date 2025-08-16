#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v1.1.0-gs3.1.0
# Purpose: Golden Standard ARR API connector with fully dynamic API URL, port, and version detection.
# -------------------------------------------------------------------------------------------------------------

ARRBIT_BASE="/app/arrbit"
source "$ARRBIT_BASE/universal/helpers/logging_utils.bash"
source "$ARRBIT_BASE/universal/helpers/helpers.bash"

arrbitPurgeOldLogs

SCRIPT_NAME="arr_bridge"
SCRIPT_VERSION="v1.1.0-gs3.1.0"

# Initialize logging (log_level exported by helpers)
LOG_FILE="${ARRBIT_LOGS_DIR}/arrbit-${SCRIPT_NAME}-${log_level}-$(date +%Y_%m_%d-%H_%M).log"
arrbitInitLog "$LOG_FILE" || { echo "[Arrbit] ERROR: could not initialize log file" >&2; return 1 2>/dev/null || exit 1; }
chmod 644 "$LOG_FILE" 2>/dev/null || true

CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  log_error "ARR config.xml not found"
  printf '[Arrbit] ERROR: ARR config.xml not found (%s)\n' "$CONFIG_XML" | arrbitLogClean >> "$LOG_FILE"
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
  log_error "API key not found"
  printf '[Arrbit] ERROR: API key not found in %s\n' "$CONFIG_XML" | arrbitLogClean >> "$LOG_FILE"
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
  # Use X-Api-Key header for detection (do not embed key in URL)
  response="$(curl -s --fail -H "X-Api-Key: $arr_api_key" "${arrUrl}/api/${ver}/system/status" 2>/dev/null)"
  if echo "$response" | jq -e '.instanceName' >/dev/null 2>&1; then
    arrApiVersion="$ver"
    break
  fi
done

if [[ -z "$arrApiVersion" ]]; then
  log_error "Unable to detect working API version"
  printf '[Arrbit] ERROR: Unable to detect working API version at %s\n' "$arrUrl" | sed -E 's/(apikey=[^ &]*)/REDACTED/' | arrbitLogClean >> "$LOG_FILE"
  return 13 2>/dev/null || exit 13
fi

export arrApiKey arrUrl arrApiVersion

# --- Wait for ARR API to become available ---
waitForArrApi() {
  local retries=12
  local url="${arrUrl}/api/${arrApiVersion}/system/status?apikey=REDACTED"
  for ((i=1; i<=retries; i++)); do
    if curl -s --fail -H "X-Api-Key: $arrApiKey" "${arrUrl}/api/${arrApiVersion}/system/status" >/dev/null 2>/dev/null; then
      return 0
    fi
    sleep 5
  done
  log_error "Could not connect to ARR API after $retries attempts"
  printf '[Arrbit] ERROR: Could not connect to ARR API after %s attempts; URL=%s Port=%s Instance=%s\n' "$retries" "$arrUrl" "$arr_port" "$arr_instance_name" | sed -E 's/(apikey=[^ &]*)/REDACTED/' | arrbitLogClean >> "$LOG_FILE"
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
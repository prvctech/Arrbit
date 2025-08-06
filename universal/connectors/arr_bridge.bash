#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v2.0-gs2.7.1
# Purpose: Golden Standard ARR API connector using YAML configuration
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/config_utils.bash
arrbitPurgeOldLogs

SCRIPT_NAME="arr_bridge"
SCRIPT_VERSION="v2.0-gs2.7.1"

# --- 1. Check YAML configuration exists ---
if ! config_exists; then
  log_error "Configuration file missing: arrbit-config.yaml"
  cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Configuration file missing
[WHY]: arrbit-config.yaml not found in /config/arrbit/config/
[FIX]: Create a configuration file based on the example in the repository
EOF
  exit 1
fi

# --- 2. Get API configuration from YAML ---
arr_api_key=$(get_yaml_value "api.key")
arr_instance_name=$(get_yaml_value "api.instance_name")
arr_port=$(get_yaml_value "api.port")
arr_url_base=$(get_yaml_value "api.url_base")
custom_url=$(get_yaml_value "api.url")

# --- 3. Validate API key ---
if [[ -z "$arr_api_key" || "$arr_api_key" == "null" ]]; then
  log_error "API key not found in configuration"
  cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR API key not found in configuration
[WHY]: The api.key setting is missing or empty in arrbit-config.yaml
[FIX]: Add your API key to the configuration file:
      api:
        key: "your-api-key-here"
EOF
  exit 1
fi

# --- 4. Set default values for missing configuration ---
if [[ -z "$arr_instance_name" || "$arr_instance_name" == "null" ]]; then
  arr_instance_name="Lidarr"
  log_warning "Instance name not found in configuration, using default: $arr_instance_name"
fi

if [[ -z "$arr_port" || "$arr_port" == "null" ]]; then
  # Set default port based on instance name
  case "${arr_instance_name,,}" in
    *sonarr*)  arr_port="8989";  log_warning "API port not found in configuration, using Sonarr default: $arr_port" ;;
    *radarr*)  arr_port="7878";  log_warning "API port not found in configuration, using Radarr default: $arr_port" ;;
    *readarr*) arr_port="8787";  log_warning "API port not found in configuration, using Readarr default: $arr_port" ;;
    *)         arr_port="8686";  log_warning "API port not found in configuration, using Lidarr default: $arr_port" ;;
  esac
fi

if [[ -z "$arr_url_base" || "$arr_url_base" == "null" ]]; then
  arr_url_base=""
else
  # Ensure URL base has leading slash but no trailing slash
  arr_url_base="/$(echo "$arr_url_base" | sed 's|^/||;s|/$||')"
fi

# --- 5. Set API URL ---
if [[ -n "$custom_url" && "$custom_url" != "null" ]]; then
  # Use custom URL if provided
  arrUrl="$custom_url"
  log_info "Using custom API URL from configuration: $arrUrl"
else
  # Build URL from components
  arrUrl="http://127.0.0.1:${arr_port}${arr_url_base}"
  log_info "Using API URL: $arrUrl"
fi

arrApiKey="$arr_api_key"

# --- 6. API version auto-detection (tries v3, then v1) ---
log_info "Detecting API version..."
arrApiVersion=""
for ver in v3 v1; do
  response="$(curl -s --fail "${arrUrl}/api/${ver}/system/status?apikey=${arrApiKey}" 2>/dev/null)"
  if echo "$response" | jq -e '.instanceName' >/dev/null 2>&1; then
    arrApiVersion="$ver"
    log_info "Detected API version: $arrApiVersion"
    break
  fi
done

if [[ -z "$arrApiVersion" ]]; then
  log_error "Unable to detect working API version at $arrUrl (tried v3, v1)"
  cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Unable to detect working API version
[WHY]: Could not connect to API at $arrUrl with the provided key
[FIX]: Check your API configuration in arrbit-config.yaml:
      - Verify the API key is correct
      - Check that the port and URL base are correct
      - Ensure the *arr service is running and accessible
EOF
  exit 1
fi

export arrApiKey arrUrl arrApiVersion

# --- 7. Wait for ARR API to become available ---
waitForArrApi() {
  local retries=12
  local url="${arrUrl}/api/${arrApiVersion}/system/status?apikey=REDACTED"
  log_info "Waiting for API to become available..."
  
  for ((i=1; i<=retries; i++)); do
    if curl -s --fail "${arrUrl}/api/${arrApiVersion}/system/status?apikey=${arrApiKey}" >/dev/null; then
      log_info "API is available"
      return 0
    fi
    log_info "Attempt $i of $retries: API not yet available, waiting 5 seconds..."
    sleep 5
  done
  
  log_error "Could not connect to API after $retries attempts"
  cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Could not connect to API
[WHY]: API did not become available after $retries attempts (Checked: $url)
[FIX]: Check that the *arr service is running and accessible
      Verify your network configuration and firewall settings
EOF
  exit 1
}
waitForArrApi

# --- 8. Universal Arrbit API call wrapper ---
arr_api() {
  curl -s --fail --retry 3 --retry-delay 2 \
    -H "X-Api-Key: $arrApiKey" \
    -H "Content-Type: application/json" \
    "$@"
}
export -f arr_api

log_success "Connected to ${arr_instance_name} API (${arrApiVersion})"

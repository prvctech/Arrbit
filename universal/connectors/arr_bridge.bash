#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v2.0-gs2.7.1
# Purpose: Golden Standard ARR API connector with YAML configuration support and dynamic API detection
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/config_utils.bash

arrbitPurgeOldLogs

SCRIPT_NAME="arr_bridge"
SCRIPT_VERSION="v2.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Banner (only one echo allowed)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} connector${NC} ${SCRIPT_VERSION}..."

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- 1. Check if YAML configuration exists ---
if ! config_exists; then
  log_warning "YAML configuration not found, falling back to XML-only mode"
  USE_YAML=false
else
  USE_YAML=true
  
  # Check if API settings are defined in YAML
  API_URL=$(get_yaml_value "api.url")
  API_KEY=$(get_yaml_value "api.key")
  API_VERSION=$(get_yaml_value "api.version")
  
  # Validate if validator is available
  if type validate_string >/dev/null 2>&1; then
    if ! validate_string "api.url" "$API_URL"; then
      API_URL=""
    fi
    if ! validate_string "api.key" "$API_KEY"; then
      API_KEY=""
    fi
    if ! validate_string "api.version" "$API_VERSION"; then
      API_VERSION=""
    fi
  fi
  
  # If any of the API settings are missing, fall back to XML
  if [[ -z "$API_URL" || -z "$API_KEY" ]]; then
    log_warning "API settings incomplete in YAML, falling back to XML for missing values"
  fi
fi

# --- 2. Get configuration from XML if needed ---
CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  if [[ "$USE_YAML" == "true" && -n "$API_URL" && -n "$API_KEY" ]]; then
    log_warning "ARR config.xml not found at $CONFIG_XML, using YAML configuration only"
  else
    log_error "ARR config.xml not found at $CONFIG_XML and YAML configuration is incomplete"
    cat <<EOFERR | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR ARR config.xml not found
[WHY]: The config.xml file is missing and YAML configuration is incomplete
[FIX]: Either create a valid config.xml file or provide complete API settings in arrbit-config.yaml:
      api:
        url: "http://localhost:8686"
        key: "your_api_key"
        version: "v1"
EOFERR
    exit 11
  fi
else
  # Only extract from XML if we need to (if YAML values are missing)
  if [[ "$USE_YAML" != "true" || -z "$API_URL" || -z "$API_KEY" ]]; then
    log_info "Extracting configuration from XML"
    
    # --- Extract ARR config values (url base, key, instance, port) ---
    arr_url_base="$(cat "$CONFIG_XML" | xq | jq -r .Config.UrlBase)"
    if [[ "$arr_url_base" == "null" || -z "$arr_url_base" ]]; then
      arr_url_base=""
    else
      arr_url_base="/$(echo "$arr_url_base" | sed 's|^/||;s|/$||')"
    fi

    arr_api_key="$(cat "$CONFIG_XML" | xq | jq -r .Config.ApiKey)"
    if [[ -z "$arr_api_key" || "$arr_api_key" == "null" ]]; then
      if [[ -z "$API_KEY" ]]; then
        log_error "API key not found in $CONFIG_XML or YAML configuration"
        cat <<EOFERR | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR API key not found
[WHY]: The API key is missing from both config.xml and YAML configuration
[FIX]: Either update config.xml with a valid API key or provide it in arrbit-config.yaml:
      api:
        key: "your_api_key"
EOFERR
        exit 12
      fi
    else
      # Only use XML API key if YAML one is not set
      if [[ -z "$API_KEY" ]]; then
        API_KEY="$arr_api_key"
      fi
    fi

    arr_instance_name="$(cat "$CONFIG_XML" | xq | jq -r .Config.InstanceName)"
    if [[ "$arr_instance_name" == "null" || -z "$arr_instance_name" ]]; then
      arr_instance_name="Lidarr"  # fallback
    fi

    arr_port="$(cat "$CONFIG_XML" | xq | jq -r .Config.Port)"
    if [[ -z "$arr_port" || "$arr_port" == "null" ]]; then
      case "${arr_instance_name,,}" in
        *sonarr*)  arr_port="8989";  log_warning "API port not found in config.xml, falling back to :8989 (Sonarr default)." ;;
        *radarr*)  arr_port="7878";  log_warning "API port not found in config.xml, falling back to :7878 (Radarr default)." ;;
        *readarr*) arr_port="8787";  log_warning "API port not found in config.xml, falling back to :8787 (Readarr default)." ;;
        *)         arr_port="8686";  log_warning "API port not found in config.xml, falling back to :8686 (Lidarr default)." ;;
      esac
    fi
    
    # Only build URL from XML if YAML URL is not set
    if [[ -z "$API_URL" ]]; then
      API_URL="http://127.0.0.1:${arr_port}${arr_url_base}"
    fi
  fi
fi

# --- 3. Set final API variables with priority to environment variables ---
arrUrl="${ARR_URL:-$API_URL}"
arrApiKey="${ARR_API_KEY:-$API_KEY}"
arrApiVersion="${ARR_API_VERSION:-$API_VERSION}"

# --- 4. API version auto-detection if not specified ---
if [[ -z "$arrApiVersion" ]]; then
  log_info "Auto-detecting API version"
  for ver in v3 v1; do
    response="$(curl -s --fail "${arrUrl}/api/${ver}/system/status?apikey=${arrApiKey}" 2>/dev/null)"
    if echo "$response" | jq -e '.instanceName' >/dev/null 2>&1; then
      arrApiVersion="$ver"
      log_info "Detected API version: $arrApiVersion"
      break
    fi
  done

  if [[ -z "$arrApiVersion" ]]; then
    log_error "Unable to detect working API version at $arrUrl (tried v3, v1)."
    cat <<EOFERR | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Unable to detect API version
[WHY]: Could not connect to API at $arrUrl with any known version
[FIX]: Check that the ARR service is running and accessible, or specify the API version in arrbit-config.yaml:
      api:
        version: "v1"
EOFERR
    exit 13
  fi
fi

export arrApiKey arrUrl arrApiVersion

# --- 5. Wait for ARR API to become available ---
waitForArrApi() {
  local retries=12
  local url="${arrUrl}/api/${arrApiVersion}/system/status?apikey=REDACTED"
  log_info "Waiting for API to become available..."
  for ((i=1; i<=retries; i++)); do
    if curl -s --fail "${arrUrl}/api/${arrApiVersion}/system/status?apikey=${arrApiKey}" >/dev/null; then
      log_success "API connection established"
      return 0
    fi
    log_warning "API not available, retry $i of $retries..."
    sleep 5
  done
  log_error "Could not connect to Arr API after $retries attempts. (Checked: $url)"
  cat <<EOFERR | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not connect to API
[WHY]: API did not respond after $retries attempts
[FIX]: Check that the ARR service is running and accessible at $arrUrl
      Verify that the API key is correct
      Check network connectivity between Arrbit and ARR service
EOFERR
  exit 14
}
waitForArrApi

# --- 6. Universal Arrbit API call wrapper ---
arr_api() {
  curl -s --fail --retry 3 --retry-delay 2 \
    -H "X-Api-Key: $arrApiKey" \
    -H "Content-Type: application/json" \
    "$@"
}
export -f arr_api

# --- 7. Get instance name for logging ---
instance_response="$(arr_api "${arrUrl}/api/${arrApiVersion}/system/status")"
instance_name="$(echo "$instance_response" | jq -r '.instanceName // "ARR Service"')"

log_info "Connected to ${instance_name}"
log_info "API URL: ${arrUrl}/api/${arrApiVersion}"
printf '[Arrbit] Connected to %s\n[Arrbit] API URL: %s/api/%s\n' "$instance_name" "$arrUrl" "$arrApiVersion" | arrbitLogClean >> "$LOG_FILE"

# --- 8. Log completion ---
log_info "Log saved to $LOG_FILE"

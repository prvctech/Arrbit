#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit arr_bridge.bash
# Version: v2.1
# Purpose: Sets up API variables for Arrbit modules and ensures API is reachable before proceeding.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

CONFIG_XML="/config/config.xml"

# -------------------------------------------------------
# Extract arrApiKey and arrApiVersion from config file or env
# -------------------------------------------------------
if [[ -f "$CONFIG_XML" ]]; then
  if command -v xmlstarlet &>/dev/null; then
    arrApiKey=$(xmlstarlet sel -t -v "//ApiKey" "$CONFIG_XML" 2>/dev/null)
    arrPort=$(xmlstarlet sel -t -v "//Port" "$CONFIG_XML" 2>/dev/null)
    arrSsl=$(xmlstarlet sel -t -v "//SslPort" "$CONFIG_XML" 2>/dev/null)
    arrUseSsl=$(xmlstarlet sel -t -v "//EnableSsl" "$CONFIG_XML" 2>/dev/null)
  else
    arrApiKey=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "$CONFIG_XML" 2>/dev/null)
    arrPort=$(grep -oPm1 "(?<=<Port>)[^<]+" "$CONFIG_XML" 2>/dev/null)
    arrSsl=$(grep -oPm1 "(?<=<SslPort>)[^<]+" "$CONFIG_XML" 2>/dev/null)
    arrUseSsl=$(grep -oPm1 "(?<=<EnableSsl>)[^<]+" "$CONFIG_XML" 2>/dev/null)
  fi

  if [[ "$arrUseSsl" == "true" ]]; then
    arrUrl="https://127.0.0.1:${arrSsl:-8686}"
  else
    arrUrl="http://127.0.0.1:${arrPort:-8686}"
  fi
else
  arrbitErrorLog "❌   " \
    "[Arrbit] $CONFIG_XML missing! Can't set API URL or key." \
    "config.xml missing" \
    "arr_bridge.bash" \
    "arr_bridge.bash:$LINENO" \
    "Required config missing" \
    "Check your container or bind mount."
  exit 1
fi

arrApiVersion=$(getFlag "API_VERSION")
: "${arrApiVersion:=v1}"

# -------------------------------------------------------
# Log found value (minimal: only Found and Connected)
# -------------------------------------------------------
arrbitLog "🔵  ${ARRBIT_TAG} Found Lidarr instance at $arrUrl"

# -------------------------------------------------------
# Wait for API (minimal: only logs when connected or on fatal error)
# -------------------------------------------------------
waitForArrApi() {
  local url="$1"
  local key="$2"
  local version="$3"
  local tries=0
  local endpoint="system/status"
  local statusName

  while true; do
    statusName=$(curl -s --max-time 3 "$url/api/$version/$endpoint?apikey=$key" | jq -r .instanceName 2>/dev/null)
    if [ -n "$statusName" ] && [ "$statusName" != "null" ]; then
      arrbitLog "🟢  ${ARRBIT_TAG} Connected to Lidarr at $url (API $version)"
      break
    fi
    tries=$((tries+1))
    if (( tries >= 20 )); then
      arrbitErrorLog "❌   " \
        "[Arrbit] API at $url not available after 20 tries" \
        "API wait failed" \
        "waitForArrApi" \
        "arr_bridge.bash:$LINENO" \
        "No response from API" \
        "Check if server is up and config is correct"
      exit 1
    fi
    sleep 2
  done
}

waitForArrApi "$arrUrl" "$arrApiKey" "$arrApiVersion"

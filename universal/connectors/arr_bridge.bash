#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v1.2-gs2.5
# Purpose: Golden Standard connector for ARR APIs; exports arr_api + connection vars.
# -------------------------------------------------------------------------------------------------------------

# Source helpers/logging first (Golden Standard)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

# Use main config.xml for API info (user: single-instance stack)
CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  log_error "ARR config.xml not found at $CONFIG_XML"
  exit 1
fi

# Parse and export ARR API credentials (never log these values)
arrApiKey=$(awk -F'[<>]' '/<ApiKey>/ {print $3}' "$CONFIG_XML" | head -n1)
arrUrl="http://localhost:8686"    # Override as needed, or make dynamic if you support multi-ARR
arrApiVersion="v1"                # Default; override if you add detection logic

export arrApiKey arrUrl arrApiVersion

# Wait for API to become available (all output via log_error, never echo)
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
  exit 1
}
waitForArrApi

# Universal Arrbit API call wrapper (only ever use this)
arr_api() {
  curl -s --fail --retry 3 --retry-delay 2 \
    -H "X-Api-Key: $arrApiKey" \
    -H "Content-Type: application/json" \
    "$@"
}
export -f arr_api

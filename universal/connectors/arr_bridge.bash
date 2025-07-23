# -------------------------------------------------------------------------------------------------------------
# Arrbit - arr_bridge.bash
# Version: v1.2
# Purpose: Connects to Lidarr/Sonarr/Radarr instance, extracts API key/version/URL, exports for modules,
#          and provides a universal API call wrapper for all downstream modules.
# -------------------------------------------------------------------------------------------------------------

# --- Source helpers (for logging, etc) ---
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

# --- Find and extract required config values ---
CONFIG_XML="/config/config.xml"

if [[ ! -f "$CONFIG_XML" ]]; then
  echo -e "\033[36m[Arrbit]\033[0m ERROR: Lidarr config.xml not found at $CONFIG_XML"
  exit 1
fi

arrApiKey=$(awk -F'[<>]' '/<ApiKey>/ {print $3}' "$CONFIG_XML" | head -n1)
arrUrl="http://localhost:8686"  # You might want to extract this if dynamic, otherwise keep default
arrApiVersion="v1"              # Default, can be made dynamic if needed

export arrApiKey arrUrl arrApiVersion

# --- Wait for API to become available (Golden Standard logic) ---
waitForArrApi() {
  local retries=12
  local url="${arrUrl}/api/${arrApiVersion}/system/status?apikey=${arrApiKey}"
  for ((i=1; i<=retries; i++)); do
    if curl -s --fail "$url" >/dev/null; then
      return 0
    fi
    sleep 5
  done
  echo -e "\033[36m[Arrbit]\033[0m ERROR: Could not connect to Arr API after $retries attempts."
  exit 1
}
waitForArrApi

# --- Universal Arrbit API call wrapper ---
#   Usage: arr_api [curl options] <URL>
#   Example: arr_api -X GET "${arrUrl}/api/${arrApiVersion}/qualityprofile"
arr_api() {
  curl -s --fail --retry 3 --retry-delay 2 \
    -H "X-Api-Key: $arrApiKey" \
    -H "Content-Type: application/json" \
    "$@"
}
export -f arr_api

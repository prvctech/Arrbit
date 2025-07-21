#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [arr_bridge]
# Version: v2.0
# Purpose: Connects Arrbit modules to Lidarr/Sonarr/etc. via HTTP. Handles API key, base URL, and API version.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------------
# ENV / PATHS
# ------------------------------------------------------------
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
scriptName="arr_bridge"
scriptVersion="v2.0"
logFilePath="$LOG_DIR/arrbit-${scriptName}-$(date +%d-%m-%Y-%H:%M).log"

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------
logRaw() {
  local msg="$1"
  msg=$(echo -e "$msg" | tr -d "🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴💾")
  msg=$(echo -e "$msg" | sed -E "s/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g")
  msg=$(echo -e "$msg" | sed -E "s/^[[:space:]]+\[Arrbit\]/[Arrbit]/")
  echo "$msg" >> "$logFilePath"
}

log() {
  echo -e "$1"
  logRaw "$1"
}

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${scriptName}-*.log" -mtime +5 -delete
touch "$logFilePath"
chmod 666 "$logFilePath"

log "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}${scriptName}\033[0m service ${scriptVersion}..."

# ------------------------------------------------------------
# LOAD CONFIG (API Key, Base URL)
# ------------------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  log "❌  ${ARRBIT_TAG} Config file missing at $CONFIG_FILE"
  exit 1
fi

arrUrl=$(awk -F= '$1=="ARR_URL"{print $2}' "$CONFIG_FILE" | tr -d '\r"')
arrApiKey=$(awk -F= '$1=="ARR_API_KEY"{print $2}' "$CONFIG_FILE" | tr -d '\r"')

if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
  log "❌  ${ARRBIT_TAG} ARR_URL or ARR_API_KEY is missing in config"
  exit 1
fi

export arrUrl
export arrApiKey

log "🔧  ${ARRBIT_TAG} ARR_URL and API key loaded (key redacted)"

# ------------------------------------------------------------
# Determine API Version (prefer v3, fallback to v1)
# ------------------------------------------------------------
statusV3=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "X-Api-Key: $arrApiKey" \
  "$arrUrl/api/v3/system/status")

if [[ "$statusV3" == "200" ]]; then
  arrApiVersion="v3"
else
  arrApiVersion="v1"
fi
export arrApiVersion

log "🔵  ${ARRBIT_TAG} Detected API version: $arrApiVersion"

# ------------------------------------------------------------
# Usage helper (optional)
# ------------------------------------------------------------
exportArrInfo() {
  echo "ARR URL: $arrUrl"
  echo "API Version: $arrApiVersion"
}

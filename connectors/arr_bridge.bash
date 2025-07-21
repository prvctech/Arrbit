#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [arr_bridge]
# Version: v2.3
# Purpose: Connects Arrbit modules to Lidarr/Sonarr/etc. via HTTP. Detects API key, base URL, version.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
APP_XML="/config/config.xml"
scriptName="arr_bridge"
scriptVersion="v2.3"
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

# ------------------------------------------------------------
# DETECT ARR DATA FROM config.xml using xq + jq
# ------------------------------------------------------------
if [ ! -f "$APP_XML" ]; then
  log "❌  ${ARRBIT_TAG} Config file $APP_XML not found!"
  exit 1
fi

arrUrlBase=$(cat "$APP_XML" | xq | jq -r .Config.UrlBase)
arrPort=$(cat "$APP_XML" | xq | jq -r .Config.Port)
arrApiKey=$(cat "$APP_XML" | xq | jq -r .Config.ApiKey)
arrAppName=$(cat "$APP_XML" | xq | jq -r .Config.InstanceName)

arrUrlBase=${arrUrlBase#/}  # strip leading slash if present
arrUrl="http://127.0.0.1:${arrPort}/${arrUrlBase}"
arrAppName=${arrAppName:-"ARR"}

if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
  log "❌  ${ARRBIT_TAG} Failed to extract arrUrl or arrApiKey from config.xml"
  exit 1
fi

export arrUrl
export arrApiKey
export arrAppName

log "🔵  ${ARRBIT_TAG} Found ${arrAppName} instance at $arrUrl"

# ------------------------------------------------------------
# DETERMINE API VERSION (prefer v3, fallback to v1)
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

log "🟢  ${ARRBIT_TAG} Connected to ${arrAppName} instance using API $arrApiVersion"

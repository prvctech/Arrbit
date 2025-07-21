#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [arr_bridge]
# Version: v2.4
# Purpose: Connects Arrbit modules to Lidarr/Sonarr/etc. via HTTP. No xq required.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
APP_XML="/config/config.xml"
scriptName="arr_bridge"
scriptVersion="v2.4"
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
# EXTRACT CONFIG.XML FIELDS USING GREP/SED
# ------------------------------------------------------------
if [ ! -f "$APP_XML" ]; then
  log "❌  ${ARRBIT_TAG} $APP_XML not found!"
  exit 1
fi

arrPort=$(grep -oPm1 "(?<=<Port>)[^<]+" "$APP_XML" || true)
arrUrlBase=$(grep -oPm1 "(?<=<UrlBase>)[^<]+" "$APP_XML" || true)
arrApiKey=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "$APP_XML" || true)
arrAppName=$(grep -oPm1 "(?<=<InstanceName>)[^<]+" "$APP_XML" || true)

arrUrlBase=${arrUrlBase#/}  # remove leading slash if exists
arrAppName=${arrAppName:-"ARR"}
arrUrl="http://127.0.0.1:${arrPort}/${arrUrlBase}"

if [ -z "$arrPort" ] || [ -z "$arrApiKey" ]; then
  log "❌  ${ARRBIT_TAG} Could not extract arrPort or arrApiKey from $APP_XML"
  exit 1
fi

export arrUrl
export arrApiKey
export arrAppName

log "🔧  ${ARRBIT_TAG} Discovered $arrAppName URL and API key (key redacted)"
log "🔵  ${ARRBIT_TAG} Found ${arrAppName} instance at $arrUrl"

# ------------------------------------------------------------
# DETERMINE API VERSION
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

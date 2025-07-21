#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [arr_bridge]
# Version: v2.5
# Purpose: Connects Arrbit modules to Lidarr/Sonarr/etc. via HTTP. Discovers API key, URL, and version.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------------
# ENV / PATHS
# ------------------------------------------------------------
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
APP_XML="/config/config.xml"
scriptName="arr_bridge"
scriptVersion="v2.5"
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
# 1. PARSE config.xml for URL, KEY, PORT
# ------------------------------------------------------------
if [ ! -f "$APP_XML" ]; then
  log "❌  ${ARRBIT_TAG} $APP_XML not found!"
  exit 1
fi

port=$(grep -m1 '<Port>' "$APP_XML" | sed -E 's/.*<Port>([^<]+)<\/Port>.*/\1/')
key=$(grep -m1 '<ApiKey>' "$APP_XML" | sed -E 's/.*<ApiKey>([^<]+)<\/ApiKey>.*/\1/')
base=$(grep -m1 '<UrlBase>' "$APP_XML" | sed -E 's/.*<UrlBase>([^<]*)<\/UrlBase>.*/\1/')
appName=$(grep -m1 '<InstanceName>' "$APP_XML" | sed -E 's/.*<InstanceName>([^<]+)<\/InstanceName>.*/\1/')

if [ -z "$port" ] || [ -z "$key" ]; then
  log "❌  ${ARRBIT_TAG} Could not extract Port or ApiKey from config.xml"
  exit 1
fi

basePath=""
if [ -n "$base" ]; then
  basePath="/${base#/}"
fi

arrUrl="http://127.0.0.1:${port}${basePath}"
arrApiKey="$key"
arrAppName="${appName:-ARR}"

export arrUrl
export arrApiKey
export arrAppName

log "🔵  ${ARRBIT_TAG} Found ${arrAppName} instance at $arrUrl"

# ------------------------------------------------------------
# 2. DETECT API VERSION
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

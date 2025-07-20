#!/usr/bin/env bash
#
# Arrbit Functions
# Shared helper functions for Arrbit scripts
# Version: v1.4
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
ARRBIT_CONF="/config/arrbit/config/arrbit-config.conf"

# -----------------------------------------------------------------------------
# Config validation: ensure config file exists
# -----------------------------------------------------------------------------
if [ ! -f "$ARRBIT_CONF" ]; then
  echo -e "❌  ${ARRBIT_TAG} ERROR: \"arrbit-config.conf\" is missing at /config/arrbit/config/"
  exit 1
fi

# Load all config flags (no validation of specific flags here)
source "$ARRBIT_CONF"

# -----------------------------------------------------------------------------
# log: timestamped logging to both stdout and Arrbit log folder
# -----------------------------------------------------------------------------
log() {
  local m_time
  m_time=$(date "+%F %T")
  echo "${m_time} :: ${scriptName} :: ${scriptVersion} :: $1"
  echo "${m_time} :: ${scriptName} :: ${scriptVersion} :: $1" \
    >> "/config/logs/${logFileName}"
}

# -----------------------------------------------------------------------------
# logfileSetup: rotate old logs and create a fresh Arrbit log file
# -----------------------------------------------------------------------------
logfileSetup() {
  logFileName="${scriptName}-$(date +"%Y_%m_%d_%I_%M_%p").txt"

  mkdir -p /config/logs
  find "/config/logs" -type f -iname "${scriptName}-*.txt" -mtime +5 -delete

  if [ ! -f "/config/logs/${logFileName}" ]; then
    echo "" > "/config/logs/${logFileName}"
    chmod 666 "/config/logs/${logFileName}"
  fi
}

# -----------------------------------------------------------------------------
# getArrAppInfo: read URL, port, base path & API key from /config/config.xml
# -----------------------------------------------------------------------------
getArrAppInfo() {
  local xml="/config/config.xml"
  local port key base basePath

  port=$(grep -m1 '<Port>' "$xml" | sed -E 's/.*<Port>([^<]+)<\/Port>.*/\1/')
  key=$(grep -m1 '<ApiKey>' "$xml" | sed -E 's/.*<ApiKey>([^<]+)<\/ApiKey>.*/\1/')
  base=$(grep -m1 '<UrlBase>' "$xml" | sed -E 's/.*<UrlBase>([^<]*)<\/UrlBase>.*/\1/')

  if [ -z "$base" ]; then
    basePath=""
  else
    basePath="/${base#/}"
  fi

  arrApiKey="$key"
  arrUrl="http://127.0.0.1:${port}${basePath}"

  log "✅  ${ARRBIT_TAG} Discovered Lidarr at ${arrUrl} (API key …${arrApiKey: -6})"
}

# -----------------------------------------------------------------------------
# verifyApiAccess: wait until Lidarr API v1 responds
# -----------------------------------------------------------------------------
verifyApiAccess() {
  local apiTest=""
  until [ -n "$apiTest" ]; do
    apiTest=$(curl -s "${arrUrl}/api/v1/system/status?apikey=${arrApiKey}" | jq -r .instanceName 2>/dev/null)
    if [ -n "$apiTest" ]; then
      arrApiVersion="v1"
      log "✅  ${ARRBIT_TAG} Connected to ${apiTest} at ${arrUrl} (API ${arrApiVersion})"
      return 0
    fi
    log "⏳  ${ARRBIT_TAG} Lidarr not ready at ${arrUrl}, retrying..."
    sleep 1
  done
}

# -----------------------------------------------------------------------------
# Initialize on source
# -----------------------------------------------------------------------------
scriptName="${scriptName:-functions}"
scriptVersion="${scriptVersion:-v1.4}"

logfileSetup

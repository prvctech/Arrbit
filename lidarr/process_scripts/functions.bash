#!/usr/bin/env bash
#
# Arrbit Functions
# Shared helper functions for Arrbit scripts
# Version: v1.1
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

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

  # extract <Port> value
  port=$(grep -m1 '<Port>' "$xml" | sed -E 's/.*<Port>([^<]+)<\/Port>.*/\1/')
  # extract <ApiKey> value
  key=$(grep -m1 '<ApiKey>' "$xml" | sed -E 's/.*<ApiKey>([^<]+)<\/ApiKey>.*/\1/')
  # extract <UrlBase> value (may be empty)
  base=$(grep -m1 '<UrlBase>' "$xml" | sed -E 's/.*<UrlBase>([^<]*)<\/UrlBase>.*/\1/')

  # build basePath (leading slash if non-empty)
  if [ -z "$base" ]; then
    basePath=""
  else
    basePath="/${base#/}"
  fi

  arrApiKey="$key"
  arrUrl="http://127.0.0.1:${port}${basePath}"

  log "Discovered Lidarr at ${arrUrl} with API key ending …${arrApiKey: -6}"
}

# -----------------------------------------------------------------------------
# verifyApiAccess: wait until Lidarr API v1 responds
# -----------------------------------------------------------------------------
verifyApiAccess() {
  local apiTest=""
  until [ -n "$apiTest" ]; do
    apiTest=$(curl -s "${arrUrl}/api/v1/system/status?apikey=${arrApiKey}" \
                | jq -r .instanceName 2>/dev/null)
    if [ -n "$apiTest" ]; then
      arrApiVersion="v1"
      log "✅ Connected to ${apiTest} at ${arrUrl} using API ${arrApiVersion}"
      return 0
    fi
    log "⏳ Lidarr not ready at ${arrUrl}, retrying..."
    sleep 1
  done
}

# -----------------------------------------------------------------------------
# ConfValidationCheck: ensure Arrbit config exists and has required flags
# -----------------------------------------------------------------------------
ConfValidationCheck() {
  local cfg="/config/arrbit/config/arrbit.conf"

  if [ ! -f "$cfg" ]; then
    log "ERROR :: \"arrbit.conf\" is missing at /config/arrbit/config/"
    exit 1
  fi
  # example check: INSTALL_AUTOCONFIG must be set
  if [ -z "${INSTALL_AUTOCONFIG:-}" ]; then
    log "ERROR :: \"INSTALL_AUTOCONFIG\" not set in arrbit.conf"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Initialize on source
# -----------------------------------------------------------------------------
scriptName="${scriptName:-functions}"
scriptVersion="${scriptVersion:-v1.1}"

logfileSetup
ConfValidationCheck

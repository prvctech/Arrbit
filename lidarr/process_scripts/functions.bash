#!/usr/bin/env bash
#
# Arrbit Functions
# Shared helper functions for Arrbit scripts
# Version: v1.0
# ---------------------------------------------
# Author: prvctech
# Purpose: Provide common utilities for all Arrbit modules
# ---------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# log: timestamped logging to stdout and Arrbit log file (with emojis!)
# -----------------------------------------------------------------------------
log() {
  local m_time
  m_time=$(date "+%F %T")
  echo "${m_time} :: ${scriptName} :: ${scriptVersion} :: $1"
  echo "${m_time} :: ${scriptName} :: ${scriptVersion} :: $1" \
    >> "/config/logs/${logFileName}"
}

# -----------------------------------------------------------------------------
# logfileSetup: rotate old logs and create a new Arrbit log file
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
# getArrAppInfo: retrieve Lidarr URL, port, base path & API key from XML
# -----------------------------------------------------------------------------
getArrAppInfo() {
  local xml="/config/config.xml"
  local port key base basePath

  if [ ! -f "$xml" ]; then
    log "⚠️ ERROR :: config.xml not found at $xml"
    exit 1
  fi

  port=$(grep -m1 '<Port>' "$xml" | sed -E 's/.*<Port>([^<]+)<\/Port>.*/\1/')
  key=$(grep -m1 '<ApiKey>' "$xml" | sed -E 's/.*<ApiKey>([^<]+)<\/ApiKey>.*/\1/')
  base=$(grep -m1 '<UrlBase>' "$xml" | sed -E 's/.*<UrlBase>([^<]*)<\/UrlBase>.*/\1/')

  if [ -z "$port" ] || [ -z "$key" ]; then
    log "⚠️ ERROR :: Could not retrieve Port or ApiKey from config.xml"
    exit 1
  fi

  if [ -z "$base" ]; then
    basePath=""
  else
    basePath="/${base#/}"
  fi

  arrApiKey="$key"
  arrUrl="http://127.0.0.1:${port}${basePath}"

  log "🔑 Retrieved API key (ending …${arrApiKey: -6}) and Lidarr URL ${arrUrl}"
}

# -----------------------------------------------------------------------------
# verifyApiAccess: wait until Lidarr API v1 is reachable
# -----------------------------------------------------------------------------
verifyApiAccess() {
  local apiTest=""
  until [ -n "$apiTest" ]; do
    apiTest=$(curl -s "${arrUrl}/api/v1/system/status?apikey=${arrApiKey}" \
                | jq -r .instanceName 2>/dev/null)
    if [ -n "$apiTest" ]; then
      arrApiVersion="v1"
      log "✅ Successfully connected to ${apiTest} at ${arrUrl} using API ${arrApiVersion}"
      return 0
    fi
    log "⏳ Waiting for Lidarr to become ready at ${arrUrl}..."
    sleep 1
  done
}

# -----------------------------------------------------------------------------
# ConfValidationCheck: ensure arrbit.conf exists and core flags are set
# -----------------------------------------------------------------------------
ConfValidationCheck() {
  local cfg="/config/arrbit/config/arrbit.conf"

  if [ ! -f "$cfg" ]; then
    log "⚠️ ERROR :: arrbit.conf missing at /config/arrbit/config/"
    exit 1
  fi

  # Example required flag
  if [ -z "${INSTALL_AUTOCONFIG:-}" ]; then
    log "⚠️ ERROR :: INSTALL_AUTOCONFIG not set in arrbit.conf"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Initialize on source
# -----------------------------------------------------------------------------
scriptName="${scriptName:-functions}"
scriptVersion="${scriptVersion:-v1.0}"

logfileSetup
ConfValidationCheck

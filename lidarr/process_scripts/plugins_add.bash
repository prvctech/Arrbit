#!/usr/bin/env bash
#
# Arrbit Module - Install community plugins (Tidal, Deezer, Tubifarry)
# Version: v2.5
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

source /config/arrbit/process_scripts/functions.bash

rawScriptName="$(basename "${BASH_SOURCE[0]}" .bash)"
scriptName="${rawScriptName//_/ } module"
scriptVersion="v2.5"

logfileSetup() {
  timestamp=$(date +"%Y_%m_%d-%H_%M")
  logFileName="arrbit-${rawScriptName}-${timestamp}.log"
  logFilePath="/config/logs/${logFileName}"
  mkdir -p /config/logs
  find "/config/logs" -type f -iname "arrbit-${rawScriptName}-*.log" -mtime +5 -delete
  touch "$logFilePath"
  chmod 666 "$logFilePath"
}

log() {
  echo -e "$1"
  logRaw "$1"
}

logRaw() {
  local stripped
  stripped=$(echo -e "$1" \
    | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' \
    | sed -E 's/\\033\[[0-9;]*m//g' \
    | sed -E 's/[🔵🟢⚠️📥📄⏩🚀✅❌🔧🔴🟪🟦🟩🟥📁📦]//g' \
    | sed -E 's/\\n/\n/g' \
    | sed -E 's/^[[:space:]]+\[Arrbit\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

print_unzip_clean() {
  while IFS= read -r line; do
    if [[ "$line" =~ ^Archive:\ (.*) ]]; then
      echo -e "📦  \033[1;36m[Arrbit]\033[0m Archive:    ${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\ \ inflating:\ (.*) ]]; then
      echo -e "📁  \033[1;36m[Arrbit]\033[0m inflating:  ${BASH_REMATCH[1]}"
    fi
  done
}

logfileSetup
log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

CONFIG_FILE="/config/arrbit/config/arrbit-config.conf"
PLUGINS_DIR="/config/plugins"

if [ ! -r "$CONFIG_FILE" ]; then
  log "⚠️  ${ARRBIT_TAG} Config file not found: $CONFIG_FILE. Skipping plugins."
  exit 0
fi

source "$CONFIG_FILE"

if [ "${ENABLE_COMMUNITY_PLUGINS,,}" != "true" ]; then
  log "⏩  ${ARRBIT_TAG} Community plugin install is disabled. Skipping."
  exit 0
fi

has_dll() {
  shopt -s nullglob
  files=("$1"/*.dll)
  ((${#files[@]} > 0))
}

# ----------------- Deezer -----------------
DEEZER_TARGET="$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer"
if [ "${INSTALL_PLUGIN_DEEZER,,}" = "true" ]; then
  if has_dll "$DEEZER_TARGET"; then
    log "⏩  ${ARRBIT_TAG} Deezer already installed; skipping"
    logRaw "[SKIP] Deezer already exists at $DEEZER_TARGET"
  else
    log "📥  ${ARRBIT_TAG} Installing Deezer plugin..."
    rm -rf /tmp/*
    mkdir -p /tmp/deezer
    curl -sfL -o /tmp/deezer.zip \
      https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip
    unzip -o /tmp/deezer.zip -d /tmp/deezer | print_unzip_clean
    mkdir -p "$DEEZER_TARGET"
    mv /tmp/deezer/* "$DEEZER_TARGET/"
    chmod -R 777 "$DEEZER_TARGET"
    log "✅  ${ARRBIT_TAG} Deezer plugin installed"
    logRaw "[SUCCESS] Deezer installed to $DEEZER_TARGET"
  fi
else
  log "⏩  ${ARRBIT_TAG} Deezer plugin disabled; skipping"
fi

# ----------------- Tidal -----------------
TIDAL_TARGET="$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"
if [ "${INSTALL_PLUGIN_TIDAL,,}" = "true" ]; then
  if has_dll "$TIDAL_TARGET"; then
    log "⏩  ${ARRBIT_TAG} Tidal already installed; skipping"
    logRaw "[SKIP] Tidal already exists at $TIDAL_TARGET"
  else
    log "📥  ${ARRBIT_TAG} Installing Tidal plugin..."
    rm -rf /tmp/*
    mkdir -p /tmp/tidal
    curl -sfL -o /tmp/tidal.zip \
      https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip
    unzip -o /tmp/tidal.zip -d /tmp/tidal | print_unzip_clean
    mkdir -p "$TIDAL_TARGET"
    mv /tmp/tidal/* "$TIDAL_TARGET/"
    chmod -R 777 "$TIDAL_TARGET"
    log "✅  ${ARRBIT_TAG} Tidal plugin installed"
    logRaw "[SUCCESS] Tidal installed to $TIDAL_TARGET"
  fi
else
  log "⏩  ${ARRBIT_TAG} Tidal plugin disabled; skipping"
fi

# ----------------- Tubifarry -----------------
TUBI_TARGET="$PLUGINS_DIR/TypNull/Tubifarry"
if [ "${INSTALL_PLUGIN_TUBIFARRY,,}" = "true" ]; then
  if has_dll "$TUBI_TARGET"; then
    log "⏩  ${ARRBIT_TAG} Tubifarry already installed; skipping"
    logRaw "[SKIP] Tubifarry already exists at $TUBI_TARGET"
  else
    log "📥  ${ARRBIT_TAG} Installing Tubifarry plugin..."
    rm -rf /tmp/*
    mkdir -p /tmp/tubifarry
    curl -sfL -o /tmp/tubifarry.zip \
      https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip
    unzip -o /tmp/tubifarry.zip -d /tmp/tubifarry | print_unzip_clean
    mkdir -p "$TUBI_TARGET"
    mv /tmp/tubifarry/* "$TUBI_TARGET/"
    chmod -R 777 "$TUBI_TARGET"
    log "✅  ${ARRBIT_TAG} Tubifarry plugin installed"
    logRaw "[SUCCESS] Tubifarry installed to $TUBI_TARGET"
  fi
else
  log "⏩  ${ARRBIT_TAG} Tubifarry plugin disabled; skipping"
fi

log "📄  ${ARRBIT_TAG} Log saved to /config/logs/${logFileName}"
log "✅  ${ARRBIT_TAG} Done with ${rawScriptName}.bash!"
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [plugins]
# Version: v2.2
# Purpose: Install community plugins for Lidarr (Tidal, Deezer, Tubifarry)
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
PLUGIN_PURPLE="\033[1;35m"
LOG_DIR="/config/logs"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
PLUGINS_DIR="/config/plugins"
SCRIPT_NAME="plugins"
scriptVersion="v2.2"
logFilePath="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%d-%m-%Y-%H:%M).log"

# ------------------------------------------------------------
# LOGGING FUNCTIONS: emoji/color on STDOUT, plain in log file
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

# ------------------------------------------------------------
# LOG FILE SETUP
# ------------------------------------------------------------
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$logFilePath"
chmod 777 "$logFilePath"

# ------------------------------------------------------------
# SERVICE STARTUP
# ------------------------------------------------------------
log "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}plugins service\033[0m $scriptVersion..."

# ------------------------------------------------------------
# CONFIG FILE CHECK AND LOAD
# ------------------------------------------------------------
if [ ! -r "$CONFIG_FILE" ]; then
  log "⚠️  ${ARRBIT_TAG} Config file not found: $CONFIG_FILE. Skipping plugins."
  exit 0
fi

source "$CONFIG_FILE"

if [ "${ENABLE_PLUGINS,,}" != "true" ]; then
  log "⏩  ${ARRBIT_TAG} Plugin install is disabled. Skipping."
  exit 0
fi

# ------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------
has_dll() {
  shopt -s nullglob
  files=("$1"/*.dll)
  ((${#files[@]} > 0))
}

print_unzip_clean() {
  while IFS= read -r line; do
    if [[ "$line" =~ ^Archive:\ (.*) ]]; then
      echo -e "📦  ${ARRBIT_TAG} Archive:    ${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\ \ inflating:\ (.*) ]]; then
      echo -e "📁  ${ARRBIT_TAG} inflating:  ${BASH_REMATCH[1]}"
    fi
  done
}

# ------------------------------------------------------------
# DEEZER PLUGIN INSTALLATION
# ------------------------------------------------------------
DEEZER_TARGET="$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer"
if [ "${INSTALL_PLUGIN_DEEZER,,}" = "true" ]; then
  if has_dll "$DEEZER_TARGET"; then
    log "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}Deezer\033[0m plugin already installed; skipping"
  else
    log "🌐  ${ARRBIT_TAG} Downloading ${PLUGIN_PURPLE}Deezer\033[0m plugin..."
    rm -rf /tmp/*
    mkdir -p /tmp/deezer
    curl -sfL -o /tmp/deezer.zip \
      https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip
    log "📦  ${ARRBIT_TAG} Deezer archive downloaded."
    unzip -o /tmp/deezer.zip -d /tmp/deezer | print_unzip_clean
    log "📥  ${ARRBIT_TAG} Installing Deezer plugin..."
    mkdir -p "$DEEZER_TARGET"
    mv /tmp/deezer/* "$DEEZER_TARGET/"
    chmod -R 777 "$DEEZER_TARGET"
    log "✅  ${ARRBIT_TAG} Deezer plugin installed"
  fi
else
  log "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}Deezer\033[0m plugin disabled; skipping"
fi

# ------------------------------------------------------------
# TIDAL PLUGIN INSTALLATION
# ------------------------------------------------------------
TIDAL_TARGET="$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"
if [ "${INSTALL_PLUGIN_TIDAL,,}" = "true" ]; then
  if has_dll "$TIDAL_TARGET"; then
    log "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}Tidal\033[0m plugin already installed; skipping"
  else
    log "🌐  ${ARRBIT_TAG} Downloading ${PLUGIN_PURPLE}Tidal\033[0m plugin..."
    rm -rf /tmp/*
    mkdir -p /tmp/tidal
    curl -sfL -o /tmp/tidal.zip \
      https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip
    log "📦  ${ARRBIT_TAG} Tidal archive downloaded."
    unzip -o /tmp/tidal.zip -d /tmp/tidal | print_unzip_clean
    log "📥  ${ARRBIT_TAG} Installing Tidal plugin..."
    mkdir -p "$TIDAL_TARGET"
    mv /tmp/tidal/* "$TIDAL_TARGET/"
    chmod -R 777 "$TIDAL_TARGET"
    log "✅  ${ARRBIT_TAG} Tidal plugin installed"
  fi
else
  log "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}Tidal\033[0m plugin disabled; skipping"
fi

# ------------------------------------------------------------
# TUBIFARRY PLUGIN INSTALLATION
# ------------------------------------------------------------
TUBI_TARGET="$PLUGINS_DIR/TypNull/Tubifarry"
if [ "${INSTALL_PLUGIN_TUBIFARRY,,}" = "true" ]; then
  if has_dll "$TUBI_TARGET"; then
    log "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}Tubifarry\033[0m plugin already installed; skipping"
  else
    log "🌐  ${ARRBIT_TAG} Downloading ${PLUGIN_PURPLE}Tubifarry\033[0m plugin..."
    rm -rf /tmp/*
    mkdir -p /tmp/tubifarry
    curl -sfL -o /tmp/tubifarry.zip \
      https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip
    log "📦  ${ARRBIT_TAG} Tubifarry archive downloaded."
    unzip -o /tmp/tubifarry.zip -d /tmp/tubifarry | print_unzip_clean
    log "📥  ${ARRBIT_TAG} Installing Tubifarry plugin..."
    mkdir -p "$TUBI_TARGET"
    mv /tmp/tubifarry/* "$TUBI_TARGET/"
    chmod -R 777 "$TUBI_TARGET"
    log "✅  ${ARRBIT_TAG} Tubifarry plugin installed"
  fi
else
  log "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}Tubifarry\033[0m plugin disabled; skipping"
fi

# ------------------------------------------------------------
# SERVICE END LOGS
# ------------------------------------------------------------
log "📄  ${ARRBIT_TAG} Log saved to $logFilePath"
log "✅  ${ARRBIT_TAG} Done with plugins service!"

exit 0

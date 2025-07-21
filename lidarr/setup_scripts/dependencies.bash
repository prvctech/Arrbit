#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [dependencies]
# Version: v1.1
# Purpose: Installs all required dependencies for Arrbit scripts and services.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
SCRIPT_NAME="dependencies"
scriptVersion="v1.1"
logFilePath="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%d-%m-%Y-%H:%M).log"

# ------------------------------------------------------------
# LOGGING FUNCTIONS: emoji/color on stdout, plain in log
# ------------------------------------------------------------
logRaw() {
  local msg="$1"
  # Remove all Arrbit emojis first
  msg=$(echo -e "$msg" | tr -d "🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴💾")
  # Remove ANSI color codes
  msg=$(echo -e "$msg" | sed -E "s/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g")
  # Normalize Arrbit tag at start of line
  msg=$(echo -e "$msg" | sed -E "s/^[[:space:]]+\[Arrbit\]/[Arrbit]/")
  echo "$msg" >> "$logFilePath"
}

log() {
  local msg="$1"
  echo -e "$msg"
  logRaw "$msg"
}

# ------------------------------------------------------------
# LOG FILE SETUP
# ------------------------------------------------------------
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$logFilePath"
chmod 777 "$logFilePath"

log "🚀  $ARRBIT_TAG Starting ${MODULE_YELLOW}dependencies script\033[0m $scriptVersion..."

# ------------------------------------------------------------
# DETECT PACKAGE MANAGER AND DEFINE COMMANDS
# ------------------------------------------------------------
if command -v apk &>/dev/null; then
    PKG_INSTALL="apk add --no-cache"
    UPDATE_CMD="apk update"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 py3-pip git py3-requests"
elif command -v apt-get &>/dev/null; then
    PKG_INSTALL="apt-get install -y"
    UPDATE_CMD="apt-get update"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 python3-pip git python3-requests"
elif command -v yum &>/dev/null; then
    PKG_INSTALL="yum install -y"
    UPDATE_CMD="yum makecache"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 python3-pip git python3-requests"
else
    log "⚠️  $ARRBIT_TAG Unknown package manager! Exiting."
    exit 1
fi

# ------------------------------------------------------------
# UPDATE SOURCES & INSTALL PACKAGES
# ------------------------------------------------------------
log "🔄  $ARRBIT_TAG Updating package sources..."
$UPDATE_CMD >> "$logFilePath" 2>&1

log "🔧  $ARRBIT_TAG Installing base dependencies: $PKGS"
$PKG_INSTALL $PKGS >> "$logFilePath" 2>&1

# ------------------------------------------------------------
# VERIFY PYTHON REQUESTS (AND FIX IF NEEDED)
# ------------------------------------------------------------
if ! python3 -c "import requests" &>/dev/null; then
    if command -v apk &>/dev/null; then
        log "⚠️  $ARRBIT_TAG requests not found after APK install! Please check your Alpine packages."
        exit 1
    else
        log "🔧  $ARRBIT_TAG Installing python3-requests via pip..."
        pip3 install --no-cache-dir requests >> "$logFilePath" 2>&1
    fi
fi

chmod -R 777 "$LOG_DIR" 2>/dev/null || true

log "✅  $ARRBIT_TAG Dependencies install complete!"
log "📄  $ARRBIT_TAG Log saved to $logFilePath"

exit 0

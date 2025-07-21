#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [dependencies]
# Version: v1.2
# Purpose: Installs all required dependencies for Arrbit scripts and services, only if missing, and applies updates.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
LOG_DIR="/config/logs"
SCRIPT_NAME="dependencies"
scriptVersion="v1.2"
logFilePath="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%d-%m-%Y-%H:%M).log"

logRaw() {
  local msg="$1"
  msg=$(echo -e "$msg" | tr -d "🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴💾")
  msg=$(echo -e "$msg" | sed -E "s/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g")
  msg=$(echo -e "$msg" | sed -E "s/^[[:space:]]+\[Arrbit\]/[Arrbit]/")
  echo "$msg" >> "$logFilePath"
}

log() {
  local msg="$1"
  echo -e "$msg"
  logRaw "$msg"
}

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$logFilePath"
chmod 777 "$logFilePath"

log "🚀  $ARRBIT_TAG Starting ${MODULE_YELLOW}dependencies script\033[0m $scriptVersion..."

# ------------------------------------------------------------
# DETECT PACKAGE MANAGER AND DEFINE COMMANDS
# ------------------------------------------------------------
if command -v apk &>/dev/null; then
    PM="apk"
    UPDATE_CMD="apk update"
    UPGRADE_CMD="apk upgrade"
    PKG_INSTALL="apk add --no-cache"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 py3-pip git py3-requests"
elif command -v apt-get &>/dev/null; then
    PM="apt"
    UPDATE_CMD="apt-get update"
    UPGRADE_CMD="apt-get upgrade -y"
    PKG_INSTALL="apt-get install -y"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 python3-pip git python3-requests"
elif command -v yum &>/dev/null; then
    PM="yum"
    UPDATE_CMD="yum makecache"
    UPGRADE_CMD="yum update -y"
    PKG_INSTALL="yum install -y"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 python3-pip git python3-requests"
else
    log "⚠️  $ARRBIT_TAG Unknown package manager! Exiting."
    exit 1
fi

log "🔄  $ARRBIT_TAG Updating package sources..."
$UPDATE_CMD >> "$logFilePath" 2>&1

# ------------------------------------------------------------
# CHECK AND INSTALL INDIVIDUAL PACKAGES IF MISSING
# ------------------------------------------------------------
MISSING_PKGS=""
for pkg in $PKGS; do
  case $PM in
    apk)
      if ! apk info -e "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
      fi
      ;;
    apt)
      if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
      fi
      ;;
    yum)
      if ! rpm -q "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
      fi
      ;;
  esac
done

if [ -n "$MISSING_PKGS" ]; then
  log "🔧  $ARRBIT_TAG Installing missing dependencies:$MISSING_PKGS"
  $PKG_INSTALL $MISSING_PKGS >> "$logFilePath" 2>&1
else
  log "⏩  $ARRBIT_TAG All base dependencies already installed. Skipping install."
fi

# ------------------------------------------------------------
# UPGRADE/UPDATE INSTALLED PACKAGES
# ------------------------------------------------------------
log "🔄  $ARRBIT_TAG Upgrading installed packages (if any updates available)..."
$UPGRADE_CMD >> "$logFilePath" 2>&1

# ------------------------------------------------------------
# VERIFY PYTHON REQUESTS (AND FIX IF NEEDED)
# ------------------------------------------------------------
if ! python3 -c "import requests" &>/dev/null; then
    if [ "$PM" = "apk" ]; then
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

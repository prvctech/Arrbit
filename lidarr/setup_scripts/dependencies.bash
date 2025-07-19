#!/usr/bin/env bash
# ------------------------------------------------------------
# Arrbit [dependencies]
# Version: 1.1-gs1
# Purpose: Installs all required dependencies for Arrbit modules.
# ------------------------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
LOG_DIR="/config/logs"
logFilePath="$LOG_DIR/arrbit-dependencies-$(date +%Y%m%d-%H%M%S).log"

.logRaw() {
  local stripped
  stripped=$(echo -e "$1" | sed -E $'s/(\\x1B|\\033)\\[[0-9;]*[a-zA-Z]//g; s/[🔵🟢⚠️📥📄⏩🚀✅❌🔧🔴🟪🟦🟩🟥📁📦]//g; s/\\\\n/\\\n/g; s/^[[:space:]]+\\[Arrbit\\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

log() {
  local msg="$1"
  echo -e "$msg"
  .logRaw "$msg"
}

log "🔵  $ARRBIT_TAG Starting dependencies..."

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

log "📦  $ARRBIT_TAG Updating package sources..."
$UPDATE_CMD >> "$logFilePath" 2>&1

log "📦  $ARRBIT_TAG Installing base dependencies: $PKGS"
$PKG_INSTALL $PKGS >> "$logFilePath" 2>&1

if ! python3 -c "import requests" &>/dev/null; then
    if command -v apk &>/dev/null; then
        log "⚠️  $ARRBIT_TAG requests not found after APK install! Please check your Alpine packages."
        exit 1
    else
        log "📦  $ARRBIT_TAG Installing python3-requests via pip..."
        pip3 install --no-cache-dir requests >> "$logFilePath" 2>&1
    fi
fi

chmod -R 777 "$LOG_DIR" 2>/dev/null || true

log "✅  $ARRBIT_TAG dependencies complete!"
log "[Arrbit] Log saved to $logFilePath"
exit 0

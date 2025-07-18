#!/usr/bin/env bash
set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
LOG_DIR="/config/logs"
RAW_LOG="$LOG_DIR/arrbit-dependencies-$(date +%Y%m%d-%H%M%S).log"

log() { echo -e "$1" | tee -a "$RAW_LOG"; }

log "🔵  $ARRBIT_TAG Starting dependencies.bash..."

# --- Detect OS package manager ---
if command -v apk &>/dev/null; then
    PKG_INSTALL="apk add --no-cache"
    UPDATE_CMD="apk update"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 py3-pip git"
elif command -v apt-get &>/dev/null; then
    PKG_INSTALL="apt-get install -y"
    UPDATE_CMD="apt-get update"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 python3-pip git"
elif command -v yum &>/dev/null; then
    PKG_INSTALL="yum install -y"
    UPDATE_CMD="yum makecache"
    PKGS="curl bash coreutils jq unzip ffmpeg sox opus-tools python3 python3-pip git"
else
    log "⚠️   $ARRBIT_TAG Unknown package manager! Exiting."
    exit 1
fi

log "📦  $ARRBIT_TAG Updating package sources..."
$UPDATE_CMD >>"$RAW_LOG" 2>&1

log "📦  $ARRBIT_TAG Installing base dependencies: $PKGS"
$PKG_INSTALL $PKGS >>"$RAW_LOG" 2>&1

# --- Ensure python 'requests' (for API scripts) ---
if ! python3 -c "import requests" &>/dev/null; then
    log "📦  $ARRBIT_TAG Installing python3-requests..."
    pip3 install --no-cache-dir requests >>"$RAW_LOG" 2>&1
fi

# --- Permissions ---
chmod -R 777 "$LOG_DIR" 2>/dev/null || true

log "✅  $ARRBIT_TAG dependencies.bash complete!"
exit 0

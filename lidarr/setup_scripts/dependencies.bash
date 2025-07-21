#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit dependencies.bash
# Version: v2.0
# Purpose: Installs all required dependencies for Arrbit scripts and services, only if missing, and applies updates.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v2.0"
LOG_DIR="/config/logs"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  $ARRBIT_TAG Starting ${MODULE_YELLOW}${SCRIPT_NAME} script\033[0m ${SCRIPT_VERSION}..."

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
    arrbitErrorLog "⚠️" \
      "[Arrbit] Unknown package manager! Exiting." \
      "Unknown package manager" \
      "dependencies.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "No supported package manager (apk/apt/yum) found" \
      "Install one of apk, apt-get, or yum and rerun this script"
    sleep infinity
fi

arrbitLog "🔄  $ARRBIT_TAG Updating package sources..."
$UPDATE_CMD >> "$log_file_path" 2>&1

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
  arrbitLog "🔧  $ARRBIT_TAG Installing missing dependencies:$MISSING_PKGS"
  $PKG_INSTALL $MISSING_PKGS >> "$log_file_path" 2>&1
else
  arrbitLog "⏩  $ARRBIT_TAG All base dependencies already installed. Skipping install."
fi

# ------------------------------------------------------------
# UPGRADE/UPDATE INSTALLED PACKAGES
# ------------------------------------------------------------
arrbitLog "🔄  $ARRBIT_TAG Upgrading installed packages (if any updates available)..."
$UPGRADE_CMD >> "$log_file_path" 2>&1

# ------------------------------------------------------------
# VERIFY PYTHON REQUESTS (AND FIX IF NEEDED)
# ------------------------------------------------------------
if ! python3 -c "import requests" &>/dev/null; then
    if [ "$PM" = "apk" ]; then
        arrbitErrorLog "⚠️" \
          "[Arrbit] requests not found after APK install! Please check your Alpine packages." \
          "python3-requests not found" \
          "python3-requests, dependencies.bash" \
          "${SCRIPT_NAME}:${LINENO}" \
          "python3-requests package missing after install" \
          "Check APK packages or try installing via pip"
        sleep infinity
    else
        arrbitLog "🔧  $ARRBIT_TAG Installing python3-requests via pip..."
        pip3 install --no-cache-dir requests >> "$log_file_path" 2>&1
    fi
fi

chmod -R 777 "$LOG_DIR" 2>/dev/null || true

arrbitLog "✅  $ARRBIT_TAG Dependencies install complete!"
arrbitLog "📄  $ARRBIT_TAG Log saved to $log_file_path"

exit 0

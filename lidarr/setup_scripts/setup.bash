#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup.bash
# Version: v1.4-gs2.7.1
# Purpose: Bootstrap Arrbit: ensure config, folders, helpers, modules present (silent except fatal error).
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_ROOT="/config/arrbit"
TMP_DIR="/config/arrbit/tmp"
ZIP_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
ZIP_NAME="arrbit.zip"
EXTRACTED="Arrbit-main"

# --- Ensure Arrbit root and tmp dir exist ---
mkdir -p "$ARRBIT_ROOT" "$ARRBIT_ROOT/tmp"
chmod 777 "$ARRBIT_ROOT/tmp"
mkdir -p "$TMP_DIR"

cd "$TMP_DIR"

# --- Download and extract repo (fatal error = only echo allowed) ---
if ! curl -fsSL "$ZIP_URL" -o "$ZIP_NAME"; then
    echo "[Arrbit] ERROR: Failed to download repository. Check network and URL."
    exit 1
fi

unzip -qqo "$ZIP_NAME"
rm -f "$ZIP_NAME"

# --- Copy core folders to /config/arrbit if not present ---
for d in config connectors custom helpers modules services setup; do
  if [[ ! -d "$ARRBIT_ROOT/$d" ]]; then
    cp -rf "$EXTRACTED/$d" "$ARRBIT_ROOT/"
  fi
done

# --- Write default config if missing ---
DEFAULT_CONFIG="$EXTRACTED/config/arrbit-config.conf"
TARGET_CONFIG="$ARRBIT_ROOT/config/arrbit-config.conf"
if [[ ! -f "$TARGET_CONFIG" && -f "$DEFAULT_CONFIG" ]]; then
  cp -f "$DEFAULT_CONFIG" "$TARGET_CONFIG"
fi

# --- Clean up temp dir ---
rm -rf "$TMP_DIR/$EXTRACTED"

# --- Now helpers should exist: switch to GS logging for the rest ---
if [[ -f "$ARRBIT_ROOT/helpers/logging_utils.bash" && -f "$ARRBIT_ROOT/helpers/helpers.bash" ]]; then
  source "$ARRBIT_ROOT/helpers/logging_utils.bash"
  source "$ARRBIT_ROOT/helpers/helpers.bash"
  arrbitPurgeOldLogs
  SCRIPT_NAME="setup"
  SCRIPT_VERSION="v1.4-gs2.7.1"
  LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
  touch "$LOG_FILE" && chmod 777 "$LOG_FILE"
fi

exit 0

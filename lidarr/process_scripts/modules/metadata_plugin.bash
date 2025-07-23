#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_plugin.bash
# Version: v2.3
# Purpose: Configure Lyrics Enhancer metadata provider only (Golden Standard, Tubifarry block removed).
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="metadata_plugin"
SCRIPT_VERSION="v2.3"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

log_info "${ARRBIT_TAG} Starting ${MODULE_YELLOW}metadata_plugin module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (sets arr_api, arrUrl, arrApiVersion)
# ------------------------------------------------------------------------
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "${ARRBIT_TAG} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Only Lyrics Enhancer (id=11)
# ------------------------------------------------------------------------
log_info "[Arrbit] Configuring Lyrics Enhancer consumer..."
lid=11
le=$(arr_api "${arrUrl}/api/${arrApiVersion}/metadata/${lid}")
upd=$(echo "$le" | jq '
  .enable = true
  | (.fields[] |=
      if .name=="createLrcFiles" then .value=true
      elif .name=="lrcLibEnabled" then .value=true
      elif .name=="lrcLibInstanceUrl" then .value="https://lrclib.net"
      else . end
    )
')
if arr_api -X PUT --data-raw "$upd" "${arrUrl}/api/${arrApiVersion}/metadata/${lid}" >/dev/null; then
  log_info "[Arrbit] Lyrics Enhancer configured"
else
  log_error "[Arrbit] Failed to configure Lyrics Enhancer"
fi

log_info "[Arrbit] Done with metadata_plugin module!"
exit 0

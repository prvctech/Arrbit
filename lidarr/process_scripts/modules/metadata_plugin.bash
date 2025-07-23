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

CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# Banner (yellow for module name, first log only)
log_info "${YELLOW}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (sets arr_api, arrUrl, arrApiVersion)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

# Only Lyrics Enhancer (id=11)
log_info "Configuring Lyrics Enhancer consumer..."
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
  log_info "Lyrics Enhancer configured"
else
  log_error "Failed to configure Lyrics Enhancer"
fi

log_info "Done with ${SCRIPT_NAME} module!"
exit 0

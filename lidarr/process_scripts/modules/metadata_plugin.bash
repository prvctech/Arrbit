#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_plugin.bash
# Version: v2.0-gs2.7.1
# Purpose: Configure Lyrics Enhancer metadata provider only (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Source logging and helpers (Golden Standard order)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/config_utils.bash

arrbitPurgeOldLogs
n# Check if YAML configuration exists
if ! config_exists; then
  log_error &quot;Configuration file missing: arrbit-config.yaml (see log at /config/logs)&quot;
  cat <<EOF | arrbitLogClean >> &quot;$LOG_FILE&quot;
[Arrbit] ERROR Configuration file missing
[WHY]: arrbit-config.yaml not found in /config/arrbit/config/
[FIX]: Create a configuration file based on the example in the repository
EOF
  exit 1
fi

# Get module configuration from YAML
MODULE_ENABLED=$(get_yaml_value &quot;autoconfig.modules.metadata_plugin&quot;)

# Validate if validator is available
if type validate_boolean >/dev/null 2>&1; then
  if ! validate_boolean &quot;autoconfig.modules.metadata_plugin&quot; &quot;$MODULE_ENABLED&quot;; then
    MODULE_ENABLED=&quot;false&quot;
  fi
fi

if [[ &quot;${MODULE_ENABLED,,}&quot; != &quot;true&quot; ]]; then
  log_warning &quot;metadata_plugin module is disabled in configuration. Exiting.&quot;
  exit 0
fi

SCRIPT_NAME="metadata_plugin"
SCRIPT_VERSION="v2.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

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

# Log the payload being sent (sanitized)
log_info "Payload for Lyrics Enhancer written to log file (sanitized)"
printf '[Arrbit] Lyrics Enhancer update payload:\n%s\n' "$upd" | arrbitLogClean >> "$LOG_FILE"

if arr_api -X PUT --data-raw "$upd" "${arrUrl}/api/${arrApiVersion}/metadata/${lid}" >/dev/null; then
  log_info "Lyrics Enhancer configured"
else
  log_error "Failed to configure Lyrics Enhancer"
fi

#log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

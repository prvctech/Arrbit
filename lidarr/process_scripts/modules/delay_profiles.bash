#!/usr/bin/env bash

# -------------------------------------------------------------------------------------------------------------
# Arrbit - Delay Profiles Module
# Version: v1.7-gs2.6
# Author: prvctech
# Purpose: Configures Lidarr delay profiles by importing correct payloads based on plugin flags. Removes "id".
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="delay_profiles"
SCRIPT_VERSION="v1.7-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/connectors/arr_bridge.bash

echo -e "${GREEN}[Arrbit] Delay Profiles Module v1.7-gs2.6${NC}"

PAYLOAD_DIR="/config/arrbit/modules/data"

PLUGINS_ENABLED=$(getFlag "ENABLE_PLUGINS")
DEEZER_ENABLED=$(getFlag "INSTALL_PLUGIN_DEEZER")
TIDAL_ENABLED=$(getFlag "INSTALL_PLUGIN_TIDAL")
TUBIFARRY_ENABLED=$(getFlag "INSTALL_PLUGIN_TUBIFARRY")

payload_file=""

if [[ "${PLUGINS_ENABLED}" == "false" ]]; then
    payload_file="${PAYLOAD_DIR}/payload-delay_profile_all_plugins_off.json"
    log_info "Plugins disabled. Importing: $(basename "$payload_file")"
else
    if [[ "${TIDAL_ENABLED}" == "false" && "${DEEZER_ENABLED}" == "false" ]]; then
        payload_file="${PAYLOAD_DIR}/payload-delay_profile_tidal_deezer_off.json"
        log_info "Both Tidal and Deezer OFF. Importing: $(basename "$payload_file")"
    elif [[ "${TIDAL_ENABLED}" == "false" && "${TUBIFARRY_ENABLED}" == "false" ]]; then
        payload_file="${PAYLOAD_DIR}/payload-delay_profile_tidal_tubi_off.json"
        log_info "Tidal and Tubifarry OFF. Importing: $(basename "$payload_file")"
    elif [[ "${DEEZER_ENABLED}" == "false" ]]; then
        payload_file="${PAYLOAD_DIR}/payload-delay_profile_deezer_off.json"
        log_info "Deezer OFF. Importing: $(basename "$payload_file")"
    elif [[ "${TIDAL_ENABLED}" == "false" ]]; then
        payload_file="${PAYLOAD_DIR}/payload-delay_profile_tidal_off.json"
        log_info "Tidal OFF. Importing: $(basename "$payload_file")"
    elif [[ "${TUBIFARRY_ENABLED}" == "false" ]]; then
        payload_file="${PAYLOAD_DIR}/payload-delay_profile_tubi_off.json"
        log_info "Tubifarry OFF. Importing: $(basename "$payload_file")"
    else
        payload_file="${PAYLOAD_DIR}/payload-delay_profile_all_plugins_on.json"
        log_info "All major plugins enabled. Importing: $(basename "$payload_file")"
    fi
fi

if [[ ! -f "$payload_file" ]]; then
    log_error "Payload file not found: $payload_file"
    log_info "Log file saved to: $LOG_FILE"
    exit 1
fi

# --- Remove all "id" fields from the payload before sending to Lidarr ---
DELAY_JSON=$(cat "$payload_file" | jq 'del(.id) | if type=="array" then map(del(.id)) else . end')
if [[ -z "$DELAY_JSON" ]]; then
    log_error "Failed to sanitize JSON payload (empty or invalid)."
    log_info "Log file saved to: $LOG_FILE"
    exit 1
fi

log_info "Loaded and sanitized payload from: $payload_file"

log_info "Applying Delay Profile via arr_api..."
response=$(arr_api -X PUT --data-raw "${DELAY_JSON}" "${arrUrl}/api/${arrApiVersion}/delayProfile?apikey=${arrApiKey}")
api_status=$?

if [[ $api_status -eq 0 ]]; then
    log_info "Delay Profile applied successfully."
else
    log_error "Failed to apply Delay Profile."
fi

log_info "Log file saved to: $LOG_FILE"
exit 0

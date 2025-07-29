#!/usr/bin/env bash

# -------------------------------------------------------------------------------------------------------------
# Arrbit - Delay Profiles Module
# Version: v1.2-gs2.6
# Author: prvctech
# Purpose: Configure Lidarr delay profiles based on plugin flags (Golden Standard v2.6)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="delay_profiles"
SCRIPT_VERSION="v1.2-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/connectors/arr_bridge.bash

# Module banner (GREEN)
echo -e "${GREEN}[Arrbit] Delay Profiles Module v1.2-gs2.6${NC}"

# Get flags from config using helper (removes whitespace, is robust)
DEEZER_ENABLED=$(getFlag "INSTALL_PLUGIN_DEEZER")
TIDAL_ENABLED=$(getFlag "INSTALL_PLUGIN_TIDAL")
TUBIFARRY_ENABLED=$(getFlag "INSTALL_PLUGIN_TUBIFARRY")

profile_type="default"
DELAY_JSON='{}'  # fallback/empty payload

# Decision tree
if [[ "$DEEZER_ENABLED" == "true" && "$TIDAL_ENABLED" == "true" && "$TUBIFARRY_ENABLED" == "true" ]]; then
    profile_type="tidal_deezer_tubifarry_soulseek_usenet_torrent"
    DELAY_JSON='{ "profile": "Tidal, Deezer, Tubifarry (YouTube), Soulseek, Usenet, Torrent" }'
elif [[ "$DEEZER_ENABLED" == "true" && "$TIDAL_ENABLED" == "false" && "$TUBIFARRY_ENABLED" == "true" ]]; then
    profile_type="deezer_tubifarry_soulseek_usenet_torrent"
    DELAY_JSON='{ "profile": "Deezer, Tubifarry (YouTube), Soulseek, Usenet, Torrent" }'
elif [[ "$DEEZER_ENABLED" == "false" && "$TIDAL_ENABLED" == "false" && "$TUBIFARRY_ENABLED" == "true" ]]; then
    profile_type="tubifarry_soulseek_usenet_torrent"
    DELAY_JSON='{ "profile": "Tubifarry (YouTube), Soulseek, Usenet, Torrent" }'
elif [[ "$DEEZER_ENABLED" == "false" && "$TIDAL_ENABLED" == "false" && "$TUBIFARRY_ENABLED" == "false" ]]; then
    profile_type="usenet_torrent"
    DELAY_JSON='{ "profile": "Usenet, Torrent" }'
else
    log_warning "No matching delay profile conditions found for config: Deezer=$DEEZER_ENABLED, Tidal=$TIDAL_ENABLED, Tubifarry=$TUBIFARRY_ENABLED. Skipping."
    log_info "Log file saved to: $LOG_FILE"
    exit 0
fi

log_info "Selected Delay Profile: $profile_type"
log_info "Applying Delay Profile..."

response=$(arr_api -X PUT --data-raw "${DELAY_JSON}" "${arrUrl}/api/${arrApiVersion}/delayProfile?apikey=${arrApiKey}")
api_status=$?

if [[ $api_status -eq 0 ]]; then
    log_info "Delay Profile applied successfully."
else
    log_error "Failed to apply Delay Profile."
fi

log_info "Log file saved to: $LOG_FILE"
exit 0

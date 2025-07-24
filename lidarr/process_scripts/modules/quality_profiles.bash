#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - quality_profiles.bash
# Version: v1.6-gs2.6
# Purpose: Configure Lidarr quality profiles via API (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Source logging and helpers (Golden Standard order)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.6-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner: [Arrbit] always CYAN, module name/version GREEN (first line only)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

# Connect to arr_bridge.bash (waits for API, sets arr_api)
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup)"
  exit 1
fi

log_info "Configuring Quality Profile..."

# 1) Delete default profiles if JSON exists
remove_file="/config/arrbit/modules/json_values/quality_profiles-default_values-remove.json"
if [[ -f "$remove_file" ]] && default_profiles_json=$(jq -c . "$remove_file" 2>/dev/null); then
  for name in $(jq -r '.[].name' <<<"$default_profiles_json"); do
    ids_json=$(arr_api "${arrUrl}/api/${arrApiVersion}/qualityprofile")
    id=$(jq -r ".[] | select(.name==\"$name\") | .id" <<<"$ids_json")
    if [[ -n "$id" && "$id" != "null" ]]; then
      log_info "Deleting default profile '$name' (ID: $id)..."
      if arr_api -X DELETE "${arrUrl}/api/${arrApiVersion}/qualityprofile/$id"; then
        log_info "Deleted profile '$name'"
      else
        log_error "Failed deleting profile '$name'"
      fi
    fi
  done
else
  log_info "Could not parse default-values JSON; skipping deletion"
fi

# 2) Build JSON for HQ profile
hq_profile=$(cat <<'EOF'
{
  "name": "hq",
  "upgradeAllowed": false,
  "cutoff": 21,
  "items": [
    {"quality": {"id": 4, "name": "MP3-320"}, "items": [], "allowed": true},
    {"quality": {"id": 6, "name": "FLAC"}, "items": [], "allowed": true},
    {"quality": {"id": 21, "name": "FLAC 24bit"}, "items": [], "allowed": true}
  ],
  "minFormatScore": 0,
  "cutoffFormatScore": 0,
  "formatItems": [
    {"format": 24, "name": "WEB", "score": 1},
    {"format": 23, "name": "VIP Edition", "score": -5},
    {"format": 22, "name": "Single", "score": 1},
    {"format": 21, "name": "Remix", "score": -5},
    {"format": 20, "name": "Remastered", "score": 2},
    {"format": 19, "name": "Original", "score": 2},
    {"format": 18, "name": "LQ Releases", "score": -10},
    {"format": 17, "name": "Lossless", "score": 5},
    {"format": 16, "name": "Live", "score": -10},
    {"format": 15, "name": "Limited Edition", "score": 1},
    {"format": 14, "name": "Instrumental", "score": -10},
    {"format": 13, "name": "HQ Releases - Tier 2", "score": 9},
    {"format": 12, "name": "HQ Releases - Tier 1", "score": 10},
    {"format": 11, "name": "Explicit", "score": 1},
    {"format": 10, "name": "Expanded Edition", "score": -10},
    {"format": 9, "name": "EP", "score": 0},
    {"format": 8, "name": "Drumless", "score": -10},
    {"format": 7, "name": "Demo", "score": -10},
    {"format": 6, "name": "Deluxe Edition", "score": 2},
    {"format": 5, "name": "Compilation", "score": -2},
    {"format": 4, "name": "CD", "score": 3},
    {"format": 3, "name": "Anniversary Edition", "score": 1},
    {"format": 2, "name": "Acapella", "score": -10},
    {"format": 1, "name": "24bit", "score": 6}
  ],
  "id": 4
}
EOF
)

# 3) Update profile via API
log_info "Updating HQ quality profile (payload logged to file)"
printf '[Arrbit] HQ Profile payload:\n%s\n' "$hq_profile" | arrbitLogClean >> "$LOG_FILE"

if arr_api -X PUT --data "$hq_profile" \
     "${arrUrl}/api/${arrApiVersion}/qualityprofile/4" >/dev/null; then
  log_info "Quality profile 'hq' updated."
else
  log_error "Failed to update quality profile 'hq' (Check API connectivity and payload)"
fi

log_info "Done with ${SCRIPT_NAME} module!"
log_info "Log saved to $LOG_FILE"
exit 0

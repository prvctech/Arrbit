#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit quality_profiles.bash
# Version: v1.3
# Purpose: Configure Lidarr quality profiles via API. Golden Standard.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="quality_profiles"
SCRIPT_VERSION="v1.3"
LOG_DIR="/config/logs"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
CYAN="\033[1;36m"
RESET="\033[0m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}quality_profiles module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API)
# ------------------------------------------------------------------------
if ! source /etc/services.d/arrbit/connectors/arr_bridge.bash; then
  arrbitErrorLog "❌  " \
    "${CYAN}[Arrbit]${RESET} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Check CONFIGURE_QUALITY_PROFILE (always use flag helpers)
# ------------------------------------------------------------------------
CFG_FLAG=$(getFlag "CONFIGURE_QUALITY_PROFILE")
: "${CFG_FLAG:=true}"

if [[ "${CFG_FLAG,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} Skipping Quality Profile module (flag disabled)"
  exit 0
fi

arrbitLog "⚙️  ${ARRBIT_TAG} Configuring Quality Profile..."

# 1) Delete default profiles
remove_file="/etc/services.d/arrbit/modules/json_values/quality_profiles-default_values-remove.json"
if [[ -f "$remove_file" ]] && default_profiles_json=$(jq -c . "$remove_file" 2>/dev/null); then
  for name in $(jq -r '.[].name' <<<"$default_profiles_json"); do
    ids_json=$(curl -s -H "X-Api-Key: ${arrApiKey}" "${arrUrl}/api/${arrApiVersion}/qualityprofile")
    id=$(jq -r ".[] | select(.name==\"$name\") | .id" <<<"$ids_json")
    if [[ -n "$id" && "$id" != "null" ]]; then
      arrbitLog "⚙️  ${ARRBIT_TAG} Deleting default profile '$name' (ID: $id)..."
      if curl -s --fail -X DELETE "${arrUrl}/api/${arrApiVersion}/qualityprofile/$id" -H "X-Api-Key: ${arrApiKey}"; then
        arrbitLog "✅  ${ARRBIT_TAG} Deleted profile '$name'"
      else
        arrbitLog "⚠️  ${ARRBIT_TAG} Failed deleting profile '$name'"
      fi
    fi
  done
else
  arrbitLog "⚠️  ${ARRBIT_TAG} Could not parse default-values JSON; skipping deletion"
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
if curl -s --fail --retry 3 --retry-delay 2 \
     -H "X-Api-Key: ${arrApiKey}" \
     -H "Content-Type: application/json" \
     -X PUT \
     --data "${hq_profile}" \
     "${arrUrl}/api/${arrApiVersion}/qualityprofile/4" >/dev/null; then
  arrbitLog "✅  ${ARRBIT_TAG} Quality profile 'hq' updated."
else
  arrbitErrorLog "⚠️  " \
    "${CYAN}[Arrbit]${RESET} Failed to update quality profile 'hq'" \
    "quality profile PUT failed" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Quality profile update failed" \
    "Check API connectivity and payload"
fi

arrbitLog "✅  ${ARRBIT_TAG} Done with quality_profiles module!"
exit 0

#!/usr/bin/env bash
#
# Module: Quality Profile
# Version: v1.2
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Shared helpers (sets up logging, $arrUrl, $arrApiKey, etc.)
source /config/arrbit/process_scripts/functions.bash

# Discover & wait for Lidarr API
getArrAppInfo
verifyApiAccess

# Check toggle
if [ "${CONFIGURE_QUALITY_PROFILE,,}" != "true" ]; then
  log "⏭️   [Arrbit] Skipping Quality Profile"
  exit 0
fi

log "⚙️   [Arrbit] Configuring Quality Profile..."

# 1) Delete default profiles
remove_file="/config/arrbit/process_scripts/modules/json_values/quality_profiles-default_values-remove.json"
if [[ -f "$remove_file" ]] && default_profiles_json=$(jq -c . "$remove_file" 2>/dev/null); then
  for name in $(jq -r '.[].name' <<<"$default_profiles_json"); do
    id=$(jq -r ".[] | select(.name==\"$name\") | .id" <<<"$(curl -s -H \"X-Api-Key: ${arrApiKey}\" "${arrUrl}/api/${arrApiVersion}/qualityprofile")")
    if [[ -n "$id" && "$id" != "null" ]]; then
      log "⚙️   [Arrbit] Deleting default profile '$name' (ID: $id)..."
      curl -s --fail -X DELETE "${arrUrl}/api/${arrApiVersion}/qualityprofile/$id" -H "X-Api-Key: ${arrApiKey}" \
        && log "✅  [Arrbit] Deleted profile '$name'" \
        || log "⚠️   [Arrbit] Failed deleting profile '$name'"
    fi
  done
else
  log "⚠️   [Arrbit] Could not parse default-values JSON; skipping deletion"
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
     "${arrUrl}/api/${arrApiVersion}/qualityprofile/4"; then
  log "✅  [Arrbit] Quality profile 'hq' updated."
else
  log "⚠️   [Arrbit] Failed to update quality profile 'hq'"
fi

log "✅  [Arrbit] Quality Profile configuration done!"
exit 0

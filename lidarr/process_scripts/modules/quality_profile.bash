#!/usr/bin/env bash
#
# Module: Quality Profile
# Version: v0.1
# Author: prvctech
# ---------------------------------------------

# Identify this script for shared logging
scriptName="quality_profile"
scriptVersion="v0.1"

set -euo pipefail

# Bring in shared helpers (sets up logging, loads config flags)
source /config/arrbit/process_scripts/functions.bash

# Discover Lidarr endpoint and API key
getArrAppInfo
# Wait for API readiness and set arrApiVersion
verifyApiAccess

# Prepare HTTP headers for API calls
HEADER=( "-H" "X-Api-Key: ${arrApiKey}" "-H" "Content-Type: application/json" )

# Configure Quality Profile if enabled
if [ "${CONFIGURE_QUALITY_PROFILE,,}" = "true" ]; then
  log "⚙️   [Arrbit] Configuring Quality Profile..."

  # Build JSON for HQ profile
  quality_profile_json=$(cat <<EOF
{
  "name": "hq",
  "upgradeAllowed": false,
  "cutoff": 21,
  "items": [
    {"quality": {"id": 4, "name": "MP3-320"},     "items": [], "allowed": true},
    {"quality": {"id": 6, "name": "FLAC"},        "items": [], "allowed": true},
    {"quality": {"id": 21, "name": "FLAC 24bit"}, "items": [], "allowed": true}
  ],
  "minFormatScore": 0,
  "cutoffFormatScore": 0,
  "formatItems": [
    {"format": 24, "name": "WEB",                  "score": 1},
    {"format": 23, "name": "VIP Edition",         "score": -5},
    {"format": 22, "name": "Single",              "score": 1},
    {"format": 21, "name": "Remix",               "score": -5},
    {"format": 20, "name": "Remastered",          "score": 2},
    {"format": 19, "name": "Original",            "score": 2},
    {"format": 18, "name": "LQ Releases",         "score": -10},
    {"format": 17, "name": "Lossless",            "score": 5},
    {"format": 16, "name": "Live",                "score": -10},
    {"format": 15, "name": "Limited Edition",     "score": 1},
    {"format": 14, "name": "Instrumental",        "score": -10},
    {"format": 13, "name": "HQ Releases - Tier 2", "score": 9},
    {"format": 12, "name": "HQ Releases - Tier 1", "score": 10},
    {"format": 11, "name": "Explicit",            "score": 1},
    {"format": 10, "name": "Expanded Edition",    "score": -10},
    {"format": 9,  "name": "EP",                  "score": 0},
    {"format": 8,  "name": "Drumless",            "score": -10},
    {"format": 7,  "name": "Demo",                "score": -10},
    {"format": 6,  "name": "Deluxe Edition",      "score": 2},
    {"format": 5,  "name": "Compilation",         "score": -2},
    {"format": 4,  "name": "CD",                  "score": 3},
    {"format": 3,  "name": "Anniversary Edition",  "score": 1},
    {"format": 2,  "name": "Acapella",            "score": -10},
    {"format": 1,  "name": "24bit",               "score": 6}
  ],
  "id": 4
}
EOF
  )

  # Send API request
  if curl -s --fail --retry 3 --retry-delay 2 \
       "${arrUrl}/api/${arrApiVersion}/qualityprofile/4" \
       -X PUT "${HEADER[@]}" \
       --data-raw "$quality_profile_json"; then
    log "✅  [Arrbit] Quality Profile configured successfully"
  else
    log "⚠️   [Arrbit] Quality Profile API call failed"
  fi
else
  log "⏭️   [Arrbit] Skipping Quality Profile"
fi

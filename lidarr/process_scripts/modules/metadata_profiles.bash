#!/usr/bin/env bash
set -euo pipefail

echo "*** [Arrbit] Configuring metadata profiles ***"

# Load functions
source /config/arrbit/process_scripts/functions.bash

# Check toggle
if [[ "${CONFIGURE_METADATA_PROFILES}" != "true" ]]; then
  echo "*** [Arrbit] CONFIGURE_METADATA_PROFILES disabled. Skipping. ***"
  exit 0
fi

# Function to update a profile
update_profile() {
  local id=$1
  local data=$2

  curl -sfL \
    -H "X-Api-Key: $(api_key)" \
    -H "Content-Type: application/json" \
    -X PUT \
    --data "${data}" \
    "$(api_url)/api/v1/metadataprofile/${id}" \
    && echo "✅ Profile ID ${id} updated." \
    || echo "⚠ Failed to update profile ID ${id}."
}

# ------------------------
# Profile: standard
# ------------------------
standard_profile=$(cat <<EOF
{
  "name": "standard",
  "id": 1,
  "primaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Album"}, "allowed": true},
    {"albumType": {"id": 1, "name": "EP"}, "allowed": true},
    {"albumType": {"id": 2, "name": "Single"}, "allowed": true},
    {"albumType": {"id": 3, "name": "Broadcast"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Other"}, "allowed": false}
  ],
  "secondaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Studio"}, "allowed": true},
    {"albumType": {"id": 1, "name": "Compilation"}, "allowed": false},
    {"albumType": {"id": 2, "name": "Soundtrack"}, "allowed": false},
    {"albumType": {"id": 3, "name": "Spokenword"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Interview"}, "allowed": false},
    {"albumType": {"id": 6, "name": "Live"}, "allowed": false},
    {"albumType": {"id": 7, "name": "Remix"}, "allowed": false},
    {"albumType": {"id": 8, "name": "DJ-mix"}, "allowed": false},
    {"albumType": {"id": 9, "name": "Mixtape/Street"}, "allowed": false},
    {"albumType": {"id": 10, "name": "Demo"}, "allowed": false},
    {"albumType": {"id": 11, "name": "Audio drama"}, "allowed": false}
  ],
  "releaseStatuses": [
    {"releaseStatus": {"id": 0, "name": "Official"}, "allowed": true},
    {"releaseStatus": {"id": 1, "name": "Promotion"}, "allowed": false},
    {"releaseStatus": {"id": 2, "name": "Bootleg"}, "allowed": false},
    {"releaseStatus": {"id": 3, "name": "Pseudo-Release"}, "allowed": false}
  ]
}
EOF
)
update_profile 1 "$standard_profile"

# ------------------------
# Profile: None
# ------------------------
none_profile=$(cat <<EOF
{
  "name": "None",
  "id": 2,
  "primaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Album"}, "allowed": false},
    {"albumType": {"id": 1, "name": "EP"}, "allowed": false},
    {"albumType": {"id": 2, "name": "Single"}, "allowed": false},
    {"albumType": {"id": 3, "name": "Broadcast"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Other"}, "allowed": false}
  ],
  "secondaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Studio"}, "allowed": false},
    {"albumType": {"id": 1, "name": "Compilation"}, "allowed": false},
    {"albumType": {"id": 2, "name": "Soundtrack"}, "allowed": false},
    {"albumType": {"id": 3, "name": "Spokenword"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Interview"}, "allowed": false},
    {"albumType": {"id": 6, "name": "Live"}, "allowed": false},
    {"albumType": {"id": 7, "name": "Remix"}, "allowed": false},
    {"albumType": {"id": 8, "name": "DJ-mix"}, "allowed": false},
    {"albumType": {"id": 9, "name": "Mixtape/Street"}, "allowed": false},
    {"albumType": {"id": 10, "name": "Demo"}, "allowed": false},
    {"albumType": {"id": 11, "name": "Audio drama"}, "allowed": false}
  ],
  "releaseStatuses": [
    {"releaseStatus": {"id": 0, "name": "Official"}, "allowed": false},
    {"releaseStatus": {"id": 1, "name": "Promotion"}, "allowed": false},
    {"releaseStatus": {"id": 2, "name": "Bootleg"}, "allowed": false},
    {"releaseStatus": {"id": 3, "name": "Pseudo-Release"}, "allowed": false}
  ]
}
EOF
)
update_profile 2 "$none_profile"

# ------------------------
# Profile: edm
# ------------------------
edm_profile=$(cat <<EOF
{
  "name": "edm",
  "id": 3,
  "primaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Album"}, "allowed": true},
    {"albumType": {"id": 1, "name": "EP"}, "allowed": true},
    {"albumType": {"id": 2, "name": "Single"}, "allowed": true},
    {"albumType": {"id": 3, "name": "Broadcast"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Other"}, "allowed": false}
  ],
  "secondaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Studio"}, "allowed": true},
    {"albumType": {"id": 1, "name": "Compilation"}, "allowed": true},
    {"albumType": {"id": 2, "name": "Soundtrack"}, "allowed": true},
    {"albumType": {"id": 3, "name": "Spokenword"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Interview"}, "allowed": false},
    {"albumType": {"id": 6, "name": "Live"}, "allowed": false},
    {"albumType": {"id": 7, "name": "Remix"}, "allowed": true},
    {"albumType": {"id": 8, "name": "DJ-mix"}, "allowed": false},
    {"albumType": {"id": 9, "name": "Mixtape/Street"}, "allowed": false},
    {"albumType": {"id": 10, "name": "Demo"}, "allowed": false},
    {"albumType": {"id": 11, "name": "Audio drama"}, "allowed": false}
  ],
  "releaseStatuses": [
    {"releaseStatus": {"id": 0, "name": "Official"}, "allowed": true},
    {"releaseStatus": {"id": 1, "name": "Promotion"}, "allowed": false},
    {"releaseStatus": {"id": 2, "name": "Bootleg"}, "allowed": false},
    {"releaseStatus": {"id": 3, "name": "Pseudo-Release"}, "allowed": false}
  ]
}
EOF
)
update_profile 3 "$edm_profile"

# ------------------------
# Profile: latino
# ------------------------
latino_profile=$(cat <<EOF
{
  "name": "latino",
  "id": 4,
  "primaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Album"}, "allowed": true},
    {"albumType": {"id": 1, "name": "EP"}, "allowed": false},
    {"albumType": {"id": 2, "name": "Single"}, "allowed": true},
    {"albumType": {"id": 3, "name": "Broadcast"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Other"}, "allowed": false}
  ],
  "secondaryAlbumTypes": [
    {"albumType": {"id": 0, "name": "Studio"}, "allowed": false},
    {"albumType": {"id": 1, "name": "Compilation"}, "allowed": true},
    {"albumType": {"id": 2, "name": "Soundtrack"}, "allowed": false},
    {"albumType": {"id": 3, "name": "Spokenword"}, "allowed": false},
    {"albumType": {"id": 4, "name": "Interview"}, "allowed": false},
    {"albumType": {"id": 6, "name": "Live"}, "allowed": false},
    {"albumType": {"id": 7, "name": "Remix"}, "allowed": true},
    {"albumType": {"id": 8, "name": "DJ-mix"}, "allowed": false},
    {"albumType": {"id": 9, "name": "Mixtape/Street"}, "allowed": false},
    {"albumType": {"id": 10, "name": "Demo"}, "allowed": false},
    {"albumType": {"id": 11, "name": "Audio drama"}, "allowed": false}
  ],
  "releaseStatuses": [
    {"releaseStatus": {"id": 0, "name": "Official"}, "allowed": true},
    {"releaseStatus": {"id": 1, "name": "Promotion"}, "allowed": false},
    {"releaseStatus": {"id": 2, "name": "Bootleg"}, "allowed": false},
    {"releaseStatus": {"id": 3, "name": "Pseudo-Release"}, "allowed": false}
  ]
}
EOF
)
update_profile 4 "$latino_profile"

echo "*** [Arrbit] Metadata profiles updated successfully! ***"
exit 0

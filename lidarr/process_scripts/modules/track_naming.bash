#!/usr/bin/env bash
#
# Module: Track Naming
# Version: v0.3
# Author: prvctech
# ---------------------------------------------

# Identify this script for shared logging
scriptName="track_naming"
scriptVersion="v0.3"

set -euo pipefail

# Bring in shared helpers (sets up logging, loads config flags)
source /config/arrbit/process_scripts/functions.bash

# Discover Lidarr endpoint and API key
getArrAppInfo
# Wait for API readiness and set arrApiVersion
verifyApiAccess

# Prepare HTTP headers for API calls
HEADER=( "-H" "X-Api-Key: ${arrApiKey}" "-H" "Content-Type: application/json" )

# Configure Track Naming if enabled
if [ "${CONFIGURE_TRACK_NAMING,,}" = "true" ]; then
  log "⚙️   [Arrbit] Configuring Track Naming..."
  if curl -s --fail --retry 3 --retry-delay 2 \
       "${arrUrl}/api/${arrApiVersion}/config/naming" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "renameTracks": true,
  "replaceIllegalCharacters": true,
  "standardTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
  "multiDiscTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
  "artistFolderFormat": "{Artist CleanName}{ (Artist Disambiguation)}",
  "includeArtistName": false,
  "includeAlbumTitle": false,
  "includeQuality": false,
  "replaceSpaces": false,
  "id": 1
}'; then
    log "✅  [Arrbit] Track Naming configured successfully"
  else
    log "⚠️   [Arrbit] Track Naming API call failed"
  fi
else
  log "⏭️   [Arrbit] Skipping Track Naming"
fi

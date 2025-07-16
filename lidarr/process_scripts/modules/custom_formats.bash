#!/usr/bin/env bash
#
# Arrbit Module - Register tagger.bash as Lidarr custom script
# Version: v1.2
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source functions
source /config/arrbit/process_scripts/functions.bash

scriptName="custom_scripts"
scriptVersion="v1.2"

# Setup logging
logfileSetup
log "🚀  ${ARRBIT_TAG} Starting custom_scripts.bash..."

# Connect to Lidarr
getArrAppInfo
verifyApiAccess

# Check if tagger.bash is already registered as "arrbit-tagger"
if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
  | jq -e '.[] | select(.name=="arrbit-tagger")' >/dev/null; then

  log "🔧  ${ARRBIT_TAG} Registering arrbit-tagger (tagger.bash)..."

  curl -s -X POST "${arrUrl}/api/${arrApiVersion}/notification?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw '{
      "name": "arrbit-tagger",
      "implementation": "CustomScript",
      "configContract": "CustomScriptSettings",
      "onReleaseImport": true,
      "onUpgrade": true,
      "fields": [
        { "name": "path", "value": "/config/arrbit/process_scripts/tagger.bash" }
      ]
    }' \
    && log "✅  ${ARRBIT_TAG} Registered arrbit-tagger script" \
    || log "❌  ${ARRBIT_TAG} Failed to register arrbit-tagger script"

else
  log "⏭️  ${ARRBIT_TAG} arrbit-tagger already registered; skipping"
fi

log "✅  ${ARRBIT_TAG} Done with custom_scripts.bash!"
exit 0

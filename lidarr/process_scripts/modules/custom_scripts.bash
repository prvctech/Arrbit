#!/usr/bin/env bash
#
# Arrbit Custom Scripts Module
# Runs user-defined scripts on Lidarr events (e.g., tagging)
# Version: v1.0
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Source shared functions
source /config/arrbit/process_scripts/functions.bash

scriptName="custom_scripts"
scriptVersion="v1.0"

# Setup logging
logfileSetup

log "🚀  ${ARRBIT_TAG} Starting custom scripts module..."

# Get API info & verify connection
getArrAppInfo
verifyApiAccess

# Determine event type from Lidarr
EVENT="${EVENTTYPE:-unknown}"

log "🔔  ${ARRBIT_TAG} Triggered by event: ${EVENT}"

case "$EVENT" in
  "On Release Import"|"On Upgrade")
    log "🏷️  ${ARRBIT_TAG} Running tagger.bash..."
    if bash /config/arrbit/process_scripts/tagger.bash; then
      log "✅  ${ARRBIT_TAG} tagger.bash completed successfully"
      exit 0
    else
      log "❌  ${ARRBIT_TAG} tagger.bash failed"
      exit 1
    fi
    ;;
  *)
    log "⏭️   ${ARRBIT_TAG} No action for event type: ${EVENT}"
    exit 0
    ;;
esac

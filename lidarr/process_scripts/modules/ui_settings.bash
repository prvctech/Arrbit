#!/usr/bin/env bash
#
# Module: UI Settings
# Version: v0.1.5
# Author: prvctech
# ---------------------------------------------

# Identify this script for shared logging
scriptName="ui_settings"
scriptVersion="v0.1.5"

set -euo pipefail

# Load shared functions (sets up logging, loads config flags)
source /config/arrbit/process_scripts/functions.bash

# Discover Lidarr endpoint and API key
getArrAppInfo

# Wait for API readiness and set arrApiVersion
verifyApiAccess

# Prepare HTTP headers for API calls
HEADER=( "-H" "X-Api-Key: ${arrApiKey}" "-H" "Content-Type: application/json" )

# Configure UI settings if enabled
if [ "${CONFIGURE_UI_SETTINGS,,}" = "true" ]; then
  log "⚙️   [Arrbit] Configuring UI Settings..."
  if curl -s --fail --retry 3 --retry-delay 2 \
       "${arrUrl}/api/${arrApiVersion}/config/ui" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "firstDayOfWeek": 0,
  "calendarWeekColumnHeader": "ddd M/D",
  "shortDateFormat": "MMM D YYYY",
  "longDateFormat": "dddd, MMMM D YYYY",
  "timeFormat": "h(:mm)a",
  "showRelativeDates": true,
  "enableColorImpairedMode": true,
  "uiLanguage": 1,
  "expandAlbumByDefault": true,
  "expandSingleByDefault": true,
  "expandEPByDefault": true,
  "expandBroadcastByDefault": true,
  "expandOtherByDefault": true,
  "theme": "auto",
  "id": 1
}' ; then
    log "✅  [Arrbit] UI Settings configured successfully"
  else
    log "⚠️   [Arrbit] UI Settings API call failed"
  fi
else
  log "⏭️   [Arrbit] Skipping UI Settings"
fi

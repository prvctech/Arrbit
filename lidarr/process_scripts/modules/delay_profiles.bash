#!/usr/bin/env bash
#
# Arrbit Delay Profiles module
# Version: v1.1
# Author: prvctech
# Purpose: Configure Lidarr delay profiles based on plugin flags
# ---------------------------------------------

set -euo pipefail

# Colored Arrbit tag for better terminal visibility
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# Source shared functions and user config
source /config/arrbit/process_scripts/functions.bash
source /config/arrbit/config/arrbit.conf

# Retrieve Lidarr info
getArrAppInfo
verifyApiAccess

echo -e "🚀  ${ARRBIT_TAG} Running Delay Profiles module"

# Master switch & module flag checks
if [ "${ENABLE_AUTOCONFIG:-false}" != "true" ]; then
  echo -e "⏭️  ${ARRBIT_TAG} Auto-configuration disabled. Skipping Delay Profiles."
  exit 0
fi
if [ "${CONFIGURE_DELAY_PROFILES:-false}" != "true" ]; then
  echo -e "⏭️  ${ARRBIT_TAG} CONFIGURE_DELAY_PROFILES is false. Skipping."
  exit 0
fi

# Assemble JSON payload based on plugin flags
if [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ] && \
   [ "${INSTALL_PLUGIN_TIDAL:-false}"   = "true" ] && \
   [ "${INSTALL_PLUGIN_DEEZER:-false}"  = "true" ] && \
   [ "${INSTALL_PLUGIN_TUBIFARRY:-false}" = "true" ]; then
  echo -e "🛎️  ${ARRBIT_TAG} Using Delay Profile: Tidal, Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='…full-payload…'
elif [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ] && \
     [ "${INSTALL_PLUGIN_TIDAL:-false}" = "false" ] && \
     [ "${INSTALL_PLUGIN_DEEZER:-false}" = "true" ]; then
  echo -e "🛎️  ${ARRBIT_TAG} Using Delay Profile: Deezer, Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='…full-payload…'
elif [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ] && \
     [ "${INSTALL_PLUGIN_TIDAL:-false}" = "false" ] && \
     [ "${INSTALL_PLUGIN_DEEZER:-false}" = "false" ]; then
  echo -e "🛎️  ${ARRBIT_TAG} Using Delay Profile: Soulseek, Usenet, Torrent, Youtube"
  DELAY_JSON='…full-payload…'
elif [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "false" ]; then
  echo -e "🛎️  ${ARRBIT_TAG} Using Delay Profile: Usenet, Torrent only"
  DELAY_JSON='…full-payload…'
else
  echo -e "⚠️  ${ARRBIT_TAG} No matching delay profile conditions found. Skipping."
  exit 0
fi

# Apply the selected delay profile
echo -e "⚙️  ${ARRBIT_TAG} Applying Delay Profile..."
if curl -sfX PUT \
      -H "X-Api-Key: ${arrApiKey}" \
      -H "Content-Type: application/json" \
      --data-raw "${DELAY_JSON}" \
      "${arrUrl}/api/v1/delayProfile"; then
  echo -e "✅  ${ARRBIT_TAG} Delay Profile module completed!"
else
  echo -e "⚠️  ${ARRBIT_TAG} Failed to apply Delay Profile."
fi

exit 0

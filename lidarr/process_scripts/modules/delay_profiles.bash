#!/usr/bin/env bash
set -euo pipefail

echo "*** [Arrbit] Running Delay Profiles module... ***"

# Source functions and config
source /config/arrbit/process_scripts/functions.bash
source /config/arrbit/config/arrbit.conf

# Get Lidarr URL and API key from functions
LIDARR_URL=$(get_lidarr_url)
API_KEY=$(get_lidarr_api_key)

# Check if AutoConfig master switch is on and metadata profiles is enabled
if [[ "${INSTALL_AUTOCONFIG}" != "true" ]]; then
  echo "*** [Arrbit] AutoConfig master switch is off. Skipping delay profiles. ***"
  exit 0
fi

if [[ "${CONFIGURE_DELAY_PROFILES}" != "true" ]]; then
  echo "*** [Arrbit] CONFIGURE_DELAY_PROFILES is false. Skipping. ***"
  exit 0
fi

# Decide which JSON payload to use
if [[ "${INSTALL_COMMUNITY_PLUGINS}" == "true" && "${INSTALL_PLUGIN_TIDAL}" == "true" && "${INSTALL_PLUGIN_DEEZER}" == "true" && "${INSTALL_PLUGIN_TUBIFARRY}" == "true" ]]; then
  echo "*** [Arrbit] Using Delay Profile with Tidal, Deezer, Soulseek, Usenet, Torrent, Youtube. ***"
  DELAY_JSON='[{"name":"main","items":[{"name":"Tidal","protocol":"TidalDownloadProtocol","allowed":true,"delay":0},{"name":"Deezer","protocol":"DeezerDownloadProtocol","allowed":true,"delay":0},{"name":"Soulseek","protocol":"SoulseekDownloadProtocol","allowed":true,"delay":30},{"name":"Usenet","protocol":"UsenetDownloadProtocol","allowed":true,"delay":120},{"name":"Torrent","protocol":"TorrentDownloadProtocol","allowed":true,"delay":180},{"name":"Youtube","protocol":"YoutubeDownloadProtocol","allowed":true,"delay":720}],"bypassIfHighestQuality":true,"bypassIfAboveCustomFormatScore":false,"minimumCustomFormatScore":0,"order":2147483647,"tags":[],"id":1}]'
elif [[ "${INSTALL_COMMUNITY_PLUGINS}" == "true" && "${INSTALL_PLUGIN_TIDAL}" == "false" && "${INSTALL_PLUGIN_DEEZER}" == "true" ]]; then
  echo "*** [Arrbit] Using Delay Profile without Tidal. ***"
  DELAY_JSON='[{"name":"main","items":[{"name":"Deezer","protocol":"DeezerDownloadProtocol","allowed":true,"delay":0},{"name":"Soulseek","protocol":"SoulseekDownloadProtocol","allowed":true,"delay":30},{"name":"Usenet","protocol":"UsenetDownloadProtocol","allowed":true,"delay":120},{"name":"Torrent","protocol":"TorrentDownloadProtocol","allowed":true,"delay":180},{"name":"Youtube","protocol":"YoutubeDownloadProtocol","allowed":true,"delay":720}],"bypassIfHighestQuality":true,"bypassIfAboveCustomFormatScore":false,"minimumCustomFormatScore":0,"order":2147483647,"tags":[],"id":1}]'
elif [[ "${INSTALL_COMMUNITY_PLUGINS}" == "true" && "${INSTALL_PLUGIN_TIDAL}" == "false" && "${INSTALL_PLUGIN_DEEZER}" == "false" ]]; then
  echo "*** [Arrbit] Using Delay Profile with only Soulseek, Usenet, Torrent, Youtube. ***"
  DELAY_JSON='[{"name":"main","items":[{"name":"Soulseek","protocol":"SoulseekDownloadProtocol","allowed":true,"delay":0},{"name":"Usenet","protocol":"UsenetDownloadProtocol","allowed":true,"delay":60},{"name":"Torrent","protocol":"TorrentDownloadProtocol","allowed":true,"delay":120},{"name":"Youtube","protocol":"YoutubeDownloadProtocol","allowed":true,"delay":720}],"bypassIfHighestQuality":true,"bypassIfAboveCustomFormatScore":false,"minimumCustomFormatScore":0,"order":2147483647,"tags":[],"id":1}]'
elif [[ "${INSTALL_COMMUNITY_PLUGINS}" == "false" ]]; then
  echo "*** [Arrbit] Using Delay Profile with only Usenet and Torrent. ***"
  DELAY_JSON='[{"name":"main","items":[{"name":"Usenet","protocol":"UsenetDownloadProtocol","allowed":true,"delay":0},{"name":"Torrent","protocol":"TorrentDownloadProtocol","allowed":true,"delay":0}],"bypassIfHighestQuality":true,"bypassIfAboveCustomFormatScore":false,"minimumCustomFormatScore":0,"order":2147483647,"tags":[],"id":1}]'
else
  echo "⚠️ [Arrbit] No matching delay profile conditions found. Skipping."
  exit 0
fi

# Send PUT request to update Delay Profile
echo "*** [Arrbit] Applying Delay Profile... ***"
curl -sfX PUT \
  -H "X-Api-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  --data-raw "${DELAY_JSON}" \
  "${LIDARR_URL}/api/v1/delayProfile"

echo "*** [Arrbit] Delay Profile module completed! ***"
exit 0

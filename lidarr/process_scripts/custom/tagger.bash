#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [tagger]
# Version: 1.1
# Purpose: Tag imported music files using Beets and ensure correct artist/album metadata
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

scriptVersion="1.1"
scriptName="tagger module"
rawScriptName="tagger"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
logFilePath="/config/logs/arrbit-${rawScriptName}-$(date '+%d-%m-%Y-%H%M').log"

source /config/arrbit.conf

lidarr_album_id="$1"
beets_config="/config/arrbit/beets-config.yaml"
SECONDS=0

# ------------------------------------------------------------
# 1. LOGGING SETUP
# ------------------------------------------------------------
log() {
  echo -e "$1"
  logRaw "$1"
}

logRaw() {
  local stripped
  stripped=$(echo -e "$1" | sed -E $'s/(\\x1B|\\033)\\[[0-9;]*[a-zA-Z]//g; s/[🔵🟢⚠️🌐📥📋🛠️📄⏩⏭🚀✅❌🔧🔴🟪🟦🟩🟥📁📦]//g; s/\\\\n/\\\n/g; s/^[[:space:]]+\\[Arrbit\\]/[Arrbit]/')
  echo "$stripped" >> "$logFilePath"
}

log "🚀  ${ARRBIT_TAG} Starting \033[1;33m${scriptName}\033[0m ${scriptVersion}..."

# ------------------------------------------------------------
# 2. SAFETY CHECKS
# ------------------------------------------------------------
if [ "$lidarr_eventtype" == "Test" ]; then
  log "🔵  ${ARRBIT_TAG} Test event received. Script tested successfully."
  exit 0
fi

if [ -z "$lidarr_album_id" ]; then
  log "❌  ${ARRBIT_TAG} No album ID received! Exiting."
  exit 1
fi

# ------------------------------------------------------------
# 3. RESOLVE IMPORT FOLDER
# ------------------------------------------------------------
getTrackPath="$(curl -s "$arrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"
log "📁  ${ARRBIT_TAG} Resolved import path: $getFolderPath"

# ------------------------------------------------------------
# 4. BEETS TAGGING
# ------------------------------------------------------------
export XDG_CONFIG_HOME=/config/arrbit
log "🛠️  ${ARRBIT_TAG} Starting Beets import..."
beet -c "$beets_config" import -qC "$getFolderPath"
if [ $? -ne 0 ]; then
  log "❌  ${ARRBIT_TAG} Beets import failed! Exiting."
  exit 1
fi
log "✅  ${ARRBIT_TAG} Beets tagging completed."

# ------------------------------------------------------------
# 5. TAG CLEANUP FUNCTIONS
# ------------------------------------------------------------
fetch_artist_data() {
  getAlbumArtist="$(curl -s "$arrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .artist.artistName)"
  getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$1" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"
}

# ------------------------------------------------------------
# 6. CLEAN FLAC FILES
# ------------------------------------------------------------
find "$getFolderPath" -type f -iname "*.flac" | while read -r file; do
  log "📋  ${ARRBIT_TAG} Cleaning FLAC file: $file"
  fetch_artist_data "$file"

  metaflac --remove-tag=ARTIST "$file"
  metaflac --remove-tag=ALBUMARTIST "$file"
  metaflac --set-tag=ALBUMARTIST="$getAlbumArtist" "$file"

  if [ -n "$getArtistCredit" ]; then
    metaflac --set-tag=ARTIST="$getArtistCredit" "$file"
  else
    metaflac --set-tag=ARTIST="$getAlbumArtist" "$file"
  fi
done

# ------------------------------------------------------------
# 7. CLEAN MP3 FILES
# ------------------------------------------------------------
find "$getFolderPath" -type f -iname "*.mp3" | while read -r file; do
  log "📋  ${ARRBIT_TAG} Cleaning MP3 file: $file"
  fetch_artist_data "$file"

  id3v2 --delete-all "$file"
  id3v2 --TPE2 "$getAlbumArtist" "$file"
  if [ -n "$getArtistCredit" ]; then
    id3v2 --artist "$getArtistCredit" "$file"
  else
    id3v2 --artist "$getAlbumArtist" "$file"
  fi
done

# ------------------------------------------------------------
# 8. WRAP UP
# ------------------------------------------------------------
log "✅  ${ARRBIT_TAG} Final tag cleanup completed."

duration=$SECONDS
log "✅  ${ARRBIT_TAG} ${scriptName} finished in $(($duration / 60))m $(($duration % 60))s"
exit 0

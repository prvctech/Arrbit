#!/usr/bin/env bash
scriptVersion="1.0"
scriptName="ArrbitTagger"

source /config/arrbit.conf

lidarr_album_id="$1"
if [ -z "$lidarr_album_id" ]; then
    lidarr_album_id="$1"
fi

logFile="/logs/lidarr/arrbit_tagger.log"
beets_config="/config/arrbit/beets-config.yaml"

SECONDS=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$logFile"
}

if [ "$lidarr_eventtype" == "Test" ]; then
    log "Test event received. Script tested successfully."
    exit 0
fi

if [ -z "$lidarr_album_id" ]; then
    log "No album ID received! Exiting."
    exit 1
fi

getTrackPath="$(curl -s "$arrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"

log "Resolved import path: $getFolderPath"

export XDG_CONFIG_HOME=/config/arrbit
log "Starting Beets import..."
beet -c "$beets_config" import -qC "$getFolderPath"
if [ $? -ne 0 ]; then
    log "Beets import failed! Exiting."
    exit 1
fi
log "Beets tagging completed."

log "Starting final tag cleanup..."

find "$getFolderPath" -type f -iname "*.flac" | while read -r file; do
    log "Cleaning FLAC file: $file"

    getAlbumArtist="$(curl -s "$arrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .artist.artistName)"
    getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"

    metaflac --remove-tag=ARTIST "$file"
    metaflac --remove-tag=ALBUMARTIST "$file"
    metaflac --set-tag=ALBUMARTIST="$getAlbumArtist" "$file"

    if [ ! -z "$getArtistCredit" ]; then
        metaflac --set-tag=ARTIST="$getArtistCredit" "$file"
    else
        metaflac --set-tag=ARTIST="$getAlbumArtist" "$file"
    fi
done

find "$getFolderPath" -type f -iname "*.mp3" | while read -r file; do
    log "Cleaning MP3 file: $file"

    getAlbumArtist="$(curl -s "$arrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .artist.artistName)"
    getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"

    id3v2 --delete-all "$file"
    id3v2 --TPE2 "$getAlbumArtist" "$file"
    if [ ! -z "$getArtistCredit" ]; then
        id3v2 --artist "$getArtistCredit" "$file"
    else
        id3v2 --artist "$getAlbumArtist" "$file"
    fi
done

log "Final tag cleanup completed."

duration=$SECONDS
log "ArrbitTagger finished in $(($duration / 60)) minutes and $(($duration % 60)) seconds."
exit 0

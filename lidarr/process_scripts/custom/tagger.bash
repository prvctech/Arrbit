#!/usr/bin/env bash

# -------------------------------------------------------------------------------------------------------------
# Arrbit - beets_tagger.bash
# Version: v1.0-gs2.6
# Purpose: GS2.6-compliant Lidarr event script to tag music files using beets and metaflac.
# -------------------------------------------------------------------------------------------------------------

# ----- Golden Standard Boilerplate -----
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

# ----- Module Details -----
SCRIPT_NAME="beets_tagger"
SCRIPT_VERSION="v1.0-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# ----- Banner (first line only) -----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}"

# ----- Source Arr Bridge (API/exports) -----
source /config/arrbit/connectors/arr_bridge.bash

# ----- Validate argument (album ID) -----
if [[ -z "$1" ]]; then
    log_error "No album ID supplied as argument. Exiting."
    log_info "Log saved to $LOG_FILE"
    exit 1
fi
lidarr_album_id="$1"

# ----- Fetch album/artist info via API -----
log_info "Fetching album and artist info from Lidarr API..."
album_response="$(arr_api -X GET "${arrUrl}/api/${arrApiVersion}/album/${lidarr_album_id}")"
if [[ -z "$album_response" || "$album_response" == "null" ]]; then
    log_error "Failed to retrieve album details from Lidarr for album ID: $lidarr_album_id"
    log_info "Log saved to $LOG_FILE"
    exit 2
fi

artist_name="$(echo "$album_response" | jq -r '.artist.artistName // empty')"
artist_path="$(echo "$album_response" | jq -r '.artist.path // empty')"

if [[ -z "$artist_name" || -z "$artist_path" ]]; then
    log_error "Missing artist name or path from API response."
    log_info "Log saved to $LOG_FILE"
    exit 3
fi

# ----- Fetch first track file to locate album folder -----
log_info "Locating album folder from track files..."
track_response="$(arr_api -X GET "${arrUrl}/api/${arrApiVersion}/trackFile?albumId=${lidarr_album_id}")"
track_path="$(echo "$track_response" | jq -r '.[0].path // empty')"
if [[ -z "$track_path" ]]; then
    log_error "No track files found for album. Aborting."
    log_info "Log saved to $LOG_FILE"
    exit 4
fi
album_folder="$(dirname "$track_path")"
album_folder_name="$(basename "$album_folder")"

log_info "Processing album: '$album_folder_name' (artist: '$artist_name') in folder: $album_folder"

# ----- Verify album folder exists -----
if [[ ! -d "$album_folder" ]]; then
    log_error "Album folder '$album_folder' does not exist. Exiting."
    log_info "Log saved to $LOG_FILE"
    exit 5
fi

# ----- Check for FLAC files -----
if ! find "$album_folder" -type f -iname "*.flac" | grep -q .; then
    log_error "No FLAC files found in album folder. Only FLAC is supported."
    log_info "Log saved to $LOG_FILE"
    exit 6
fi

# ----- Begin Beets tagging process -----
SECONDS=0
log_info "Running beets import for folder: $album_folder"

beets_config="/config/arrbit/config/beets-config.yaml"
library_tmp="/tmp/beets-lidarr.blb"
beets_log="/config/logs/beets-lidarr.log"

# Clean up any old temp files
rm -f "$library_tmp" "$beets_log"

beet -c "$beets_config" -l "$library_tmp" -d "$album_folder" import -qC "$album_folder" >> "$beets_log" 2>&1

# ----- Fix FLAC tags using metaflac and ffprobe -----
log_info "Post-processing FLAC tags with metaflac and ffprobe..."
fixed_any=0
find "$album_folder" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' flac; do
    if [[ $fixed_any -eq 0 ]]; then
        log_info "Fixing FLAC tags..."
        fixed_any=1
    fi

    artist_credit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$flac" | jq -r '.format.tags.ARTIST_CREDIT // empty')"

    metaflac --remove-tag=ARTIST "$flac"
    metaflac --remove-tag=ALBUMARTIST "$flac"
    metaflac --remove-tag=ALBUMARTIST_CREDIT "$flac"
    metaflac --remove-tag=ALBUMARTISTSORT "$flac"
    metaflac --remove-tag=ALBUM_ARTIST "$flac"
    metaflac --remove-tag="ALBUM ARTIST" "$flac"
    metaflac --remove-tag=ARTISTSORT "$flac"
    metaflac --remove-tag=COMPOSERSORT "$flac"
    metaflac --set-tag=ALBUMARTIST="$artist_name" "$flac"

    if [[ -n "$artist_credit" ]]; then
        metaflac --set-tag=ARTIST="$artist_credit" "$flac"
    else
        metaflac --set-tag=ARTIST="$artist_name" "$flac"
    fi
done

log_info "FLAC tag fixing complete."

# ----- Cleanup temp files -----
rm -f "$library_tmp" "$beets_log"

duration=$SECONDS
log_info "Finished processing album '$album_folder_name' in $((duration / 60)) min $((duration % 60)) sec."
log_info "Log saved to $LOG_FILE"

exit 0

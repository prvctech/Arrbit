#!/usr/bin/env bash

# -------------------------------------------------------------------------------------------------------------
# Arrbit - beets_tagger.bash
# Version: v1.0-gs2.6
# Purpose: Ninja logic, GS2.6 style: Lidarr event script to tag music files using beets and metaflac.
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="beets_tagger"
SCRIPT_VERSION="v1.0-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}"

# --- Lidarr Test Event Handling (matches Ninja's logic) ---
if [[ "${lidarr_eventtype:-}" == "Test" ]]; then
    log_info "Tested Successfully"
    log_info "Log saved to $LOG_FILE"
    exit 0
fi

# --- Load Arrbit API bridge ---
source /config/arrbit/connectors/arr_bridge.bash

# --- Album ID: env var, fallback to argument ---
if [[ -z "${lidarr_album_id:-}" ]]; then
    lidarr_album_id="$1"
fi

if [[ -z "$lidarr_album_id" ]]; then
    log_error "No album ID supplied as environment variable or argument. Exiting."
    log_info "Log saved to $LOG_FILE"
    exit 1
fi

log_info "Using lidarr_album_id: $lidarr_album_id"

# --- Fetch album and artist info ---
log_info "Fetching album and artist info from Lidarr API..."
album_response="$(arr_api -X GET "${arrUrl}/api/${arrApiVersion}/album/${lidarr_album_id}")"
if [[ -z "$album_response" || "$album_response" == "null" ]]; then
    log_error "Failed to retrieve album details from Lidarr for album ID: $lidarr_album_id"
    log_info "Log saved to $LOG_FILE"
    exit 2
fi

artist_name="$(echo "$album_response" | jq -r '.artist.artistName // empty')"
artist_path="$(echo "$album_response" | jq -r '.artist.path // empty')"

# --- Fetch first track file to locate album folder ---
track_response="$(arr_api -X GET "${arrUrl}/api/${arrApiVersion}/trackFile?albumId=${lidarr_album_id}")"
track_path="$(echo "$track_response" | jq -r '.[0].path // empty')"
album_folder="$(dirname "$track_path")"
album_folder_name="$(basename "$album_folder")"

log_info "Processing album: '$album_folder_name' (artist: '$artist_name') in folder: $album_folder"

# --- Verify album folder matches artist path (Ninja logic) ---
if echo "$album_folder" | grep "$artist_path" | read; then
    if [[ ! -d "$album_folder" ]]; then
        log_error "Folder missing: \"$album_folder\". Exiting."
        log_info "Log saved to $LOG_FILE"
        exit 3
    fi
else
    log_error "$artist_path not found within \"$album_folder\". Exiting."
    log_info "Log saved to $LOG_FILE"
    exit 4
fi

# --- Only process if there are FLAC files ---
if ! find "$album_folder" -type f -iname "*.flac" | grep -q .; then
    log_error "No FLAC files found in album folder. Only FLAC is supported."
    log_info "Log saved to $LOG_FILE"
    exit 5
fi

# --- Run Beets tagging process (Ninja-style block) ---
SECONDS=0
beets_config="/config/arrbit/config/beets-config.yaml"
library_tmp="/tmp/beets-lidarr.blb"
beets_log="/config/logs/beets-lidarr.log"

rm -f "$library_tmp" "$beets_log"

log_info "Running beets import for: $album_folder"
beet -c "$beets_config" -l "$library_tmp" -d "$album_folder" import -qC "$album_folder" >> "$beets_log" 2>&1

log_info "Fixing FLAC tags..."

fixed=0
find "$album_folder" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
    if [[ $fixed == 0 ]]; then
        fixed=$(( fixed + 1 ))
        log_info "Fixing Flac Tags in folder: $album_folder"
    fi
    artist_credit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r '.format.tags.ARTIST_CREDIT // empty' | sed '/^$/d')"
    metaflac --remove-tag=ARTIST "$file"
    metaflac --remove-tag=ALBUMARTIST "$file"
    metaflac --remove-tag=ALBUMARTIST_CREDIT "$file"
    metaflac --remove-tag=ALBUMARTISTSORT "$file"
    metaflac --remove-tag=ALBUM_ARTIST "$file"
    metaflac --remove-tag="ALBUM ARTIST" "$file"
    metaflac --remove-tag=ARTISTSORT "$file"
    metaflac --remove-tag=COMPOSERSORT "$file"
    metaflac --set-tag=ALBUMARTIST="$artist_name" "$file"
    if [[ -n "$artist_credit" ]]; then
        metaflac --set-tag=ARTIST="$artist_credit" "$file"
    else
        metaflac --set-tag=ARTIST="$artist_name" "$file"
    fi
done

log_info "FLAC tag fixing complete."

rm -f "$library_tmp" "$beets_log"

duration=$SECONDS
log_info "Finished processing album '$album_folder_name' in $((duration / 60)) min $((duration % 60)) sec."
log_info "Log saved to $LOG_FILE"

exit 0

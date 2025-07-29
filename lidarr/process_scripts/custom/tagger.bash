#!/usr/bin/env bash

# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash
# Version: v1.0-gs2.6
# Purpose: GS2.6 with strict Ninja logic—auto-detects album ID from env, works with Lidarr as-is.
# -------------------------------------------------------------------------------------------------------------

# ---- Golden Standard Boilerplate ----
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v1.0-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}"

# ---- Debug/Trace: Log all arguments and environment variables ----
log_info "DEBUG: Script called as: $0 $*"
log_info "DEBUG: Argument 1: '${1:-unset}'"
log_info "DEBUG: lidarr_album_id env: '${lidarr_album_id:-unset}'"
log_info "DEBUG: lidarr_eventtype env: '${lidarr_eventtype:-unset}'"
env | grep -i '^lidarr_' | arrbitLogClean | while read -r line; do log_info "DEBUG: $line"; done

# ---- Lidarr Test Event Handling (Ninja logic) ----
if [[ "${lidarr_eventtype:-}" == "Test" ]]; then
    log_info "Lidarr Test event detected. Exiting successfully."
    log_info "Log saved to $LOG_FILE"
    exit 0
fi

# ---- Album ID: ONLY use env var unless running manually ----
if [[ -z "${lidarr_album_id:-}" ]]; then
    # Allow manual run with argument for debug
    lidarr_album_id="$1"
    if [[ -z "$lidarr_album_id" ]]; then
        log_error "No album ID in environment variable (lidarr_album_id) or argument. Exiting."
        log_info "Log saved to $LOG_FILE"
        exit 1
    fi
    log_info "DEBUG: Using manual argument for album ID: $lidarr_album_id"
else
    log_info "DEBUG: Using env var lidarr_album_id: $lidarr_album_id"
fi

# ---- Load Arrbit API bridge ----
source /config/arrbit/connectors/arr_bridge.bash

# ---- Fetch album and artist info from Lidarr ----
log_info "Fetching album and artist info from Lidarr API for album_id '$lidarr_album_id'"
album_response="$(arr_api -X GET "${arrUrl}/api/${arrApiVersion}/album/${lidarr_album_id}")"
log_info "DEBUG: album_response: $(echo "$album_response" | jq '.')"
if [[ -z "$album_response" || "$album_response" == "null" ]]; then
    log_error "Failed to retrieve album details from Lidarr for album ID: $lidarr_album_id"
    log_info "Log saved to $LOG_FILE"
    exit 2
fi

artist_name="$(echo "$album_response" | jq -r '.artist.artistName // empty')"
artist_path="$(echo "$album_response" | jq -r '.artist.path // empty')"
log_info "DEBUG: artist_name='$artist_name', artist_path='$artist_path'"

# ---- Fetch first track file to locate album folder ----
log_info "Fetching track files for album_id='$lidarr_album_id'"
track_response="$(arr_api -X GET "${arrUrl}/api/${arrApiVersion}/trackFile?albumId=${lidarr_album_id}")"
log_info "DEBUG: track_response: $(echo "$track_response" | jq '.')"
track_path="$(echo "$track_response" | jq -r '.[0].path // empty')"
album_folder="$(dirname "$track_path")"
album_folder_name="$(basename "$album_folder")"
log_info "DEBUG: album_folder='$album_folder', album_folder_name='$album_folder_name'"

log_info "Processing album: '$album_folder_name' (artist: '$artist_name') in folder: $album_folder"

# ---- Verify album folder matches artist path ----
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

# ---- Check for FLAC files ----
if ! find "$album_folder" -type f -iname "*.flac" | grep -q .; then
    log_error "No FLAC files found in album folder. Only FLAC is supported."
    log_info "Log saved to $LOG_FILE"
    exit 5
fi

# ---- Check beets config exists ----
beets_config="/config/arrbit/config/beets-config.yaml"
if [[ ! -f "$beets_config" ]]; then
    log_error "Beets config not found at $beets_config! Exiting."
    log_info "Log saved to $LOG_FILE"
    exit 6
fi

# ---- Run Beets tagging process ----
SECONDS=0
library_tmp="/tmp/beets-lidarr.blb"
beets_log="/config/logs/beets-lidarr.log"

rm -f "$library_tmp" "$beets_log"

log_info "Running beets import for folder: $album_folder"
beet -c "$beets_config" -l "$library_tmp" -d "$album_folder" import -qC "$album_folder" >> "$beets_log" 2>&1

log_info "Beets import done. See $beets_log for details."
log_info "Fixing FLAC tags..."

fixed=0
find "$album_folder" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
    log_info "Processing FLAC file: $file"
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
        log_info "Set ARTIST to '$artist_credit'"
    else
        metaflac --set-tag=ARTIST="$artist_name" "$file"
        log_info "Set ARTIST to '$artist_name'"
    fi
done

log_info "FLAC tag fixing complete."

rm -f "$library_tmp" "$beets_log"

duration=$SECONDS
log_info "Finished processing album '$album_folder_name' in $((duration / 60)) min $((duration % 60)) sec."
log_info "Log saved to $LOG_FILE"

exit 0

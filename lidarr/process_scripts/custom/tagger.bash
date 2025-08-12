#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash - Automatic music tagging script for Lidarr using beets
# Version: v1.0.0-gs2.8.3
# Purpose: This script processes music albums from Lidarr using beets to improve metadata tagging.
# -------------------------------------------------------------------------------------------------------------

# MUST start with helpers and purge (per GS v2.8.3)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

# Script information (reset for GS update)
SCRIPT_NAME="tagger"
SCRIPT_VERSION="v1.0.0-gs2.8.3"
LOG_FILE="/config/logs/arrbit-tagger-$(date +%Y_%m_%d-%H_%M).log"

# Create log directory/file and set permissive permissions (per GS)
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true
chmod 777 "$(dirname "$LOG_FILE")" "$LOG_FILE" 2>/dev/null || true

# Ensure temporary directory exists
TMP_DIR="/config/arrbit/tmp"
mkdir -p "$TMP_DIR" 2>/dev/null || true

# Banner (only line allowed with echo -e; colors from logging_utils)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} script${NC} ${SCRIPT_VERSION} ..."

# Check if this is a test event from Lidarr (avoid connecting to ARR in test mode)
if [ "$lidarr_eventtype" == "Test" ]; then
    log_info "Tested Successfully"
    exit 0
fi

# Ignore rename-type events (case-insensitive) which often lack album ID and can cause loops
_evt_lower=$(printf '%s' "${lidarr_eventtype:-}" | tr '[:upper:]' '[:lower:]')
if [[ "${_evt_lower}" == *rename* || "${_evt_lower}" == *retag* ]]; then
    log_info "Ignoring ${lidarr_eventtype:-} event"
    exit 0
fi

# Connect to ARR only for real runs
if [ ! -f "/config/arrbit/connectors/arr_bridge.bash" ]; then
    log_error "arr_bridge.bash not found at /config/arrbit/connectors/arr_bridge.bash (see log at /config/logs)"
    {
        echo "[WHY]: The universal arr_bridge connector is missing or not mounted at the canonical path";
        echo "[FIX]: Ensure /config/arrbit/connectors/arr_bridge.bash exists and is readable by this container";
    } >> "$LOG_FILE"
    exit 11
fi
# shellcheck source=/dev/null
source "/config/arrbit/connectors/arr_bridge.bash"

# Get album ID from Lidarr
# This can come from environment variable or command line argument
if [ -z "$lidarr_album_id" ]; then
    lidarr_album_id="$1"
fi

# Verify we have an album ID
if [ -z "$lidarr_album_id" ]; then
    # If invoked by Lidarr but no album ID was provided for this event, skip quietly
    if [ -n "${lidarr_eventtype:-}" ]; then
        log_info "Ignoring ${lidarr_eventtype} event without album ID"
        exit 0
    fi
    # Otherwise (manual run without parameter), treat as an error
    log_error "No album ID provided (see log at /config/logs)"
    {
        echo "[WHY]: The script needs a Lidarr album ID to fetch album and track file info";
        echo "[FIX]: Run from Lidarr with a proper event payload or pass an album ID as the first argument";
    } >> "$LOG_FILE"
    exit 1
fi

# Retag events can fire per-track; wait briefly to let Lidarr finish batch retagging
_evt_lower=$(printf '%s' "${lidarr_eventtype:-}" | tr '[:upper:]' '[:lower:]')
 

# Fetch album information from Lidarr API
printf "[Arrbit] Fetching album information for ID: %s\n" "$lidarr_album_id" >> "$LOG_FILE"
# Build full URL for arr_bridge v1.1.0 wrapper (expects URL, not method)
album_info=$(arr_api "${arrUrl}/api/${arrApiVersion}/album/$lidarr_album_id")

if [ -z "$album_info" ]; then
    log_error "Failed to fetch album information (see log at /config/logs)"
    {
        echo "[WHY]: The Lidarr API returned an empty response or the request failed";
        echo "[FIX]: Confirm arr_url/api version/key via arr_bridge.bash and network reachability from this container";
    } >> "$LOG_FILE"
    exit 1
fi

# Extract album artist information
album_artist=$(echo "$album_info" | jq -r '.artist.artistName // empty')
album_artist_path=$(echo "$album_info" | jq -r '.artist.path // empty')

# Validate album metadata
if [ -z "$album_artist" ] || [ -z "$album_artist_path" ]; then
    log_error "Album metadata missing (artist or artist path) (see log at /config/logs)"
    {
        echo "[WHY]: The album payload from Lidarr did not include the artist name or path";
        echo "[FIX]: Verify the album exists in Lidarr and the artist has a valid root folder/path";
    } >> "$LOG_FILE"
    exit 1
fi

# Get track path information
# Use original endpoint casing compatible with Lidarr and prior script
track_files=$(arr_api "${arrUrl}/api/${arrApiVersion}/trackFile?albumId=$lidarr_album_id")
# Avoid Broken pipe from head(1) by selecting within jq
track_path=$(echo "$track_files" | jq -r 'map(select((.path // "") != "")) | (.[0].path // empty)')
folder_path=$(dirname "$track_path")
album_folder_name=$(basename "$folder_path")

printf "[Arrbit] Processing :: %s :: Processing Files...\n" "$album_folder_name" >> "$LOG_FILE"
log_info "Processing album folder: $album_folder_name"
# Validate paths
if [ -z "$track_path" ] || [ -z "$folder_path" ] || [ "$folder_path" = "." ]; then
    log_error "Unable to determine album folder path from track files (see log at /config/logs)"
    {
        echo "[WHY]: No valid track file paths were returned for the album";
        echo "[FIX]: Ensure the album has imported tracks and Lidarr reports their paths";
    } >> "$LOG_FILE"
    exit 1
fi

if ! echo "$folder_path" | grep -Fq "$album_artist_path"; then
    log_error "ERROR :: $album_artist_path not found within \"$folder_path\" (see log at /config/logs)"
    {
        echo "[WHY]: The album folder resolved from track files does not match the expected artist path";
        echo "[FIX]: Verify Lidarr root folders and that the album's tracks are under the artist path";
    } >> "$LOG_FILE"
    exit 1
fi

if [ ! -d "$folder_path" ]; then
    log_error "ERROR :: \"$folder_path\" Folder is missing (see log at /config/logs)"
    {
        echo "[WHY]: The resolved album directory does not exist on disk";
        echo "[FIX]: Check your mounts and that media is present at the expected path";
    } >> "$LOG_FILE"
    exit 1
fi

 

# Check required tools
for bin in beet ffprobe metaflac jq find dirname basename; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        log_error "Missing required tool: $bin (see log at /config/logs)"
        {
            echo "[WHY]: The executable '$bin' was not found in PATH inside the container";
            echo "[FIX]: Install or enable '$bin' in the image, or adjust PATH accordingly";
        } >> "$LOG_FILE"
        exit 1
    fi
done

# Process with Beets function
# This function handles the actual tagging process using beets
process_with_beets() {
    local process_folder="$1"
    
    printf "[Arrbit] %s :: Start Processing...\n" "$process_folder" >> "$LOG_FILE"
    
    # Check if folder contains FLAC files
    if ! find "$process_folder" -type f -iname "*.flac" | grep -q .; then
        log_error "$process_folder :: ERROR :: Only supports flac files, exiting... (see log at /config/logs)"
        # Add detailed error information to log
        echo "[WHY]: No FLAC files were found in the album folder" >> "$LOG_FILE"
        echo "[FIX]: This script only processes FLAC files. Convert your audio files to FLAC format" >> "$LOG_FILE"
        return 1
    fi
    
    # Start processing timer
    SECONDS=0
    
    # Clean up previous files if they exist
    if [ -f /config/arrbit/tmp/library-lidarr.blb ]; then
        rm /config/arrbit/tmp/library-lidarr.blb
        sleep 0.5
    fi
    
    # Do not remove external beets logs; rely on beets-config.yaml for its log path/rotation
    
    if [ -f "/config/arrbit/tmp/beets-lidarr-match" ]; then
        rm "/config/arrbit/tmp/beets-lidarr-match"
        sleep 0.5
    fi
    
    touch "/config/arrbit/tmp/beets-lidarr-match"
    sleep 0.5
    
    printf "[Arrbit] %s :: Begin matching with beets!\n" "$process_folder" >> "$LOG_FILE"
    
    # Ensure beets configuration uses a writable directory
    export XDG_CONFIG_HOME="/config/arrbit/tmp"
    export BEETSDIR="/config/arrbit/tmp/beets"
    mkdir -p "$XDG_CONFIG_HOME" "$BEETSDIR" 2>/dev/null || true

    # Resolve beets config file (single canonical path)
    BEETS_CFG="/config/arrbit/config/beets-config.yaml"
    if [ ! -f "$BEETS_CFG" ]; then
        log_error "$process_folder :: Beets config not found at $BEETS_CFG"
        echo "[WHY]: Beets configuration file is missing" >> "$LOG_FILE"
        echo "[FIX]: Provide a valid beets config at $BEETS_CFG" >> "$LOG_FILE"
        return 1
    fi

    # Do not override or pre-create beets log; rely on value in beets-config.yaml (e.g., /config/logs/arrbit-beets.log)

    # Run beets import
    # -c: Config file path
    # -l: Library database path
    # -d: Destination directory
    # -qC: Quiet mode, no confirmation
        set -o pipefail
        # Sanitize all beets output and write to log only (keep terminal minimal per GS)
        beet -c "$BEETS_CFG" -l /config/arrbit/tmp/library-lidarr.blb -d "$process_folder" import -qC "$process_folder" 2>&1 \
            | arrbitLogClean >> "$LOG_FILE"
        beets_status=${PIPESTATUS[0]}
        set +o pipefail
    if [ ${beets_status:-0} -ne 0 ]; then
        log_error "$process_folder :: Beets import failed (exit ${beets_status}) (see log at /config/logs)"
        echo "[WHY]: Beets failed to run or initialize its config directory" >> "$LOG_FILE"
        echo "[FIX]: Verify permissions on $XDG_CONFIG_HOME and the beets config at $BEETS_CFG" >> "$LOG_FILE"
        return ${beets_status}
    fi
    
    # Fix tags
	log_info "Fixing tags..."
    printf "[Arrbit] %s :: Fixing tags...\n" "$process_folder" >> "$LOG_FILE"
    printf "[Arrbit] %s :: Fixing flac tags...\n" "$process_folder" >> "$LOG_FILE"

    # Fix flac tags
    find "$process_folder" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
        
        # Get artist credit from file
        artist_credit=$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")
        
        # Remove existing tags to ensure clean tagging
        metaflac --remove-tag=ARTIST "$file"
        metaflac --remove-tag=ALBUMARTIST "$file"
        metaflac --remove-tag=ALBUMARTIST_CREDIT "$file"
        metaflac --remove-tag=ALBUMARTISTSORT "$file"
        metaflac --remove-tag=ALBUM_ARTIST "$file"
        metaflac --remove-tag="ALBUM ARTIST" "$file"
        metaflac --remove-tag=ARTISTSORT "$file"
        metaflac --remove-tag=COMPOSERSORT "$file"
        
        # Set album artist tag
        metaflac --set-tag=ALBUMARTIST="$album_artist" "$file"
        
    # Set artist tag - use artist_credit if available, otherwise use album_artist
    if [ ! -z "$artist_credit" ]; then
            metaflac --set-tag=ARTIST="$artist_credit" "$file"
        else
            metaflac --set-tag=ARTIST="$album_artist" "$file"
        fi
    done
    
    printf "[Arrbit] %s :: Fixing tags Complete!\n" "$process_folder" >> "$LOG_FILE"
    
    # Clean up temporary files
    rm -f "/config/arrbit/tmp/beets-lidarr-match" /config/arrbit/tmp/library-lidarr.blb 2>/dev/null || true
    
    # Calculate and log processing duration
    duration=$SECONDS
    printf "[Arrbit] %s :: Finished in %d minutes and %d seconds!\n" "$process_folder" $(($duration / 60)) $(($duration % 60)) >> "$LOG_FILE"
}

# Process the album folder with beets
if process_with_beets "$folder_path"; then
    # Completion message
    log_info "The script ran successfully."
    log_info "Done."
else
    log_error "Processing failed for folder: $folder_path (see log at /config/logs)"
    {
        echo "[WHY]: An upstream step in the tagging pipeline failed";
        echo "[FIX]: Review errors above in the log; resolve the first failure cause and retry";
    } >> "$LOG_FILE"
    exit 1
fi

exit 0
#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash
# Version: v1.1-gs2.7.1
# Purpose: Enhanced FLAC metadata tagger for Lidarr imports. Uses album ID for reliable album identification,
#          handles featuring artists, integrates with Beets, and ensures proper metadata for Plex compatibility.
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v1.1-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/connectors/arr_bridge.bash
arrbitPurgeOldLogs

# ---- TEST BUTTON SKIP LOGIC ----
if [[ "${lidarr_eventtype:-}" == "Test" ]]; then
  log_info "Lidarr Test event detected. Exiting cleanly."
  exit 0
fi

# ---- BANNER ----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting tagger module ${NC}${SCRIPT_VERSION}..."

# --- 1. Get album ID from Lidarr event or command line ---
ALBUM_ID="${lidarr_album_id:-}"

# If album ID not set via Lidarr event, check for manual override
if [[ -z "$ALBUM_ID" ]]; then
  if [[ -n "$1" ]]; then
    ALBUM_ID="$1"
    log_info "Using manually provided album ID: $ALBUM_ID"
  else
    log_error "No album ID provided (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR No album ID provided
[WHY]: lidarr_album_id environment variable is not set and no ID was provided as argument
[FIX]: Either run this script from Lidarr's Connect settings or provide an album ID as argument
EOF
    exit 1
  fi
fi

# --- 2. Query Lidarr API for album details using album ID ---
api_url="${arrUrl}/api/${arrApiVersion}/album/${ALBUM_ID}?apikey=${arrApiKey}"
album_json=$(arr_api "$api_url")

# Check if API call was successful
if ! echo "$album_json" | jq -e '.id' >/dev/null 2>&1; then
  log_error "Failed to retrieve album information from Lidarr API (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to retrieve album information from Lidarr API
[WHY]: API call failed or returned invalid data for album ID: $ALBUM_ID
[FIX]: Check Lidarr API connectivity and verify the album exists in Lidarr
[API Response]
$album_json
[/API Response]
EOF
  exit 1
fi

# Extract album and artist details
album_title=$(echo "$album_json" | jq -r '.title')
album_artist=$(echo "$album_json" | jq -r '.artist.artistName')
album_artist_path=$(echo "$album_json" | jq -r '.artist.path')
album_release_date=$(echo "$album_json" | jq -r '.releaseDate')
album_year=$(echo "$album_release_date" | cut -d'-' -f1)

if [[ -z "$album_artist" || "$album_artist" == "null" ]]; then
  log_error "Could not retrieve album artist from Lidarr API (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not retrieve album artist from Lidarr API
[WHY]: Artist information is missing or invalid in the API response
[FIX]: Verify the album has a valid artist assigned in Lidarr
[API Response]
$album_json
[/API Response]
EOF
  exit 1
fi

log_info "Album details from Lidarr: '$album_title' by '$album_artist' ($album_year)"

# --- 3. Get track file information to determine album path ---
tracks_url="${arrUrl}/api/${arrApiVersion}/trackFile?albumId=${ALBUM_ID}&apikey=${arrApiKey}"
tracks_json=$(arr_api "$tracks_url")

if ! echo "$tracks_json" | jq -e '.[0]' >/dev/null 2>&1; then
  log_error "No track files found for album ID: $ALBUM_ID (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR No track files found for album ID: $ALBUM_ID
[WHY]: The album may not have any track files or the API call failed
[FIX]: Check that the album has track files in Lidarr
[API Response]
$tracks_json
[/API Response]
EOF
  exit 1
fi

# Get the first track path and extract the album folder path
track_path=$(echo "$tracks_json" | jq -r '.[0].path')
ALBUM_PATH=$(dirname "$track_path")
album_folder_name=$(basename "$ALBUM_PATH")

# Verify the album path exists and is within the artist path
if [[ ! -d "$ALBUM_PATH" ]]; then
  log_error "Album path does not exist: $ALBUM_PATH (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Album path does not exist: $ALBUM_PATH
[WHY]: The directory derived from track file path does not exist
[FIX]: Check that the album directory exists and is accessible
EOF
  exit 1
fi

# Verify the album path is within the artist path
if ! echo "$ALBUM_PATH" | grep -q "$album_artist_path"; then
  log_warning "Album path ($ALBUM_PATH) is not within artist path ($album_artist_path)"
fi

log_info "Processing album: $album_folder_name at path: $ALBUM_PATH"

# --- 4. Get track information for featuring artists ---
tracks_info_url="${arrUrl}/api/${arrApiVersion}/track?albumId=${ALBUM_ID}&apikey=${arrApiKey}"
tracks_info_json=$(arr_api "$tracks_info_url")

# --- 5. Run Beets import on the album directory ---
log_info "Running Beets import on album directory"

# Create a temporary beets config that points to the main config
TEMP_CONFIG_DIR=$(mktemp -d)
TEMP_CONFIG_FILE="$TEMP_CONFIG_DIR/config.yaml"

cat > "$TEMP_CONFIG_FILE" <<EOF
import:
  copy: no
  move: no
  write: yes
  resume: no
  quiet: yes
  incremental: no
  log: /config/beets.log
  from_scratch: yes
include: /config/arrbit/config/beets-config.yaml
EOF

# Run beets import
beets_output=$(beet -c "$TEMP_CONFIG_FILE" import -qCW "$ALBUM_PATH" 2>&1)
beets_exit=$?

# Log beets output
printf '[Beets Output]\n%s\n[/Beets Output]\n' "$beets_output" | arrbitLogClean >> "$LOG_FILE"

if [[ $beets_exit -ne 0 ]]; then
  log_warning "Beets import completed with warnings or errors"
else
  log_info "Beets import completed successfully"
fi

# Clean up temp config
rm -rf "$TEMP_CONFIG_DIR"

# --- 6. Process FLAC files to ensure featuring artists are properly tagged ---
shopt -s nullglob
flac_files=("$ALBUM_PATH"/*.flac)

if [[ ${#flac_files[@]} -eq 0 ]]; then
  log_warning "No FLAC files found in album directory"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] WARNING No FLAC files found in album directory
[WHY]: The album directory may not contain any FLAC files
[FIX]: Check that the album directory contains FLAC files
EOF
fi

# Function to normalize featuring artist format
normalize_featuring() {
  local artist="$1"
  
  # Replace various featuring formats with standardized "feat."
  artist=$(echo "$artist" | sed -E 's/\s+(featuring|ft\.?|with|and|&|,)\s+/ feat. /gi')
  
  # If there are multiple "feat." in the string, keep only the first one
  if [[ $(echo "$artist" | grep -o "feat\." | wc -l) -gt 1 ]]; then
    # This is a complex case, handle with Python for better string manipulation
    artist=$(python3 -c "
import re, sys
artist = sys.argv[1]
# Find the first occurrence of feat.
first_feat = re.search(r'(.*?) feat\.(.*)', artist, re.IGNORECASE)
if first_feat:
    main_artist = first_feat.group(1).strip()
    featuring = first_feat.group(2).strip()
    # Replace any subsequent feat. with commas
    featuring = re.sub(r'\s+feat\.\s+', ', ', featuring)
    print(f'{main_artist} feat. {featuring}')
else:
    print(artist)
" "$artist")
  fi
  
  echo "$artist"
}

# Process each FLAC file
fixed=0
for flac_file in "${flac_files[@]}"; do
  if [[ $fixed -eq 0 ]]; then
    fixed=$((fixed + 1))
    log_info "Fixing FLAC tags..."
  fi
  
  filename=$(basename "$flac_file")
  
  # Get track information from file
  track_title=$(metaflac --show-tag=TITLE "$flac_file" | sed 's/^TITLE=//i')
  track_artist=$(metaflac --show-tag=ARTIST "$flac_file" | sed 's/^ARTIST=//i')
  
  # Get artist credit from ffprobe (similar to NINJA's BeetsTagger approach)
  artist_credit=$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$flac_file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")
  
  # Remove unwanted tags
  for tag in ARTIST ALBUMARTIST ALBUMARTIST_CREDIT ALBUMARTISTSORT "ALBUM ARTIST" ALBUM_ARTIST ARTISTSORT COMPOSERSORT; do
    metaflac --remove-tag="$tag" "$flac_file" >>"$LOG_FILE" 2>&1
  done
  
  # Set album artist tags
  metaflac --set-tag="ALBUMARTIST=$album_artist" "$flac_file" >>"$LOG_FILE" 2>&1
  
  # Set artist tag based on artist credit or normalize featuring format
  if [[ -n "$artist_credit" ]]; then
    # Use artist credit if available
    metaflac --set-tag="ARTIST=$artist_credit" "$flac_file" >>"$LOG_FILE" 2>&1
  elif [[ -n "$track_artist" && "$track_artist" != "$album_artist" ]]; then
    # Normalize featuring format
    normalized_artist=$(normalize_featuring "$track_artist")
    metaflac --set-tag="ARTIST=$normalized_artist" "$flac_file" >>"$LOG_FILE" 2>&1
  else
    # Default to album artist
    metaflac --set-tag="ARTIST=$album_artist" "$flac_file" >>"$LOG_FILE" 2>&1
  fi
  
  # Ensure YEAR tag is set
  if [[ -n "$album_year" && "$album_year" != "null" ]]; then
    metaflac --remove-tag=YEAR "$flac_file" >>"$LOG_FILE" 2>&1
    metaflac --set-tag="YEAR=$album_year" "$flac_file" >>"$LOG_FILE" 2>&1
  fi
done

log_info "Tagging complete for $album_folder_name"
exit 0

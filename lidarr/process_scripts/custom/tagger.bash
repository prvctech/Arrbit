#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash
# Version: v1.0.0-gs2.8.2
# Purpose: Enhanced FLAC metadata tagger for Lidarr imports. Handles featuring artists, integrates with Beets,
#          and ensures proper metadata for Plex compatibility.
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v1.0.0-gs2.8.2"
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

# --- 1. Validate environment and paths ---
ALBUM_PATH="${lidarr_release_folder:-}"

# If album path not set via Lidarr event, check for manual override
if [[ -z "$ALBUM_PATH" ]]; then
  if [[ -n "$1" && -d "$1" ]]; then
    ALBUM_PATH="$1"
    log_info "Using manually provided album path: $ALBUM_PATH"
  else
    log_error "No valid album path provided (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR No valid album path provided
[WHY]: lidarr_release_folder environment variable is not set and no valid path was provided as argument
[FIX]: Either run this script from Lidarr's Connect settings or provide a valid directory path as argument
EOF
    exit 1
  fi
fi

if [[ ! -d "$ALBUM_PATH" ]]; then
  log_error "Album path is not a valid directory: $ALBUM_PATH (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Album path is not a valid directory
[WHY]: The specified path does not exist or is not a directory
[FIX]: Check that the path exists and is accessible
EOF
  exit 1
fi

log_info "Tagger started for album path: $ALBUM_PATH"

# --- 2. Query Lidarr API for album and artist details ---
encoded_album_path=$(python3 -c 'import urllib.parse,os; print(urllib.parse.quote(os.environ["ALBUM_PATH"]))')
api_url="${arrUrl}/api/${arrApiVersion}/album?path=${encoded_album_path}&apikey=${arrApiKey}"
album_json=$(arr_api "$api_url")

# Check if API call was successful
if ! echo "$album_json" | jq -e '.[0]' >/dev/null 2>&1; then
  log_error "Failed to retrieve album information from Lidarr API (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to retrieve album information from Lidarr API
[WHY]: API call failed or returned invalid data
[FIX]: Check Lidarr API connectivity and verify the album exists in Lidarr
[API Response]
$album_json
[/API Response]
EOF
  exit 1
fi

# Extract album and artist details
album_id=$(echo "$album_json" | jq -r '.[0].id')
album_title=$(echo "$album_json" | jq -r '.[0].title')
album_artist=$(echo "$album_json" | jq -r '.[0].artist.artistName')
album_release_date=$(echo "$album_json" | jq -r '.[0].releaseDate')
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

# --- 3. Get track information for featuring artists ---
tracks_url="${arrUrl}/api/${arrApiVersion}/track?albumId=${album_id}&apikey=${arrApiKey}"
tracks_json=$(arr_api "$tracks_url")

if ! echo "$tracks_json" | jq -e '.[0]' >/dev/null 2>&1; then
  log_warning "No track information found for album ID: $album_id"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] WARNING No track information found for album ID: $album_id
[WHY]: The album may not have any tracks or the API call failed
[FIX]: Check that the album has tracks in Lidarr
EOF
fi

# --- 4. Run Beets import on the album directory ---
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

# --- 5. Process FLAC files to ensure featuring artists are properly tagged ---
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
for flac_file in "${flac_files[@]}"; do
  filename=$(basename "$flac_file")
  log_info "Processing FLAC file: $filename"
  
  # Get track information from filename
  track_title=$(metaflac --show-tag=TITLE "$flac_file" | sed 's/^TITLE=//i')
  track_artist=$(metaflac --show-tag=ARTIST "$flac_file" | sed 's/^ARTIST=//i')
  
  # Look for featuring artists in track title or artist
  featuring_match=""
  if [[ "$track_title" =~ [Ff]eat\.?|[Ff]eaturing|[Ww]ith|[Ff]t\.? ]]; then
    featuring_match="$track_title"
  elif [[ "$track_artist" =~ [Ff]eat\.?|[Ff]eaturing|[Ww]ith|[Ff]t\.?|&|[Aa]nd ]]; then
    featuring_match="$track_artist"
  fi
  
  # If we have a featuring artist, normalize the format
  if [[ -n "$featuring_match" ]]; then
    # Try to find the track in the Lidarr API response
    track_info=$(echo "$tracks_json" | jq -r --arg title "$track_title" '.[] | select(.title == $title)')
    
    if [[ -n "$track_info" && "$track_info" != "null" ]]; then
      # Get the track title and artist from Lidarr
      lidarr_title=$(echo "$track_info" | jq -r '.title')
      
      # Check if we have artist information from Lidarr
      if [[ -n "$lidarr_title" && "$lidarr_title" != "null" ]]; then
        log_info "Found track in Lidarr: $lidarr_title"
      fi
    fi
    
    # Normalize the featuring format
    normalized_artist=$(normalize_featuring "$track_artist")
    
    if [[ "$normalized_artist" != "$track_artist" ]]; then
      log_info "Updating artist tag: '$track_artist' -> '$normalized_artist'"
      
      # Remove existing artist tags
      metaflac --remove-tag=ARTIST "$flac_file" >>"$LOG_FILE" 2>&1
      
      # Set the normalized artist tag
      metaflac --set-tag="ARTIST=$normalized_artist" "$flac_file" >>"$LOG_FILE" 2>&1
      
      # Also update the ARTISTS tag if it exists
      metaflac --remove-tag=ARTISTS "$flac_file" >>"$LOG_FILE" 2>&1
      metaflac --set-tag="ARTISTS=$normalized_artist" "$flac_file" >>"$LOG_FILE" 2>&1
    fi
  fi
  
  # Always ensure ALBUMARTIST tags are consistent
  for tag in ALBUMARTIST ALBUMARTISTSORT "ALBUM ARTIST" ALBUM_ARTIST; do
    metaflac --remove-tag="$tag" "$flac_file" >>"$LOG_FILE" 2>&1
    metaflac --set-tag="$tag=$album_artist" "$flac_file" >>"$LOG_FILE" 2>&1
  done
  
  # Ensure YEAR tag is set
  if [[ -n "$album_year" && "$album_year" != "null" ]]; then
    metaflac --remove-tag=YEAR "$flac_file" >>"$LOG_FILE" 2>&1
    metaflac --set-tag="YEAR=$album_year" "$flac_file" >>"$LOG_FILE" 2>&1
  fi
  
  # Log the final tags for verification
  current_tags=$(metaflac --list --block-type=VORBIS_COMMENT "$flac_file" | grep -E "^\\s+comment\\[[0-9]+\\]: " | sed 's/^[[:space:]]*comment\[[0-9]*\]: //')
  printf '[Final Tags for %s]\n%s\n[/Final Tags]\n' "$filename" "$current_tags" | arrbitLogClean >> "$LOG_FILE"
done

log_info "Tagging complete for $ALBUM_PATH"
log_info "The module was configured successfully."
echo "[Arrbit] Done."
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash
# Version: v0.4-gs2.7.1
# Purpose: Tags FLAC metadata after Lidarr import. Uses Lidarr API (via arr_bridge) and sets/cleans artist fields.
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v0.4-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/connectors/arr_bridge.bash
arrbitPurgeOldLogs

# ---- BANNER ----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting tagger module ${NC}${SCRIPT_VERSION}..."

# --- 1. Get album path from Lidarr env (automatic, no hardcoding!) ---
ALBUM_PATH="${lidarr_release_folder:-}"
if [[ -z "$ALBUM_PATH" || ! -d "$ALBUM_PATH" ]]; then
  log_error "lidarr_release_folder is not set or is not a valid directory (see log at /config/logs)"
  exit 1
fi
log_info "Tagger started for album path: $ALBUM_PATH"

# --- 2. Query Lidarr API for album artist ---
# URL-encode album path for the API
encoded_album_path=$(python3 -c 'import urllib.parse,os; print(urllib.parse.quote(os.environ["ALBUM_PATH"]))')
api_url="${arrUrl}/api/${arrApiVersion}/album?path=${encoded_album_path}&apikey=${arrApiKey}"
album_json=$(arr_api "$api_url")

# Extract artist name from response
album_artist=$(echo "$album_json" | jq -r '.[0].artist.artistName // empty')
if [[ -z "$album_artist" || "$album_artist" == "null" ]]; then
  log_error "Could not retrieve album artist from Lidarr API for path: $ALBUM_PATH"
  exit 1
fi
log_info "Album artist from Lidarr: $album_artist"

# --- 3. Clean and set tags on all FLAC files ---
shopt -s nullglob
for flacfile in "$ALBUM_PATH"/*.flac; do
  log_info "Cleaning FLAC tags for: $flacfile"

  # Remove unwanted tags
  for tag in ALBUMARTIST ALBUMARTIST_CREDIT ALBUMARTISTSORT "ALBUM ARTIST" ARTISTSORT COMPOSERSORT; do
    metaflac --remove-tag="$tag" "$flacfile" >>"$LOG_FILE" 2>&1
  done

  # Set all standard album artist tags to the new artist
  for tag in ALBUMARTIST ALBUMARTISTSORT "ALBUM ARTIST" ALBUM_ARTIST; do
    metaflac --set-tag="$tag=$album_artist" "$flacfile" >>"$LOG_FILE" 2>&1
  done

  log_info "Finished FLAC tag cleanup: $flacfile"
done

log_info "Tagging complete for $ALBUM_PATH"
exit 0

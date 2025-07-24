#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash
# Version : v2.4
# Purpose : Tag imported music files using Beets; ensures correct artist/album metadata. Golden Standard enforced.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v2.4"
ARRBIT_CONF="/config/arrbit/config/arrbit-config.conf"
BEETS_CONFIG="/config/arrbit/beets-config.yaml"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

# ------------------- Logging Functions (Golden Standard) -------------------
log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# ------------------- Startup Banner ----------------------------------------
log_info "${YELLOW}${SCRIPT_NAME}.bash${NC} ${SCRIPT_VERSION}"

# ------------------- Config Sourcing & Validation --------------------------
if [[ ! -f "$ARRBIT_CONF" ]]; then
  log_error "Config file missing: $ARRBIT_CONF"
  exit 1
fi
source "$ARRBIT_CONF"

# ------------------- Environment/Argument Validation -----------------------
if [[ "${lidarr_eventtype:-}" == "Test" ]]; then
  log_info "Test event received. Exiting successfully."
  exit 0
fi

lidarr_album_id="${1:-${lidarr_album_id:-}}"
if [[ -z "$lidarr_album_id" ]]; then
  log_error "No album ID received as argument or environment. Exiting."
  exit 1
fi

if [[ ! -f "$BEETS_CONFIG" ]]; then
  log_error "Beets config missing: $BEETS_CONFIG"
  exit 1
fi

if [[ -z "${arrUrl:-}" || -z "${arrApiKey:-}" ]]; then
  log_error "arrUrl or arrApiKey not set in environment or config."
  exit 1
fi

SECONDS=0

# ------------------- Utility: Fetch Artist/Album Data ----------------------
fetch_artist_data() {
  # Usage: fetch_artist_data <album_id> <file_path>
  local album_id="$1"
  local file="$2"
  album_json=$(curl -fsSL "$arrUrl/api/v1/album/$album_id" -H "X-Api-Key: ${arrApiKey}")
  album_artist="$(echo "$album_json" | jq -r .artist.artistName)"
  artist_credit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" 2>/dev/null | jq -r '.format.tags.ARTIST_CREDIT // empty')"
}

# ------------------- Process a Single FLAC File ----------------------------
process_flac_file() {
  local file="$1"
  fetch_artist_data "$lidarr_album_id" "$file"
  metaflac --remove-tag=ARTIST "$file"
  metaflac --remove-tag=ALBUMARTIST "$file"
  metaflac --set-tag=ALBUMARTIST="$album_artist" "$file"
  if [[ -n "$artist_credit" ]]; then
    metaflac --set-tag=ARTIST="$artist_credit" "$file"
  else
    metaflac --set-tag=ARTIST="$album_artist" "$file"
  fi
}

# ------------------- Process a Single MP3 File -----------------------------
process_mp3_file() {
  local file="$1"
  fetch_artist_data "$lidarr_album_id" "$file"
  id3v2 --delete-all "$file"
  id3v2 --TPE2 "$album_artist" "$file"
  if [[ -n "$artist_credit" ]]; then
    id3v2 --artist "$artist_credit" "$file"
  else
    id3v2 --artist "$album_artist" "$file"
  fi
}

# ------------------- Main Processing Function ------------------------------
process_with_beets() {
  local import_folder="$1"
  export XDG_CONFIG_HOME="/config/arrbit"
  log_info "Running Beets import for: $import_folder"
  if ! beet -c "$BEETS_CONFIG" import -qC "$import_folder"; then
    log_error "Beets import failed."
    exit 1
  fi
  log_info "Beets tagging completed for: $import_folder"

  # FLAC tagging
  find "$import_folder" -type f -iname "*.flac" | while read -r flac; do
    log_info "Cleaning FLAC: $flac"
    process_flac_file "$flac"
  done

  # MP3 tagging
  find "$import_folder" -type f -iname "*.mp3" | while read -r mp3; do
    log_info "Cleaning MP3: $mp3"
    process_mp3_file "$mp3"
  done
}

# ------------------- Resolve Import Folder ---------------------------------
track_path="$(curl -fsSL "$arrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .[].path | head -n1)"
if [[ -z "$track_path" || "$track_path" == "null" ]]; then
  log_error "Could not resolve track path for albumId $lidarr_album_id"
  exit 1
fi

import_folder="$(dirname "$track_path")"
log_info "Resolved import path: $import_folder"

# ------------------- Main Run ----------------------------------------------
process_with_beets "$import_folder"

# ------------------- Completion Banner -------------------------------------
duration=$SECONDS
log_info "Tag cleanup completed for $import_folder in $(($duration / 60))m $(($duration % 60))s"
exit 0

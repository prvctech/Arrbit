#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger.bash
# Version : v2.3
# Purpose : Tag imported music files using Beets, ensure correct artist/album metadata. Golden Standard enforced.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v2.3"
ARRBIT_CONF="/config/arrbit/config/arrbit-config.conf"
BEETS_CONFIG="/config/arrbit/beets-config.yaml"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

# ----- Logging functions ----------------------------------------------------------------
log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"                # Terminal: colored
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"       # Log file: plain
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# ----- Startup banner -------------------------------------------------------------------
log_info "${YELLOW}${SCRIPT_NAME}.bash${NC} ${SCRIPT_VERSION}"

# ----- Config file check and source -----------------------------------------------------
if [[ ! -f "$ARRBIT_CONF" ]]; then
  log_error "Config file missing: $ARRBIT_CONF"
  exit 1
fi
source "$ARRBIT_CONF"

# ----- Environment and argument checks --------------------------------------------------
if [[ "${lidarr_eventtype:-}" == "Test" ]]; then
  log_info "Test event received. Exiting successfully."
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  log_error "No album ID argument received. Exiting."
  exit 1
fi

lidarr_album_id="$1"

if [[ ! -f "$BEETS_CONFIG" ]]; then
  log_error "Beets config missing: $BEETS_CONFIG"
  exit 1
fi

if [[ -z "${arrUrl:-}" || -z "${arrApiKey:-}" ]]; then
  log_error "arrUrl or arrApiKey not set in environment or config."
  exit 1
fi

# ----- Resolve import folder ------------------------------------------------------------
track_path="$(curl -fsSL "$arrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .[].path | head -n1)"
if [[ -z "$track_path" || "$track_path" == "null" ]]; then
  log_error "Could not resolve track path for albumId $lidarr_album_id"
  exit 1
fi

import_folder="$(dirname "$track_path")"
log_info "Resolved import path: $import_folder"

# ----- Run Beets tagging ----------------------------------------------------------------
export XDG_CONFIG_HOME="/config/arrbit"
log_info "Running Beets import..."
if ! beet -c "$BEETS_CONFIG" import -qC "$import_folder"; then
  log_error "Beets import failed."
  exit 1
fi
log_info "Beets tagging completed."

# ----- Function to fetch artist/credit --------------------------------------------------
fetch_artist_data() {
  album_json=$(curl -fsSL "$arrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}")
  album_artist="$(echo "$album_json" | jq -r .artist.artistName)"
  artist_credit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$1" 2>/dev/null | jq -r '.format.tags.ARTIST_CREDIT // empty')"
}

# ----- Tag cleanup: FLAC files ----------------------------------------------------------
find "$import_folder" -type f -iname "*.flac" | while read -r file; do
  log_info "Cleaning FLAC: $file"
  fetch_artist_data "$file"
  metaflac --remove-tag=ARTIST "$file"
  metaflac --remove-tag=ALBUMARTIST "$file"
  metaflac --set-tag=ALBUMARTIST="$album_artist" "$file"
  if [[ -n "$artist_credit" ]]; then
    metaflac --set-tag=ARTIST="$artist_credit" "$file"
  else
    metaflac --set-tag=ARTIST="$album_artist" "$file"
  fi
done

# ----- Tag cleanup: MP3 files -----------------------------------------------------------
find "$import_folder" -type f -iname "*.mp3" | while read -r file; do
  log_info "Cleaning MP3: $file"
  fetch_artist_data "$file"
  id3v2 --delete-all "$file"
  id3v2 --TPE2 "$album_artist" "$file"
  if [[ -n "$artist_credit" ]]; then
    id3v2 --artist "$artist_credit" "$file"
  else
    id3v2 --artist "$album_artist" "$file"
  fi
done

# ----- Completion banner -----------------------------------------------------------------
log_info "Tag cleanup completed for $import_folder"
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - tagger
# Version: v0.1-gs2.7.1
# Purpose: Tags music after Lidarr import using Beets and per-format tools. Triggered by Lidarr (env var).
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="tagger"
SCRIPT_VERSION="v0.1-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
arrbitPurgeOldLogs

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting tagger module ${NC}${SCRIPT_VERSION}..."

ALBUM_PATH="${lidarr_release_folder:-}"
if [[ -z "$ALBUM_PATH" || ! -d "$ALBUM_PATH" ]]; then
  log_error "lidarr_release_folder is not set or is not a valid directory (see log at /config/logs)"
  exit 1
fi

log_info "Processing album folder: $ALBUM_PATH"

# Use beets with the custom config
BEETS_CMD="beet -c /config/config/beets-config.yaml"
log_info "Running beets import for $ALBUM_PATH"
$BEETS_CMD import "$ALBUM_PATH" >>"$LOG_FILE" 2>&1

# Loop all audio files in the album dir (add more extensions as needed)
shopt -s nullglob
for musicfile in "$ALBUM_PATH"/*; do
  case "${musicfile,,}" in
    *.flac)
      log_info "Tagging FLAC file: $musicfile"
      # metaflac logic here
      ;;
    *.mp3)
      log_info "Tagging MP3 file: $musicfile"
      # eyed3 logic here
      ;;
    *.ogg|*.oga)
      log_info "Tagging OGG file: $musicfile"
      # vorbiscomment logic here
      ;;
    *.m4a|*.mp4|*.aac)
      log_info "Tagging M4A/MP4/AAC file: $musicfile"
      # AtomicParsley logic here
      ;;
    *.opus)
      log_info "Tagging OPUS file: $musicfile"
      # opustags logic here
      ;;
    *)
      log_info "Skipping non-audio file: $musicfile"
      ;;
  esac
done

log_info "Tagging complete for $ALBUM_PATH"
exit 0

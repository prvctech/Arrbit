#!/usr/bin/env bash
SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.7-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
arrbitPurgeOldLogs

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${SCRIPT_VERSION}..."

# --- Install system packages ---
apk add --no-cache --upgrade \
  tidyhtml musl-locales musl-locales-lang flac jq git gcc ffmpeg imagemagick opus-tools opustags python3-dev libc-dev parallel npm ripgrep python3 python3-pip vorbis-tools uv >>"$LOG_FILE" 2>&1

# --- AtomicParsley from edge/testing ---
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1 || {
  log_error "Failed to install atomicparsley"
  exit 1
}

# --- Python dependencies via uv ---
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests >>"$LOG_FILE" 2>&1

# --- Wrapper for eyed3 ---
if ! command -v eyed3 >/dev/null 2>&1; then
  echo '#!/bin/sh' > /usr/local/bin/eyed3
  echo 'exec python3 -m eyed3.main "$@"' >> /usr/local/bin/eyed3
  chmod +x /usr/local/bin/eyed3
fi

# --- Final verification ---
missing=""
for cmd in atomicparsley python3 pip3 uv eyed3 vorbiscomment metaflac opustags yq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

if [[ -n "$missing" ]]; then
  log_error "Missing required dependencies:$missing"
  exit 1
fi

log_info "Done."
exit 0

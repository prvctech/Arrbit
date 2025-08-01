#!/usr/bin/env bash
SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v2.1-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
arrbitPurgeOldLogs
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${NC} ${SCRIPT_VERSION}..."

# UV first
apk add --no-cache uv >>"$LOG_FILE" 2>&1

apk add --no-cache \
  tidyhtml \
  musl-locales \
  musl-locales-lang \
  flac \
  jq \
  git \
  gcc \
  ffmpeg \
  imagemagick \
  opus-tools \
  opustags \
  python3 \
  vorbis-tools \
  parallel \
  npm \
  ripgrep \
  beets >>"$LOG_FILE" 2>&1

apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1

# Python tools via uv if necessary
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests >>"$LOG_FILE" 2>&1

# Eyed3 CLI wrapper
if ! command -v eyed3 >/dev/null 2>&1; then
  echo '#!/bin/sh' > /usr/local/bin/eyed3
  echo 'exec python3 -m eyed3.main "$@"' >> /usr/local/bin/eyed3
  chmod +x /usr/local/bin/eyed3
fi

# Final verification
missing=""
for cmd in beets beet atomicparsley python3 uv eyed3 yq vorbiscomment metaflac opustags; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

if [[ -n "$missing" ]]; then
  log_error "Missing required dependencies:$missing"
  exit 1
fi

log_info "All required dependencies are present."
log_info "Done."
exit 0

#!/usr/bin/env bash
SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.8-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
arrbitPurgeOldLogs

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${SCRIPT_VERSION}..."

apk add --no-cache \
  tidyhtml musl-locales musl-locales-lang flac jq git gcc ffmpeg imagemagick opus-tools opustags python3 vorbis-tools parallel npm ripgrep

# AtomicParsley (edge repo)
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley

# --- pip3 setup ---
python3 -m ensurepip --upgrade || true

if ! command -v pip3 >/dev/null 2>&1; then
  wget -qO /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
  python3 /tmp/get-pip.py
fi

# --- python packages ---
pip3 install --upgrade pip
pip3 install eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests

# --- Eyed3 CLI wrapper ---
if ! command -v eyed3 >/dev/null 2>&1; then
  echo '#!/bin/sh' > /usr/local/bin/eyed3
  echo 'exec python3 -m eyed3.main "$@"' >> /usr/local/bin/eyed3
  chmod +x /usr/local/bin/eyed3
fi

# --- Post-install check ---
missing=""
for cmd in atomicparsley python3 pip3 eyed3 vorbiscomment metaflac opustags yq; do
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

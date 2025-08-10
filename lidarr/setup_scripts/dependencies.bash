#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - dependencies.bash
# Version: v1.0.1-gs2.8.2
# Purpose: Silent dependency installer for Arrbit (Golden Standard v2.8.2 compliant)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.0.1-gs2.8.2"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- Setup version tracking (prevent re-installation) ---
SETUP_VERSION_FILE="/config/setup_version.txt"
CURRENT_VERSION="1.0.0"

if [[ -f "$SETUP_VERSION_FILE" ]]; then
  source "$SETUP_VERSION_FILE"
  if [[ "$CURRENT_VERSION" == "$setupversion" ]]; then
    # Check if key dependencies are already installed
    if apk --no-cache list | grep installed | grep opus-tools >/dev/null 2>&1; then
      printf '[Arrbit] Dependencies already installed. Skipping.\n' | arrbitLogClean >> "$LOG_FILE"
      exit 0
    fi
  fi
fi

# --- Check required dependencies ---
REQUIRED_CMDS="beet atomicparsley python3 uv eyed3 yq vorbiscomment metaflac opustags"
missing=""
for cmd in $REQUIRED_CMDS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

if [[ -z "$missing" ]]; then
  # All dependencies present - update version and silent exit
  echo "setupversion=$CURRENT_VERSION" > "$SETUP_VERSION_FILE"
  exit 0
fi

# --- Install missing dependencies (silent operation, all output to log) ---
log_info "Installing missing dependencies: $missing" >> "$LOG_FILE"

# Install uv package manager first
apk add --no-cache uv >>"$LOG_FILE" 2>&1

# Install core packages (including missing python3-dev and libc-dev)
apk add -U --upgrade --no-cache \
  tidyhtml \
  musl-locales \
  musl-locales-lang \
  flac \
  jq \
  git \
  gcc \
  ffmpeg \
  ffprobe \
  imagemagick \
  opus-tools \
  opustags \
  python3 \
  python3-dev \
  libc-dev \
  vorbis-tools \
  parallel \
  npm \
  ripgrep \
  lame \
  faac \
  mp4v2-utils \
  id3lib \
  taglib \
  aria2 >>"$LOG_FILE" 2>&1

# Install edge/testing packages
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets >>"$LOG_FILE" 2>&1
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1

# Install comprehensive Python packages via uv (focused on core functionality)
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests \
  yt-dlp pyxDamerauLevenshtein colorama \
  pylast r128gain tidal-dl-ng \
  python-cryptography python-requests-oauthlib \
  plexapi >>"$LOG_FILE" 2>&1

# Create eyed3 CLI wrapper if needed
if ! command -v eyed3 >/dev/null 2>&1; then
  echo '#!/bin/sh' > /usr/local/bin/eyed3
  echo 'exec python3 -m eyed3.main "$@"' >> /usr/local/bin/eyed3
  chmod +x /usr/local/bin/eyed3
fi

# --- Post-install verification ---
missing_after=""
for cmd in $REQUIRED_CMDS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_after="$missing_after $cmd"
  fi
done

if [[ -n "$missing_after" ]]; then
  # Error case - only output on failure (setup script rule)
  log_error "Failed to install required dependencies: $missing_after (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to install required dependencies: $missing_after
[WHY]: Package installation failed or packages are not available in the configured repositories
[FIX]: Check the log file for detailed installation errors, verify repository availability, or manually install missing packages
[Missing Commands] $missing_after
[Installation Log]
$(cat "$LOG_FILE")
[/Installation Log]
EOF
  exit 1
fi

# --- Update setup version and success exit ---
echo "setupversion=$CURRENT_VERSION" > "$SETUP_VERSION_FILE"

# Success - silent exit (setup script rule)
printf '[Arrbit] Dependencies installation completed successfully.\n' | arrbitLogClean >> "$LOG_FILE"
exit 0

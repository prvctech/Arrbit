#!/usr/bin/env bash
# Simple dependencies installer for Arrbit - with standardized paths

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v3.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Create log directory if it doesn't exist
mkdir -p /config/logs
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Source logging utilities if available
if [ -f /config/arrbit/helpers/logging_utils.bash ]; then
  source /config/arrbit/helpers/logging_utils.bash
  echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${NC}${SCRIPT_VERSION}..."
else
  echo "[Arrbit] Starting dependencies setup ${SCRIPT_VERSION}..."
fi

# Install all required packages
echo "[Arrbit] Installing required packages..."
apk add -U --upgrade --no-cache \
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
  python3-dev \
  libc-dev \
  uv \
  parallel \
  npm \
  wget \
  curl >> "$LOG_FILE" 2>&1

# Install packages from testing repository
echo "[Arrbit] Installing packages from testing repository..."
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >> "$LOG_FILE" 2>&1

# Install Python packages
echo "[Arrbit] Installing Python packages..."
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  jellyfish \
  beautifulsoup4 \
  beets \
  pyacoustid \
  requests \
  mutagen \
  pyyaml >> "$LOG_FILE" 2>&1

# Install yq v4 directly to /usr/bin (standard location)
echo "[Arrbit] Installing yq v4..."
wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq >> "$LOG_FILE" 2>&1
chmod +x /usr/bin/yq >> "$LOG_FILE" 2>&1

# Create eyed3 wrapper if needed
if ! command -v eyed3 >/dev/null 2>&1; then
  echo '#!/bin/sh' > /usr/bin/eyed3
  echo 'exec python3 -m eyed3.main "$@"' >> /usr/bin/eyed3
  chmod +x /usr/bin/eyed3
fi

# Verify yq installation
if command -v yq >/dev/null 2>&1; then
  yq_version=$(yq --version 2>&1)
  echo "[Arrbit] Successfully installed $yq_version"
else
  echo "[Arrbit] ERROR: Failed to install yq v4"
  exit 1
fi

echo "[Arrbit] All dependencies installed successfully."
exit 0

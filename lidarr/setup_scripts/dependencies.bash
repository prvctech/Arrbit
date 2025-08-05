#!/usr/bin/env bash
# Simple dependencies installer for Arrbit - with standardized paths and proper colors

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v3.0-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Create log directory if it doesn't exist
mkdir -p /config/logs
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Source logging utilities if available
if [ -f /config/arrbit/helpers/logging_utils.bash ]; then
  source /config/arrbit/helpers/logging_utils.bash
  # Banner (only one echo allowed)
  echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${NC}${SCRIPT_VERSION}..."
else
  echo "[Arrbit] Starting dependencies setup ${SCRIPT_VERSION}..."
fi

# Define log functions if not already defined
if ! type log_info >/dev/null 2>&1; then
  # Define ANSI color codes
  CYAN='\033[96m'
  GREEN='\033[92m'
  YELLOW='\033[93m'
  RED='\033[91m'
  NC='\033[0m'
  
  # Define log functions
  log_info() {
    echo -e "${CYAN}[Arrbit]${NC} $*"
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
    fi
  }
  
  log_warning() {
    echo -e "${CYAN}[Arrbit]${NC} ${YELLOW}WARNING:${NC} $*"
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '[Arrbit] WARNING: %s\n' "$*" >> "$LOG_FILE"
    fi
  }
  
  log_error() {
    echo -e "${CYAN}[Arrbit]${NC} ${RED}ERROR:${NC} $*" >&2
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
    fi
  }
  
  arrbitLogClean() {
    cat
  }
fi

# Install all required packages
log_info "Installing required packages..."
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
log_info "Installing packages from testing repository..."
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >> "$LOG_FILE" 2>&1

# Install Python packages
log_info "Installing Python packages..."
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  jellyfish \
  beautifulsoup4 \
  beets \
  pyacoustid \
  requests \
  mutagen \
  pyyaml >> "$LOG_FILE" 2>&1

# Install yq v4 directly to /usr/bin (standard location)
log_info "Installing yq v4..."
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
  log_info "Successfully installed $yq_version"
else
  log_error "Failed to install yq v4"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to install yq v4
[WHY]: Installation of yq failed
[FIX]: Check the log for installation errors and try installing manually:
       wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
EOF
  exit 1
fi

log_info "All dependencies installed successfully."
exit 0

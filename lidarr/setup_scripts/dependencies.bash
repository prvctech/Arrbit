#!/usr/bin/env bash

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v2.8-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
arrbitPurgeOldLogs

# ---- BANNER (Only one echo allowed) ----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${NC}${SCRIPT_VERSION}..."

# YAML support is now required, not optional
REQUIRED_CMDS="beet atomicparsley python3 uv eyed3 vorbiscomment metaflac opustags"
missing=""
for cmd in $REQUIRED_CMDS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

# Check for yq v4.x specifically
if command -v yq >/dev/null 2>&1; then
  yq_version=$(yq --version 2>&1)
  if [[ "$yq_version" == *"version v4"* ]]; then
    log_info "yq v4 already installed"
  else
    log_info "yq version $yq_version detected, will upgrade to v4.x"
    missing="$missing yq-v4"
  fi
else
  missing="$missing yq-v4"
fi

# Check for YAML support in Python as fallback
yaml_support=false
if ! command -v yq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  if ! python3 -c "import yaml" >/dev/null 2>&1; then
    missing="$missing python3-yaml"
  else
    yaml_support=true
  fi
fi

if [[ -z "$missing" ]]; then
  log_info "All required dependencies are present."
  log_info "Done."
  exit 0
else
  # Minimal status, Arrbit GS: only print if something will be installed
  echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Installing missing dependencies...${NC}"
  log_info "Missing dependencies detected: $missing"
fi

# --- Install dependencies (all logs to $LOG_FILE, never echo) ---
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
  wget >>"$LOG_FILE" 2>&1

apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets >>"$LOG_FILE" 2>&1
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1

# Install yq v4 directly from GitHub
log_info "Installing yq v4.x from GitHub..."
mkdir -p /usr/local/bin
wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq >>"$LOG_FILE" 2>&1
chmod +x /usr/local/bin/yq >>"$LOG_FILE" 2>&1

# Verify yq installation
if command -v /usr/local/bin/yq >/dev/null 2>&1; then
  yq_version=$(/usr/local/bin/yq --version 2>&1)
  if [[ "$yq_version" == *"version v4"* ]]; then
    log_info "Successfully installed $yq_version from GitHub"
  else
    log_warning "Installed yq version $yq_version is not v4.x"
  fi
else
  log_error "Failed to install yq to /usr/local/bin"
fi

# Add /usr/local/bin to PATH if it's not already there
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
  export PATH="/usr/local/bin:$PATH"
  echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/profile
  log_info "Added /usr/local/bin to PATH"
fi

# PyYAML is required for configuration
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  eyed3 mutagen beautifulsoup4 jellyfish pyacoustid requests pyyaml >>"$LOG_FILE" 2>&1

# Eyed3 CLI wrapper (if needed)
if ! command -v eyed3 >/dev/null 2>&1; then
  echo '#!/bin/sh' > /usr/local/bin/eyed3
  echo 'exec python3 -m eyed3.main "$@"' >> /usr/local/bin/eyed3
  chmod +x /usr/local/bin/eyed3
fi

# --- Final post-install check ---
missing=""
for cmd in $REQUIRED_CMDS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

# Check for yq v4.x specifically
if command -v /usr/local/bin/yq >/dev/null 2>&1; then
  yq_version=$(/usr/local/bin/yq --version 2>&1)
  if [[ "$yq_version" != *"version v4"* ]]; then
    missing="$missing yq-v4"
  fi
else
  missing="$missing yq-v4"
fi

# Check for YAML support in Python as fallback
if ! command -v /usr/local/bin/yq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  if ! python3 -c "import yaml" >/dev/null 2>&1; then
    missing="$missing python3-yaml"
  fi
fi

if [[ -n "$missing" ]]; then
  log_error "Missing required dependencies after install: $missing (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Missing required dependencies after install: $missing
[WHY]: Installation of some dependencies failed
[FIX]: Check the log for installation errors and try installing manually:
       - For yq-v4: run 'wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq'
       - For python3-yaml: run 'uv pip install --system pyyaml'
EOF
  exit 1
fi

log_info "All required dependencies are present."
log_info "Done."
exit 0

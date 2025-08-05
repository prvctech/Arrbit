#!/usr/bin/env bash

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v2.6-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
arrbitPurgeOldLogs

# ---- BANNER (Only one echo allowed) ----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${NC}${SCRIPT_VERSION}..."

# YAML support is now required, not optional
REQUIRED_CMDS="beet atomicparsley python3 uv eyed3 yq vorbiscomment metaflac opustags"
missing=""
for cmd in $REQUIRED_CMDS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

# Check for YAML support (either yq or PyYAML)
yaml_support=false
if command -v yq >/dev/null 2>&1; then
  yaml_support=true
elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  yaml_support=true
else
  missing="$missing yaml-support"
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
  ripgrep >>"$LOG_FILE" 2>&1

apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets >>"$LOG_FILE" 2>&1
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1

# PyYAML is now required for configuration
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests pyyaml >>"$LOG_FILE" 2>&1

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

# Check for YAML support again - this is now required
yaml_support=false
if command -v yq >/dev/null 2>&1; then
  yaml_support=true
elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  yaml_support=true
else
  missing="$missing yaml-support"
fi

if [[ -n "$missing" ]]; then
  log_error "Missing required dependencies after install: $missing (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Missing required dependencies after install: $missing
[WHY]: Installation of some dependencies failed
[FIX]: Check the log for installation errors and try installing manually:
       - For yaml-support: run 'uv pip install --system pyyaml' or 'apk add yq'
EOF
  exit 1
fi

log_info "All required dependencies are present."
log_info "Done."
exit 0

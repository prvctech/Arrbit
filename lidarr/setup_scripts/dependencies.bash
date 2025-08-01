#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - dependencies.bash
# Version: v1.4-gs2.7.1
# Purpose: Installs required Alpine system packages and Python modules (idempotent, GS-compliant, log to file)
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.4-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs

# ---- BANNER ----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting dependencies setup ${NC} ${SCRIPT_VERSION}..."

# --- Install all system packages (Alpine only), log everything to file ---
apk add --no-cache --upgrade \
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
  ripgrep \
  atomicparsley \
  python3 \
  py3-pip \
  py3-eyed3 \
  vorbis-tools \
  >>"$LOG_FILE" 2>&1
  
# --- Always install yq (pip version, provides xq and yq everywhere) ---
if ! xq --version >/dev/null 2>&1 || ! yq --version >/dev/null 2>&1; then
  pip3 install --break-system-packages --upgrade yq >>"$LOG_FILE" 2>&1
fi

# --- Post-install verification (log_error if missing) ---
missing=""
for cmd in atomicparsley python3 pip3 xq yq jq git gcc ffmpeg magick rg npm parallel uv vorbiscomment metaflac opustags; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing="$missing $cmd"
  fi
done

if [[ -n "$missing" ]]; then
  log_error "Missing required dependencies after install:$missing (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR One or more required dependencies are missing after setup:$missing
[WHY]: Installation failed or not on PATH.
[FIX]: Ensure all dependencies are installed and available in the system PATH.
EOF
  exit 1
else
  log_info "All required dependencies are present."
fi

log_info "Done."
exit 0

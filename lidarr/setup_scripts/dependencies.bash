#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - dependencies
# Version : v1.0
# Purpose : Install / upgrade all system and Python dependencies for Arrbit.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# -------- paths & constants ---------------------------------------------------------
SERVICE_DIR="/config/arrbit"
HELPERS_DIR="$SERVICE_DIR/helpers"
LOG_DIR="/config/logs"
SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.0"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
DEPS_MARKER="$HELPERS_DIR/deps_version.txt"

# -------- prepare log & helpers -----------------------------------------------------
mkdir -p "$LOG_DIR" "$HELPERS_DIR"
touch "$LOG_FILE"; chmod 777 "$LOG_FILE"

/usr/bin/env bash -c 'source "'"$HELPERS_DIR/logging_utils.bash"'"' 2>/dev/null || true

# colour codes (stripped in log by arrbitLogClean)
CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

arrbitPurgeOldLogs 2 2>/dev/null || true

log() {
  local plain="[Arrbit] $*"
  local term="${CYAN}[Arrbit]${NC} $*"
  echo -e "$term"
  if type arrbitLogClean >/dev/null 2>&1; then
    printf '%s\n' "$plain" | arrbitLogClean >>"$LOG_FILE"
  else
    printf '%s\n' "$plain" >>"$LOG_FILE"
  fi
}

# -------- banner --------------------------------------------------------------------
log "Starting ${YELLOW}${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION}"

# -------- dependency check ----------------------------------------------------------
if [[ -f "$DEPS_MARKER" ]]; then
  # shellcheck source=/dev/null
  source "$DEPS_MARKER"
fi

needs_install=false
command -v atomicparsley >/dev/null 2>&1 || needs_install=true

if [[ "${depsversion:-}" == "$SCRIPT_VERSION" && "$needs_install" == false ]]; then
  log "Dependencies already installed - skipping"
  exit 0
fi

if [[ -n "${depsversion:-}" && "$depsversion" != "$SCRIPT_VERSION" ]]; then
  log "Upgrading dependencies (details in log file)"
else
  log "Installing dependencies (details in log file)"
fi

# -------- system packages -----------------------------------------------------------
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
  ripgrep >>"$LOG_FILE" 2>&1

apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1

# -------- Python packages -----------------------------------------------------------
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  jellyfish \
  beautifulsoup4 \
  yt-dlp \
  beets \
  yq \
  pyxDamerauLevenshtein \
  pyacoustid \
  requests \
  colorama \
  python-telegram-bot \
  pylast \
  mutagen \
  r128gain \
  tidal-dl >>"$LOG_FILE" 2>&1

echo "depsversion=$SCRIPT_VERSION" >"$DEPS_MARKER"
log "Dependency installation/upgrade complete"
log "Log saved to $LOG_FILE"
exit 0

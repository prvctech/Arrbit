#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - dependencies
# Version: v1.0-gs2.6
# Purpose: Install / upgrade all system and Python dependencies for Arrbit.
# -------------------------------------------------------------------------------------------------------------

# -------- load logging & helpers (Golden Standard) -----------------------------------------------------------
HELPERS_DIR="/config/arrbit/helpers"
LOG_DIR="/config/logs"
mkdir -p "$LOG_DIR" "$HELPERS_DIR"
source "$HELPERS_DIR/logging_utils.bash"
source "$HELPERS_DIR/helpers.bash"
arrbitPurgeOldLogs 2

# -------- constants & vars -----------------------------------------------------------------
SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.0-gs2.6"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
DEPS_MARKER="$HELPERS_DIR/deps_version.txt"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# -------- banner (GREEN for module name, CYAN for [Arrbit]) -------------------------------
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION}"

# -------- load old deps marker (if present) -----------------------------------------------
if [[ -f "$DEPS_MARKER" ]]; then
  # shellcheck source=/dev/null
  source "$DEPS_MARKER"
fi

# -------- dependency check logic ----------------------------------------------------------
needs_install=false
command -v atomicparsley >/dev/null 2>&1 || needs_install=true

if [[ "${depsversion:-}" == "$SCRIPT_VERSION" && "$needs_install" == false ]]; then
  log_info "All dependencies are already installed and up-to-date. Skipping installation."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

if [[ -n "${depsversion:-}" && "$depsversion" != "$SCRIPT_VERSION" ]]; then
  log_info "Upgrading dependencies to match $SCRIPT_VERSION..."
else
  log_info "Installing dependencies..."
fi

# -------- system packages -----------------------------------------------------------------
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
  python3-dev \
  libc-dev \
  uv \
  parallel \
  npm \
  ripgrep >>"$LOG_FILE" 2>&1

apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >>"$LOG_FILE" 2>&1

# -------- Python packages -----------------------------------------------------------------
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
  r128gain >>"$LOG_FILE" 2>&1

# -------- update marker -------------------------------------------------------------------
echo "depsversion=$SCRIPT_VERSION" >"$DEPS_MARKER"

log_info "Done with $SCRIPT_NAME."
log_info "Log saved to $LOG_FILE"

exit 0

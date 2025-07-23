#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - plugins
# Version : v3.3
# Purpose : Install / update Deezer, Tidal and Tubifarry plug-ins for Lidarr.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# -------- paths & constants ---------------------------------------------------------
HELPERS_DIR="/config/arrbit/helpers"
PLUGINS_DIR="/config/plugins"
LOG_DIR="/config/logs"
SCRIPT_NAME="plugins"
SCRIPT_VERSION="v3.3"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# -------- helpers & colours ---------------------------------------------------------
mkdir -p "$LOG_DIR" "$PLUGINS_DIR"
touch "$LOG_FILE" ; chmod 777 "$LOG_FILE"

# shellcheck source=/dev/null
source "$HELPERS_DIR/logging_utils.bash"

arrbitPurgeOldLogs 2

CYAN='\033[36m'
PURPLE='\033[35m'
YELLOW='\033[33m'
RED='\033[31m'
NC='\033[0m'

LOG_PREFIX="${CYAN}[Arrbit]${NC}"

log() { # $1 = message with color, $2 = plain version for file (optional)
  local plain="[Arrbit] ${2:-${1//\033\[[0-9;]*[mK]}}"
  echo -e "$LOG_PREFIX $1"
  printf '%s\n' "$plain" | arrbitLogClean >> "$LOG_FILE"
}

log_error() { # $1 = message, $2 = plain version for file (optional)
  local plain="[Arrbit] ERROR: ${2:-${1//\033\[[0-9;]*[mK]}}"
  echo -e "${CYAN}[Arrbit]${NC} ${RED}ERROR:${NC} $1" >&2
  printf '%s\n' "$plain" | arrbitLogClean >> "$LOG_FILE"
}

# -------- startup banner ------------------------------------------------------------
log "Starting ${YELLOW}plugins service${NC} ${SCRIPT_VERSION}"

# util: already contains any .dll?
has_dll() {
  shopt -s nullglob
  local f=("$1"/*.dll)
  (( ${#f[@]} ))
}

install_plugin() {            # $1 name  $2 dir  $3 url
  local name="$1" target="$2" url="$3"
  local coloured="${PURPLE}${name}${NC}"
  local plain="$name"

  # first status line (coloured once)
  if has_dll "$target"; then
    log "$coloured already present – skipping" "[Arrbit] $plain already present – skipping"
    return
  fi

  log "Downloading $coloured …" "[Arrbit] Downloading $plain …"

  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/p.zip" "$url" >>"$LOG_FILE" 2>&1; then
    if unzip -q "$tmp/p.zip" -d "$tmp" >>"$LOG_FILE" 2>&1; then
      mkdir -p "$target"
      mv "$tmp"/* "$target/" && chmod -R 777 "$target"
      log "$plain installed"
    else
      log_error "Failed to unzip $plain – skipped"
    fi
  else
    log_error "Failed to download $plain – skipped"
  fi
  rm -rf "$tmp"
}

# -------- install list --------------------------------------------------------------
install_plugin "Deezer"    "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer" \
  "https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip"

install_plugin "Tidal"     "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"  \
  "https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip"

install_plugin "Tubifarry" "$PLUGINS_DIR/TypNull/Tubifarry" \
  "https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip"

log "Log saved to $LOG_FILE"
exit 0

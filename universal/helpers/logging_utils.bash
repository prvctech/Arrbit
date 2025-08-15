# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version: v1.0.1-gs2.8.2
# Purpose:
#   • log_info, log_error, log_warning : Standardized, colorized logging for Arrbit scripts (with neon/bright colors).
#   • arrbitLogClean       : strip ANSI colours and normalise spacing.
#   • arrbitPurgeOldLogs   : keep only the newest N logs per script prefix (default 3).
# -------------------------------------------------------------------------------------------------------------

# Neon/Bright ANSI color codes (for terminals with 256-color or better support)
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
BLUE='\033[94m'
MAGENTA='\033[95m'
NC='\033[0m'

# You MUST set LOG_FILE in your script before using log_info/log_error/log_warning.

# ------------------------------------------------
# log_info: Standard info logger for Arrbit scripts
# ------------------------------------------------
log_info() {
  # Terminal: Neon cyan [Arrbit], normal text
  echo -e "${CYAN}[Arrbit]${NC} $*"
  # Log: Plain, no color
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[Arrbit] %s\n' "$*" | arrbitLogClean >> "$LOG_FILE"
  fi
}

# ------------------------------------------------
# log_warning: Standard warning logger (neon yellow WARNING)
# ------------------------------------------------
log_warning() {
  # Terminal: Neon cyan [Arrbit], neon yellow WARNING
  echo -e "${CYAN}[Arrbit]${NC} ${YELLOW}WARNING:${NC} $*"
  # Log: Plain, no color
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[Arrbit] WARNING: %s\n' "$*" | arrbitLogClean >> "$LOG_FILE"
  fi
}

# ------------------------------------------------
# log_error: Standard error logger (neon red ERROR)
# ------------------------------------------------
log_error() {
  # Terminal: Neon cyan [Arrbit], neon red ERROR
  echo -e "${CYAN}[Arrbit]${NC} ${RED}ERROR:${NC} $*" >&2
  # Log: Plain, no color
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[Arrbit] ERROR: %s\n' "$*" | arrbitLogClean >> "$LOG_FILE"
  fi
}

# ------------------------------------------------
# arrbitLogClean: Strip ALL ANSI color codes (cyan, green, yellow, red, blue, magenta, etc.), normalize spacing.
# ------------------------------------------------
arrbitLogClean() {
  # Remove all ANSI escape sequences (colors/styles)
  sed -r 's/\x1B\[[0-9;]*[JKmsu]//g' | \
  sed -r 's/^[[:space:]]+//' | \
  sed -r 's/\]\s+/] /' | \
  sed -r 's/[[:space:]]{2,}/ /g' | \
  sed -r 's/[[:space:]]+$//'
}

# ------------------------------------------------
# arrbitPurgeOldLogs  [max_files]
# Keep only the newest max_files per prefix (arrbit-<name>-YYYY_MM_DD-HH_MM.log), default 3
# ------------------------------------------------
arrbitPurgeOldLogs() {
  local max_files="${1:-3}"
  local primary="/config/logs"
  local secondary="/app/arrbit/data/logs"
  local log_dir=""

  if [ -d "$primary" ]; then
    log_dir="$primary"
  elif [ -d "$secondary" ]; then
    log_dir="$secondary"
  else
    return 0
  fi

  # Prefer arrbit-* prefix; if none exist, fall back to any *.log retention.
  local prefixes
  prefixes=$(ls -1 "$log_dir"/arrbit-*.log 2>/dev/null | sed -E 's#.*/(arrbit-[^-]+)-.*#\1#' | sort -u || true)

  if [ -z "$prefixes" ]; then
    # Fallback: apply simple retention across generic *.log files (excluding currently open one is out-of-scope here)
    ls -1t "$log_dir"/*.log 2>/dev/null | tail -n +$((max_files + 1)) | xargs -r rm -f
    return 0
  fi

  while IFS= read -r prefix; do
    ls -1t "$log_dir"/"${prefix}"-*.log 2>/dev/null | tail -n +$((max_files + 1)) | xargs -r rm -f
  done <<< "$prefixes"
}

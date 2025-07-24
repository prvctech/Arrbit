# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version : v2.5
# Purpose :
#   • log_info, log_error, log_warning : Standardized, colorized logging for Arrbit scripts (with neon/bright colors).
#   • arrbitLogClean       : strip ANSI colours and normalise spacing.
#   • arrbitPurgeOldLogs   : delete old Arrbit logs (default >2 days).
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
# arrbitPurgeOldLogs  [days]
# ------------------------------------------------
arrbitPurgeOldLogs() {
  local days="${1:-2}"
  local log_dir="/config/logs"
  [ -d "$log_dir" ] && find "$log_dir" -type f -name 'arrbit-*' -mtime +"$days" -delete
}

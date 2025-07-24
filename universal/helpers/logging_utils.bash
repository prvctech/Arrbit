# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version : v2.3
# Purpose :
#   • log_info, log_error   : Standardized, colorized logging for Arrbit scripts.
#   • arrbitLogClean       : strip ANSI colours and normalise spacing.
#   • arrbitPurgeOldLogs   : delete old Arrbit logs (default >2 days).
# -------------------------------------------------------------------------------------------------------------

CYAN='\033[36m'
NC='\033[0m'

# You MUST set LOG_FILE in your script before using log_info/log_error.

# ------------------------------------------------
# log_info: Standard info logger for Arrbit scripts
# ------------------------------------------------
log_info() {
  # Print to terminal with cyan Arrbit tag
  echo -e "${CYAN}[Arrbit]${NC} $*"
  # Also write plain to log file if LOG_FILE is set
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[Arrbit] %s\n' "$*" | arrbitLogClean >> "$LOG_FILE"
  fi
}

# ------------------------------------------------
# log_error: Standard error logger for Arrbit scripts
# ------------------------------------------------
log_error() {
  # Print to stderr with cyan Arrbit tag
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  # Also write plain to log file if LOG_FILE is set
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[Arrbit] ERROR: %s\n' "$*" | arrbitLogClean >> "$LOG_FILE"
  fi
}

# ------------------------------------------------
# arrbitLogClean: Strip ANSI color, normalize spaces.
# ------------------------------------------------
arrbitLogClean() {
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

# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version : v2.2
# Purpose :
#   • log_info, log_error   : Standardized logging for Arrbit scripts.
#   • arrbitLogClean       : strip ANSI colours and normalise spacing.
#   • arrbitPurgeOldLogs   : delete old Arrbit logs (default >2 days).
# -------------------------------------------------------------------------------------------------------------

# ------------------------------------------------
# log_info: Standard info logger for Arrbit scripts
# ------------------------------------------------
log_info() {
  echo "[Arrbit] $*"
}

# ------------------------------------------------
# log_error: Standard error logger for Arrbit scripts
# ------------------------------------------------
log_error() {
  echo "[Arrbit] ERROR: $*" >&2
}

# ------------------------------------------------
# arrbitLogClean
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

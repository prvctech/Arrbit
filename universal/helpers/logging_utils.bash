# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version : v2.2
# Purpose :
#   • arrbitLogClean       : strip ANSI colours and normalise spacing.
#   • arrbitPurgeOldLogs   : delete old Arrbit logs (default >2 days).
# -------------------------------------------------------------------------------------------------------------

# ------------------------------------------------
# arrbitLogClean
#   Usage: some_command | arrbitLogClean >> "$LOG_FILE"
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
#   Silent cleanup of /config/logs/arrbit-* older than N days (default 2).
# ------------------------------------------------
arrbitPurgeOldLogs() {
  local days="${1:-2}"
  local log_dir="/config/logs"
  [ -d "$log_dir" ] && find "$log_dir" -type f -name 'arrbit-*' -mtime +"$days" -delete
}

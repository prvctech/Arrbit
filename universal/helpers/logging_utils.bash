# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version: v1.0.4-gs2.8.3
# Purpose:
#   • log_info, log_error, log_warning : Standardized, colorized logging for Arrbit scripts (with neon/bright colors).
#   • arrbitLogClean       : strip ANSI colours and normalise spacing.
#   • arrbitPurgeOldLogs   : keep only the newest N logs per script prefix (default 3).
# Dependencies: arrbit_paths.bash for auto-detection (optional)
# -------------------------------------------------------------------------------------------------------------

# Auto-source path detection if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/arrbit_paths.bash" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/arrbit_paths.bash"
fi

# Neon/Bright ANSI color codes (for terminals with 256-color or better support)
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
BLUE='\033[94m'
MAGENTA='\033[95m'
NC='\033[0m'

# You SHOULD set LOG_FILE in your script before using log_info/log_error/log_warning.
# If LOG_FILE is unset or its parent directory is not writable, file logging is skipped.
# Optional environment variables:
#  - ARRBIT_NO_COLOR=1            disable color output
#  - ARRBIT_LOG_LEVEL=<DEBUG|INFO|WARN|ERROR>
#  - ARRBIT_LOG_TIMESTAMP_FORMAT  strftime format for timestamps (default ISO8601)

# ------------------------------------------------
# log_info: Standard info logger for Arrbit scripts
# ------------------------------------------------
log_info() {
  _log_emit "INFO" "$@"
}

# ------------------------------------------------
# log_warning: Standard warning logger (neon yellow WARNING)
# ------------------------------------------------
log_warning() {
  _log_emit "WARN" "$@"
}

# Backwards-compatible alias (some scripts call log_warn)
log_warn() { log_warning "$@"; }

# ------------------------------------------------
# log_error: Standard error logger (neon red ERROR)
# ------------------------------------------------
log_error() {
  _log_emit "ERROR" "$@"
}

# Debug-level logger
log_debug() { _log_emit "DEBUG" "$@"; }

# Internal: map level name to numeric value
_level_to_num() {
  case "${1:-INFO}" in
    DEBUG) echo 10 ;;
    INFO)  echo 20 ;;
    WARN|WARNING) echo 30 ;;
    ERROR) echo 40 ;;
    *) echo 20 ;;
  esac
}

# Internal: decide if message should be emitted based on ARBIT_LOG_LEVEL
_should_log() {
  local req
  req=$(_level_to_num "$1")
  local cur
  cur=$(_level_to_num "${ARRBIT_LOG_LEVEL:-INFO}")
  [ "$req" -ge "$cur" ] && return 0 || return 1
}

# Initialize log file safely (creates parent dir, touches file)
arrbitInitLog() {
  local target="${1:-${LOG_FILE:-}}"
  [ -z "$target" ] && return 1
  local parent
  parent=$(dirname "$target")
  if [ ! -d "$parent" ]; then
    mkdir -p "$parent" 2>/dev/null || return 1
  fi
  touch "$target" 2>/dev/null || return 1
  # export back to caller if LOG_FILE not set
  if [ -z "${LOG_FILE:-}" ]; then
    LOG_FILE="$target"
    export LOG_FILE
  fi
  return 0
}

# Internal: central emitter that prepares timestamp, caller info, and writes to terminal/file
_log_emit() {
  local level="$1"; shift
  local msg="$*"
  _should_log "$level" || return 0

  # Color handling: disable when ARRBIT_NO_COLOR=1 or stdout not a tty
  if [ -n "${ARRBIT_NO_COLOR:-}" ] || [ ! -t 1 ]; then
    local C_CYAN=''
    local C_YELLOW=''
    local C_RED=''
    local C_NC=''
  else
    local C_CYAN="$CYAN"
    local C_YELLOW="$YELLOW"
    local C_RED="$RED"
    local C_NC="$NC"
  fi

  # Timestamp
  local ts_fmt="${ARRBIT_LOG_TIMESTAMP_FORMAT:-%Y-%m-%dT%H:%M:%S%z}"
  local ts
  ts=$(date +"$ts_fmt")

  # Caller info (script name and lineno when available)
  local caller_script
  caller_script="${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-${0}}}"
  caller_script="$(basename "$caller_script")"
  local caller_line
  caller_line="${BASH_LINENO[1]:-0}"

  # Terminal output (colored)
  case "$level" in
    DEBUG) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} [${level}] ${msg}" ;; 
    INFO)  printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${msg}" ;; 
    WARN)  printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_YELLOW}WARNING:${C_NC} ${msg}" ;; 
    ERROR) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_RED}ERROR:${C_NC} ${msg}" >&2 ;; 
    *)     printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${msg}" ;; 
  esac

  # File output: include timestamp and caller metadata if LOG_FILE writable
  if [[ -n "${LOG_FILE:-}" ]] && [[ -w "$(dirname "${LOG_FILE}")" ]]; then
    printf '[%s] [%s] [%s:%s] %s\n' "$ts" "$level" "$caller_script" "$caller_line" "$msg" | arrbitLogClean >> "$LOG_FILE"
  fi
}

# ------------------------------------------------
# arrbitLogClean: Strip ALL ANSI color codes (cyan, green, yellow, red, blue, magenta, etc.), normalize spacing.
# ------------------------------------------------
arrbitLogClean() {
  # Remove ANSI escape sequences and normalize whitespace
  # Uses POSIX -E for extended regex (more portable than -r)
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' | \
  sed -E 's/^[[:space:]]+//' | \
  sed -E 's/\]\s+/] /' | \
  sed -E 's/[[:space:]]{2,}/ /g' | \
  sed -E 's/[[:space:]]+$//'
}

# ------------------------------------------------
# arrbitPurgeOldLogs  [max_files]
# Keep only the newest max_files per prefix (arrbit-<name>-YYYY_MM_DD-HH_MM.log), default 3
# ------------------------------------------------
arrbitPurgeOldLogs() {
  # Usage: arrbitPurgeOldLogs [max_files] [log_dir]
  # Keep only the newest max_files per prefix (arrbit-<name>-YYYY_MM_DD-HH_MM.log), default 3
  local max_files="${1:-3}"
  local primary="/config/logs"
  local secondary="/app/arrbit/data/logs"
  local log_dir="${2:-}"

  if [[ -n "$log_dir" && -d "$log_dir" ]]; then
    : # use provided
  else
    # Try to auto-detect if helpers are available
    if command -v getArrbitLogsDir >/dev/null 2>&1; then
      local detected_logs
      detected_logs=$(getArrbitLogsDir)
      if [[ -n "$detected_logs" && -d "$detected_logs" ]]; then
        log_dir="$detected_logs"
      fi
    fi
    
    # Fallback to common paths if auto-detection failed
    if [[ -z "$log_dir" ]]; then
      if [ -d "$primary" ]; then
        log_dir="$primary"
      elif [ -d "$secondary" ]; then
        log_dir="$secondary"
      else
        return 0
      fi
    fi
  fi

  # Collect prefixes from arrbit-*.log filenames (with fallback for non-GNU find)
  local prefixes
  if find "$log_dir" -maxdepth 1 -printf '%f\n' >/dev/null 2>&1; then
    # GNU find with -printf
    prefixes=$(find "$log_dir" -maxdepth 1 -type f -name 'arrbit-*.log' -printf '%f\n' 2>/dev/null | sed -E 's/^(arrbit-[^-]+)-.*$/\1/' | sort -u || true)
  else
    # Fallback for BusyBox/Alpine find
    prefixes=$(find "$log_dir" -maxdepth 1 -type f -name 'arrbit-*.log' 2>/dev/null | xargs -r basename -a | sed -E 's/^(arrbit-[^-]+)-.*$/\1/' | sort -u || true)
  fi

  if [ -z "$prefixes" ]; then
    # Fallback: apply simple retention across generic *.log files
    if find "$log_dir" -maxdepth 1 -printf '%T@ %p\n' >/dev/null 2>&1; then
      # GNU find with -printf
      mapfile -t files < <(find "$log_dir" -maxdepth 1 -type f -name '*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk -v m="$max_files" 'NR>m {sub(/^[^ ]+ /,""); print}')
    else
      # Fallback using stat
      mapfile -t files < <(find "$log_dir" -maxdepth 1 -type f -name '*.log' -exec stat -c '%Y %n' {} \; 2>/dev/null | sort -nr | awk -v m="$max_files" 'NR>m {sub(/^[^ ]+ /,""); print}')
    fi
    for f in "${files[@]:-}"; do
      rm -f -- "$f" 2>/dev/null || true
    done
    return 0
  fi

  # For each prefix remove older than newest $max_files
  while IFS= read -r prefix; do
    if find "$log_dir" -maxdepth 1 -printf '%T@ %p\n' >/dev/null 2>&1; then
      # GNU find with -printf
      mapfile -t files < <(find "$log_dir" -maxdepth 1 -type f -name "${prefix}-*.log" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk -v m="$max_files" 'NR>m {sub(/^[^ ]+ /,""); print}')
    else
      # Fallback using stat
      mapfile -t files < <(find "$log_dir" -maxdepth 1 -type f -name "${prefix}-*.log" -exec stat -c '%Y %n' {} \; 2>/dev/null | sort -nr | awk -v m="$max_files" 'NR>m {sub(/^[^ ]+ /,""); print}')
    fi
    for f in "${files[@]:-}"; do
      rm -f -- "$f" 2>/dev/null || true
    done
  done <<< "$prefixes"
}

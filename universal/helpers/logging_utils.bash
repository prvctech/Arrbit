# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version: v2.7.0-gs3.0.0 (Added VERBOSE mode: metadata without timestamp)
# Purpose (minimal set):
#   • log_trace / log_info / log_warning / log_error : Colorized terminal output with cyan [Arrbit] prefix.
#   • arrbitLogClean        : Strip ANSI + trim trailing whitespace for file logs.
#   • arrbitPurgeOldLogs    : Simple retention (keep newest N, default 3).
#   • arrbitRefreshLogLevel : Map LOG_TYPE from config (if present) or env → ARRBIT_LOG_LEVEL.
#   • arrbitBanner          : Standard banner (cyan prefix + green script name + optional version).
#
# Terminal Levels:
#   TRACE: [Arrbit] TRACE: message (only when global mode=TRACE)
#   INFO:  [Arrbit] message
#   WARN:  [Arrbit] WARNING message
#   ERROR: [Arrbit] ERROR message
#   (FATAL removed)
# File Log Formats:
#   TRACE   -> [ISO8601] [LEVEL] [script:line] message (all levels incl. TRACE)
#   VERBOSE -> [LEVEL] message (no timestamp; excludes TRACE-level lines; no script:line)
#   INFO    -> [LEVEL] message (compact; excludes TRACE-level lines)
#
# Verbosity Resolution (precedence high→low):
#   1. ARRBIT_LOG_LEVEL_OVERRIDE (TRACE|VERBOSE|INFO case-insensitive)
#   2. ARRBIT_LOG_LEVEL (already exported)
#   3. LOG_LEVEL or legacy LOG_TYPE in config (arrbit-config.conf)
#   4. Default INFO
# Config values accepted: trace | verbose | info (others → info)
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------

# Fixed base path (gs3.0.0)
ARRBIT_BASE="/app/arrbit"
ARRBIT_CONFIG_DIR="${ARRBIT_BASE}/config" 
ARRBIT_LOGS_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${ARRBIT_LOGS_DIR}" 2>/dev/null || true
mkdir -p "${ARRBIT_CONFIG_DIR}" 2>/dev/null || true

# Refresh active log level (simplified)
arrbitRefreshLogLevel() {
  if [ -n "${ARRBIT_LOG_LEVEL_OVERRIDE:-}" ]; then
    ARRBIT_LOG_LEVEL="${ARRBIT_LOG_LEVEL_OVERRIDE}"
  elif [ -n "${ARRBIT_LOG_LEVEL:-}" ]; then
    : # already set
  else
    local cfg="${ARRBIT_CONFIG_DIR}/arrbit-config.conf" raw val
    if [ -f "$cfg" ]; then
      # Prefer LOG_LEVEL=, fallback to legacy LOG_TYPE=
      raw=$(grep -iE '^(LOG_LEVEL|LOG_TYPE)=' "$cfg" 2>/dev/null | tail -n1 || true)
      val=${raw#*=}
      val=$(printf '%s' "$val" | sed -E "s/#.*//; s/[\"']//g; s/^ *//; s/ *$//" | tr '[:upper:]' '[:lower:]')
      case "$val" in
        trace) ARRBIT_LOG_LEVEL=TRACE ;;
        verbose) ARRBIT_LOG_LEVEL=VERBOSE ;;
        info|*) ARRBIT_LOG_LEVEL=INFO ;;
      esac
    else
      ARRBIT_LOG_LEVEL=INFO
    fi
  fi
  export ARRBIT_LOG_LEVEL
}

# Initialise once on load
arrbitRefreshLogLevel

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

# TRACE-level logger (most verbose)
log_trace() { _log_emit "TRACE" "$@"; }
# FATAL-level logger
 # FATAL removed (use log_error for terminal/file critical conditions)

# Internal: map level name to numeric value
_level_to_num() {
  case "${1:-INFO}" in
    TRACE) echo 5 ;;
  VERBOSE) echo 15 ;; # internal gate; VERBOSE behaves like INFO for emission except excludes TRACE
    INFO)  echo 20 ;;
    WARN|WARNING) echo 30 ;;
    ERROR) echo 40 ;;
  FATAL|CRITICAL) echo 50 ;; # retained numeric for backward compatibility if old scripts call _level_to_num
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
    local C_CYAN='' C_YELLOW='' C_RED='' C_GREEN='' C_NC=''
  else
    local C_CYAN="$CYAN" C_YELLOW="$YELLOW" C_RED="$RED" C_GREEN="$GREEN" C_NC="$NC"
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
    TRACE) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} TRACE: ${msg}" ;;
    INFO)  printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${msg}" ;;
    WARN)  printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_YELLOW}WARNING${C_NC} ${msg}" ;;
    ERROR) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_RED}ERROR${C_NC} ${msg}" >&2 ;;
  FATAL|CRITICAL) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_RED}ERROR${C_NC} ${msg}" >&2 ;; # degrade to ERROR output if encountered
  *)     printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${msg}" ;;
  esac

  # File output (three styles): TRACE full; VERBOSE level+message (no ts, no script:line); INFO compact
  if [[ -n "${LOG_FILE:-}" ]] && [[ -w "$(dirname "${LOG_FILE}")" ]]; then
    case "${ARRBIT_LOG_LEVEL}" in
      TRACE)
        printf '[%s] [%s] [%s:%s] %s\n' "$ts" "$level" "$caller_script" "$caller_line" "$msg" | arrbitLogClean >> "$LOG_FILE" ;;
      VERBOSE)
        case "$level" in
          TRACE) : ;; # suppress trace lines in verbose
          *) printf '[%s] %s\n' "$level" "$msg" | arrbitLogClean >> "$LOG_FILE" ;;
        esac ;;
      *)
        case "$level" in
          TRACE) : ;; # suppress trace lines in info
          *) printf '[%s] %s\n' "$level" "$msg" | arrbitLogClean >> "$LOG_FILE" ;;
        esac ;;
    esac
  fi
}

# ------------------------------------------------
# arrbitLogClean: Strip ANSI codes and trim trailing space (simplified)
# ------------------------------------------------
arrbitLogClean() { sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g; s/[[:space:]]+$//'; }

# ---------------------------------------------------------------------------
# arrbitBanner <script_name> [version]
# Standard banner: cyan prefix + green script name + optional version (no log level)
# ---------------------------------------------------------------------------
arrbitBanner() {
  local name="${1:-Script}" ver="${2:-}";
  if [ -n "${ARRBIT_NO_COLOR:-}" ] || [ ! -t 1 ]; then
    [ -n "$ver" ] && echo "[Arrbit] $name $ver" || echo "[Arrbit] $name"
  else
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}${name}${NC} ${ver}" | sed -E 's/ +$//' 
  fi
}

# ------------------------------------------------
# arrbitPurgeOldLogs [max_files] [log_dir]
# Keep newest N (default 3) arrbit-*.log using simple ls ordering.
# ------------------------------------------------
arrbitPurgeOldLogs() {
  local max="${1:-3}" dir="${2:-$ARRBIT_LOGS_DIR}" pattern
  [ -d "$dir" ] || return 0
  pattern="$dir/arrbit-*.log"
  if compgen -G "$pattern" > /dev/null 2>&1; then
    # shellcheck disable=SC2012
    mapfile -t old < <(ls -1t "$dir"/arrbit-*.log 2>/dev/null | tail -n +$((max+1)) || true)
    if [ "${#old[@]}" -gt 0 ]; then
      printf '%s\n' "${old[@]}" | xargs -r rm -f --
    fi
  fi
}

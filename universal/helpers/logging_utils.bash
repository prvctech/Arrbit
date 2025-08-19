# -------------------------------------------------------------------------------------------------------------
# Arrbit - logging_utils.bash
# Version: v2.7.1-gs3.0.0 (Fix: log level detection, VERBOSE now includes TRACE lines, config fallback path)
# Purpose (minimal set):
#   • log_trace / log_info / log_warning / log_error : Colorized terminal output with cyan [Arrbit] prefix.
#   • arrbitLogClean        : Strip ANSI + trim trailing whitespace for file logs.
#   • arrbitPurgeOldLogs    : Simple retention (keep newest N, default 3).
#   • arrbitBanner          : Standard banner (cyan prefix + green script name + optional version).
#
# Terminal Levels:
#   TRACE: [Arrbit] TRACE: message (only when global mode=TRACE)
#   INFO:  [Arrbit] message
#   WARN:  [Arrbit] WARNING message
#   ERROR: [Arrbit] ERROR message
#
# File Log Formats:
#   TRACE   -> [ISO8601] [LEVEL] [script:line] message (all levels incl. TRACE)
#   VERBOSE -> [LEVEL] message (no timestamp; includes TRACE lines; no script:line)
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

_arrbitDetectConfigFile() {
	# Primary fixed path, then common container mount path (/config)
	local p1="${ARRBIT_CONFIG_DIR}/arrbit-config.conf" p2="/config/arrbit/config/arrbit-config.conf"
	if [ -f "$p1" ]; then
		printf '%s' "$p1"
	elif [ -f "$p2" ]; then
		printf '%s' "$p2"
	else
		return 1
	fi
}

# Refresh active log level and export lowercase identifier `log_level`.
# Precedence:
# 1. ARRBIT_LOG_LEVEL_OVERRIDE (explicit override)
# 2. ARRBIT_LOG_LEVEL (environment export/user supplied)
# 3. Config LOG_LEVEL= or legacy LOG_TYPE=
# 4. Default INFO
arrbitRefreshLogLevel() {
	local chosen="" raw val cfg
	if [ -n "${ARRBIT_LOG_LEVEL_OVERRIDE-}" ]; then
		chosen="${ARRBIT_LOG_LEVEL_OVERRIDE}"
	elif [ -n "${ARRBIT_LOG_LEVEL-}" ]; then
		chosen="${ARRBIT_LOG_LEVEL}"
	else
		if cfg=$(_arrbitDetectConfigFile); then
			# Prefer LOG_LEVEL, fallback to LOG_TYPE (legacy) if LOG_LEVEL absent
			raw=$(grep -iE '^(LOG_LEVEL)=' "$cfg" 2>/dev/null | tail -n1 || true)
			if [ -z "$raw" ]; then
				raw=$(grep -iE '^(LOG_TYPE)=' "$cfg" 2>/dev/null | tail -n1 || true)
			fi
			val=${raw#*=}
			val=$(printf '%s' "$val" | sed -E "s/#.*//; s/[\"']//g; s/^ *//; s/ *$//" | tr '[:upper:]' '[:lower:]')
			case "$val" in
				trace) chosen=TRACE ;;
				verbose) chosen=VERBOSE ;;
				info) chosen=INFO ;;
				*) chosen=INFO ;;
			esac
		else
			chosen=INFO
		fi
	fi

	# Normalise + export
	case "${chosen^^}" in
		TRACE) ARRBIT_LOG_LEVEL=TRACE ;;
		VERBOSE) ARRBIT_LOG_LEVEL=VERBOSE ;;
		INFO | *) ARRBIT_LOG_LEVEL=INFO ;;
	esac
	export ARRBIT_LOG_LEVEL
	log_level=$(printf '%s' "${ARRBIT_LOG_LEVEL}" | tr '[:upper:]' '[:lower:]')
	export log_level
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
# shellcheck disable=SC2034 # color constants are exported/used by caller scripts for banner formatting
# shellcheck disable=SC2034 # BLUE MAGENTA C_GREEN etc. appear unused to shellcheck but are consumed externally

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

_should_log() {
	# TRACE: everything. VERBOSE: everything (now includes TRACE). INFO: suppress TRACE lines only.
	local lvl="${1:-INFO}" current="${ARRBIT_LOG_LEVEL:-INFO}"
	case "$current" in
		TRACE) return 0 ;;
		VERBOSE) return 0 ;;
		INFO)
			[ "$lvl" = TRACE ] && return 1 || return 0
			;;
		*) # fallback behaves like INFO
			[ "$lvl" = TRACE ] && return 1 || return 0
			;;
	esac
}

# Initialize log file safely (creates parent dir, touches file)
arrbitInitLog() {
	local target="${1:-${LOG_FILE-}}"
	[ -z "$target" ] && return 1
	local parent
	parent=$(dirname "$target")
	if [ ! -d "$parent" ]; then
		mkdir -p "$parent" 2>/dev/null || return 1
	fi
	touch "$target" 2>/dev/null || return 1
	# export back to caller if LOG_FILE not set
	if [ -z "${LOG_FILE-}" ]; then
		LOG_FILE="$target"
		export LOG_FILE
	fi
	return 0
}

# Internal: central emitter that prepares timestamp, caller info, and writes to terminal/file
_log_emit() {
	local level="$1"
	shift
	local msg="$*"
	_should_log "$level" || return 0

	# Color handling: disable when ARRBIT_NO_COLOR=1 or stdout not a tty
	if [ -n "${ARRBIT_NO_COLOR-}" ] || [ ! -t 1 ]; then
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
	INFO) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${msg}" ;;
	WARN) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_YELLOW}WARNING${C_NC} ${msg}" ;;
	ERROR) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_RED}ERROR${C_NC} ${msg}" >&2 ;;
	FATAL | CRITICAL) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${C_RED}ERROR${C_NC} ${msg}" >&2 ;; # degrade to ERROR output if encountered
	*) printf '%b\n' "${C_CYAN}[Arrbit]${C_NC} ${msg}" ;;
	esac

	# File output (three styles): TRACE full; VERBOSE level+message (no ts, no script:line); INFO compact
	if [[ -n ${LOG_FILE-} ]] && [[ -w "$(dirname "${LOG_FILE}")" ]]; then
		case "${ARRBIT_LOG_LEVEL}" in
		TRACE)
			printf '[%s] [%s] [%s:%s] %s\n' "$ts" "$level" "$caller_script" "$caller_line" "$msg" | arrbitLogClean >>"$LOG_FILE"
			;;
		VERBOSE)
			# Include TRACE lines (simplified format)
			printf '[%s] %s\n' "$level" "$msg" | arrbitLogClean >>"$LOG_FILE"
			;;
		*)
			# INFO mode (suppress TRACE)
			[ "$level" = TRACE ] || printf '[%s] %s\n' "$level" "$msg" | arrbitLogClean >>"$LOG_FILE"
			;;
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
	local name="${1:-Script}" ver="${2-}"
	if [ -n "${ARRBIT_NO_COLOR-}" ] || [ ! -t 1 ]; then
		[ -n "$ver" ] && echo "[Arrbit] $name $ver" || echo "[Arrbit] $name"
	else
		echo -e "${CYAN}[Arrbit]${NC} ${GREEN}${name} ${ver}${NC}" | sed -E 's/ +$//'
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
	if compgen -G "$pattern" >/dev/null 2>&1; then
		# shellcheck disable=SC2012
		mapfile -t old < <(ls -1t "$dir"/arrbit-*.log 2>/dev/null | tail -n +$((max + 1)) || true)
		if [ "${#old[@]}" -gt 0 ]; then
			printf '%s\n' "${old[@]}" | xargs -r rm -f --
		fi
	fi
}

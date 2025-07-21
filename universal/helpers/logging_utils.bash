# -------------------------------------------------------------------------------------------------------------
# Arrbit logging_utils.bash
# Version: v2.2
# Purpose: Unified logging utilities with enforced error hygiene, dynamic LOG_LEVEL sourcing, and clear output.
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_LOGGING_INCLUDED}" ]]; then
  ARRBIT_LOGGING_INCLUDED=1

  # Always source helpers for getFlag
  if ! declare -f getFlag &>/dev/null; then
    CONFIG_DIR="/config/arrbit"
    source "/etc/services.d/arrbit/helpers/helpers.bash"
  fi

  # Internal: Dynamically get LOG_LEVEL from config file (1,2,3 only)
  getLogLevel() {
    local lvl
    lvl=$(getFlag "LOG_LEVEL")
    [[ "$lvl" =~ ^[1-3]$ ]] || lvl=1
    echo "$lvl"
  }

  # Main log output logic, always logs (no level 0, never silenced)
  logCore() {
    local prefix="$1"
    local msg="$2"
    local emoji="$3"
    local color="$4"
    # Always print to terminal with color/emoji
    echo -e "${color}${emoji} [Arrbit]${prefix:+ $prefix}${color:+\033[0m} $msg"
    # Log file output: color/emoji only at level 3
    local lvl; lvl=$(getLogLevel)
    if (( lvl == 3 )); then
      echo -e "${emoji} [Arrbit]${prefix:+ $prefix} $msg" >> "$log_file_path"
    else
      local stripped
      stripped=$(echo -e "${emoji} [Arrbit]${prefix:+ $prefix} $msg" | sed -E 's/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g; s/[🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴💾]//g')
      echo "$stripped" >> "$log_file_path"
    fi
  }

  # Info log (main status)
  logInfo()    { logCore ""       "$1" "🟢" "\033[1;32m"; }
  # Warn log (unexpected but not fatal)
  logWarn()    { logCore "WARN"   "$1" "⚠️" "\033[1;33m"; }
  # Error log (failures)
  logError()   { logCore "ERROR"  "$1" "❌" "\033[1;31m"; }
  # Debug log (for troubleshooting)
  logDebug()   { local lvl; lvl=$(getLogLevel); (( lvl >= 1 )) && logCore "DEBUG" "$1" "🔵" "\033[1;36m"; }
  # Verbose log (very detailed info)
  logVerbose() { local lvl; lvl=$(getLogLevel); (( lvl >= 2 )) && logCore "VERBOSE" "$1" "📄" "\033[0;37m"; }

  # Enforced error hygiene: logs action, resource, cause, hint, function/line number
  logErrorEx() {
    local action="$1"
    local resource="$2"
    local cause="$3"
    local hint="$4"
    local func="${FUNCNAME[1]:-main}"
    local line="${BASH_LINENO[0]:-?}"
    logError "[$func:$line] $action: $resource (cause: $cause)${hint:+. $hint}"
  }

  # Optionally: enable full Bash trace at LOG_LEVEL 3
  enableTraceIfNeeded() {
    local lvl; lvl=$(getLogLevel)
    (( lvl == 3 )) && set -x
  }
fi

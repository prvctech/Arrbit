# -------------------------------------------------------------------------------------------------------------
# Arrbit logging_utils.bash
# Version: v2.0
# Purpose: Minimal logging utility with Golden Standard error logic. Script supplies full log line for arrbitLog.
#          arrbitErrorLog outputs short summary to terminal, structured detail to log file.
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_LOGGING_INCLUDED}" ]]; then
  ARRBIT_LOGGING_INCLUDED=1

  # Always source helpers for getFlag if not present
  if ! declare -f getFlag &>/dev/null; then
    CONFIG_DIR="/config/arrbit"
    source "/etc/services.d/arrbit/helpers/helpers.bash"
  fi

  # Get LOG_LEVEL from config (1,2,3 only; default 1)
  getLogLevel() {
    local lvl
    lvl=$(getFlag "LOG_LEVEL")
    [[ "$lvl" =~ ^[1-3]$ ]] || lvl=1
    echo "$lvl"
  }

  # The only log function: script is responsible for formatting!
  arrbitLog() {
    local msg="$1"
    echo -e "$msg"
    if [[ -n "$log_file_path" ]]; then
      local lvl; lvl=$(getLogLevel)
      if (( lvl == 3 )); then
        echo -e "$msg" >> "$log_file_path"
      else
        # Remove ANSI color codes and GS4 emojis for log file output at levels 1/2
        local stripped
        stripped=$(echo -e "$msg" | sed -E 's/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g; s/[📄🔄📦📥🔧🚀⏩🌐📁📋📄✅❌⚠️🔵🟢🔴]//g')
        echo "$stripped" >> "$log_file_path"
      fi
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # arrbitErrorLog: Golden Standard error logging
  # Terminal: only emoji + summary
  # Log file: full structured fields (what, resource, where, why, hint)
  # -------------------------------------------------------------------------------------------------------------
  arrbitErrorLog() {
    local emoji="${1:-❌}"
    local summary="${2:-[Arrbit] Unknown error}"
    local what="${3:-unknown}"
    local resource="${4:-unknown}"
    local where="${5:-${SCRIPT_NAME}:${LINENO}}"
    local why="${6:-unknown cause}"
    local hint="${7:-No hint available}"

    # Terminal: summary only
    arrbitLog "$emoji  $summary"

    # Log file: full detail
    local full_detail="$emoji  $summary  [what: $what]  [resource: $resource]  [where: $where]  [why: $why]  [hint: $hint]"
    if [[ -n "$log_file_path" ]]; then
      local lvl; lvl=$(getLogLevel)
      if (( lvl == 3 )); then
        echo -e "$full_detail" >> "$log_file_path"
      else
        local stripped
        stripped=$(echo -e "$full_detail" | sed -E 's/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g; s/[📄🔄📦📥🔧🚀⏩🌐📁📋📄✅❌⚠️🔵🟢🔴]//g')
        echo "$stripped" >> "$log_file_path"
      fi
    fi
  }

fi

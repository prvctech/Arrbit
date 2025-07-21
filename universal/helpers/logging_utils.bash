# -------------------------------------------------------------------------------------------------------------
# Arrbit logging_utils.bash
# Version: v1
# Purpose: Minimal logging utility. Script supplies full log line; logger only writes to .log file, strips color/emoji unless LOG_LEVEL=3.
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
        stripped=$(echo -e "$msg" | sed -E 's/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g; s/[📄🔄📦📥🔧🚀⏩🌐📁📋💾✅❌⚠️🔵🟢🔴]//g')
        echo "$stripped" >> "$log_file_path"
      fi
    fi
  }
fi

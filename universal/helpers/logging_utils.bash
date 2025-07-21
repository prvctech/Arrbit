# -------------------------------------------------------------------------------------------------------------
# Arrbit logging_utils.bash
# Version: v2.0
# Purpose: Unified logging utilities with dynamic LOG_LEVEL sourcing from config file every call.
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_LOGGING_INCLUDED}" ]]; then
  ARRBIT_LOGGING_INCLUDED=1

  # Always source helpers for getFlag
  if ! declare -f getFlag &>/dev/null; then
    # fallback location (most setups will have this sourced already)
    CONFIG_DIR="/config/arrbit"
    source "/etc/services.d/arrbit/helpers/helpers.bash"
  fi

  # Internal: Dynamically get LOG_LEVEL from config file (0,1,2,3 only)
  getLogLevel() {
    local lvl
    lvl=$(getFlag "LOG_LEVEL")
    [[ "$lvl" =~ ^[0-3]$ ]] || lvl=0
    echo "$lvl"
  }

  # Pretty output: always to terminal, always with color/emoji
  logStdout() {
    local lvl; lvl=$(getLogLevel)
    if (( lvl > 0 )); then
      echo -e "$1"
    fi
  }

  # Raw output: only to .log, stripped depending on LOG_LEVEL
  logRaw() {
    local lvl; lvl=$(getLogLevel)
    if (( lvl == 3 )); then
      # Level 3: write raw (trace/verbose/unfiltered)
      echo -e "$1" >> "$log_file_path"
    elif (( lvl > 0 )); then
      # Level 1/2: strip emoji and color
      local stripped
      stripped=$(echo -e "$1" | \
        sed -E 's/(\x1B|\033)\[[0-9;]*[a-zA-Z]//g; s/[🚀⏩📥🌐🔧📦📁🔄📋📄✅❌⚠️🔵🟢🔴💾]//g; s/^[[:space:]]+\[Arrbit\]/[Arrbit]/')
      echo "$stripped" >> "$log_file_path"
    fi
    # Level 0: nothing
  }

  log() {
    logStdout "$1"
    logRaw "$1"
  }

  logDebug() {
    local lvl; lvl=$(getLogLevel)
    if (( lvl > 0 )); then
      log "$1"
    fi
  }

  logVerbose() {
    local lvl; lvl=$(getLogLevel)
    if (( lvl > 1 )); then
      log "$1"
    fi
  }
fi

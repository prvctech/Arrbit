# logging_utils.bash

if [[ -z "${ARRBIT_LOGGING_INCLUDED}" ]]; then
  ARRBIT_LOGGING_INCLUDED=1

  # Pretty output: always to terminal, always with color/emoji
  logStdout() {
    if (( LOG_LEVEL > 0 )); then
      echo -e "$1"
    fi
  }

  # Raw output: only to .log, stripped depending on LOG_LEVEL
  logRaw() {
    if (( LOG_LEVEL == 3 )); then
      # Level 3: write raw (trace/verbose/unfiltered)
      echo -e "$1" >> "$log_file_path"
    elif (( LOG_LEVEL > 0 )); then
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
    if (( LOG_LEVEL > 0 )); then
      log "$1"
    fi
  }

  logVerbose() {
    if (( LOG_LEVEL > 1 )); then
      log "$1"
    fi
  }
fi

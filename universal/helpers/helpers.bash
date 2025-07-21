# -------------------------------------------------------------------------------------------------------------
# Arrbit helpers.bash
# Version: v1.1
# Purpose: Reusable helper functions for Arrbit scripts (flag reading, version compare, source guard, dry-run, etc)
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_HELPERS_INCLUDED}" ]]; then
  ARRBIT_HELPERS_INCLUDED=1

  # -------------------------------------------------------
  # Safely get a flag value from the config file (case-insensitive, ignores comments/spaces)
  # Usage: getFlag "ENABLE_PLUGINS"
  # Returns: the value (e.g., true/false), or blank if not found
  # -------------------------------------------------------
  getFlag() {
    local flag_name="$1"
    local config_file="${CONFIG_DIR:-/config/arrbit}/arrbit-config.conf"
    # Convert flag_name to uppercase for case-insensitive search
    local flag_upper
    flag_upper=$(echo "$flag_name" | tr '[:lower:]' '[:upper:]')
    awk -F '=' -v key="$flag_upper" '
      $0 !~ /^[[:space:]]*#/ && NF >= 2 {
        # Remove whitespace in key
        gsub(/[[:space:]]+/, "", $1);
        # Trim value (leading/trailing whitespace)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
        if (toupper($1) == key) {
          # Remove trailing inline comments (e.g., # or ;)
          gsub(/[#;].*$/, "", $2);
          print $2;
          exit
        }
      }
    ' "$config_file" 2>/dev/null | tr -d '"\r'
  }

  # -------------------------------------------------------
  # Compare two version strings: compareVersions old new
  # Returns 0 (true) if new > old (should update), 1 otherwise
  # Usage: compareVersions "v1.0" "v1.1" && echo "Needs update"
  # -------------------------------------------------------
  compareVersions() {
    [[ "$1" == "$2" ]] && return 1
    local a b
    a=$(echo "$1" | tr -d 'v' | tr . ' ')
    b=$(echo "$2" | tr -d 'v' | tr . ' ')
    local i
    for i in 1 2 3; do
      local av bv
      av=$(echo $a | awk "{ print \$$i }")
      bv=$(echo $b | awk "{ print \$$i }")
      av=${av:-0}; bv=${bv:-0}
      if (( av < bv )); then return 0; fi
      if (( av > bv )); then return 1; fi
    done
    return 1
  }

  # -------------------------------------------------------
  # Source guard: prevent this file from being sourced more than once
  # Usage: .sourceGuard "$BASH_SOURCE"
  # -------------------------------------------------------
  .sourceGuard() {
    local guard_var="SOURCE_GUARD_$(echo "$1" | md5sum | awk '{print $1}')"
    [[ -n "${!guard_var}" ]] && return 1
    declare -g "$guard_var=1"
    return 0
  }

  # -------------------------------------------------------
  # DRY_RUN shortcut: returns 0 if dry run is active, 1 otherwise
  # Usage: [[ $(dryRunGuard) -eq 0 ]] && return
  # -------------------------------------------------------
  dryRunGuard() {
    [[ "${DRY_RUN:-false}" == true ]] && return 0
    return 1
  }

  # -------------------------------------------------------
  # Join array with delimiter (Bash 4+)
  # Usage: joinBy , a b c   => "a,b,c"
  # -------------------------------------------------------
  joinBy() {
    local IFS="$1"
    shift
    echo "$*"
  }
fi

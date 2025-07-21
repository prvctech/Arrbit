# -------------------------------------------------------------------------------------------------------------
# Arrbit helpers.bash
# Version: v1.0
# Purpose: Reusable helper functions for Arrbit scripts (flag reading, version compare, source guard, dry-run, etc)
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_HELPERS_INCLUDED}" ]]; then
  ARRBIT_HELPERS_INCLUDED=1

  # -------------------------------------------------------
  # Safely get a flag value from the config file
  # Usage: getFlag "ENABLE_PLUGINS"
  # Returns: the value (e.g., true/false), or blank if not found
  # -------------------------------------------------------
  getFlag() {
    local flag_name="$1"
    local config_file="${CONFIG_DIR:-/config/arrbit}/arrbit-config.conf"
    grep -E "^$flag_name=" "$config_file" 2>/dev/null | cut -d'=' -f2 | sed 's/[[:space:]"\r]//g'
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

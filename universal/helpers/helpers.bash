# -------------------------------------------------------------------------------------------------------------
# Arrbit - helpers.bash
# Version: v1.1
# Purpose: Reusable helper functions for Arrbit scripts (flag reading, source guard, joinBy, etc)
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_HELPERS_INCLUDED:-}" ]]; then
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
          # Remove trailing inline comments (e.g., # or ; )
          gsub(/[#;].*$/, "", $2);
          print $2;
          exit
        }
      }
    ' "$config_file" 2>/dev/null | tr -d '"\r'
  }

  # -------------------------------------------------------
  # Source guard: prevent this file from being sourced more than once
  # Usage: .sourceGuard "$BASH_SOURCE"
  # -------------------------------------------------------
  .sourceGuard() {
    local guard_var="SOURCE_GUARD_$(echo "$1" | md5sum | awk '{print $1}')"
    [[ -n "${!guard_var:-}" ]] && return 1
    declare -g "$guard_var=1"
    return 0
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

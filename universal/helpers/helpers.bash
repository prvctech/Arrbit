# -------------------------------------------------------------------------------------------------------------
# Arrbit - helpers.bash
# Version: v1.1.1-gs2.8.3
# Purpose: Reusable helper functions for Arrbit scripts (config parsing, validation, file ops, etc)
# Dependencies: arrbit_paths.bash for auto-detection
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_HELPERS_INCLUDED:-}" ]]; then
  ARRBIT_HELPERS_INCLUDED=1

  # Source path detection helper if available
  if [[ -f "$(dirname "${BASH_SOURCE[0]}")/arrbit_paths.bash" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/arrbit_paths.bash"
  fi

  # -------------------------------------------------------
  # Safely get a flag value from the config file (case-insensitive, ignores comments/spaces)
  # Usage: getFlag "ENABLE_PLUGINS" || echo "Config missing or flag not found"
  # Returns: 0 + stdout if found, 1 if config missing or flag not found
  # -------------------------------------------------------
  getFlag() {
    local flag_name="$1"
    local config_dir
    config_dir=$(getArrbitConfigDir) || return 1
    local config_file="${CONFIG_DIR:-$config_dir}/arrbit-config.conf"
    
    # Return 1 silently if config missing - caller decides how to handle
    [[ -f "$config_file" ]] || return 1
    
    local flag_upper
    flag_upper=$(echo "$flag_name" | tr '[:lower:]' '[:upper:]')
    awk -F '=' -v key="$flag_upper" '
      $0 !~ /^[[:space:]]*#/ && NF >= 2 {
        # Remove whitespace in key
        gsub(/[[:space:]]+/, "", $1)
        if (toupper($1) == key) {
          val=$2
          # Remove inline comments after # or ;
          sub(/[#;].*/, "", val)
          # Trim leading/trailing whitespace
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
          # Remove leading/trailing double quotes
          gsub(/^"+|"+$/, "", val)
          print val
          exit
        }
      }
    ' "$config_file"
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

  # -------------------------------------------------------
  # Common utility functions for file operations, validation, etc.
  # -------------------------------------------------------

  # Check if a file/directory exists and is readable
  # Usage: isReadable "/path/to/file" && echo "exists"
  isReadable() { [[ -r "${1:-}" ]]; }
  
  # Check if a directory exists and is writable  
  # Usage: isWritableDir "/path/to/dir" && echo "can write"
  isWritableDir() { [[ -d "${1:-}" && -w "${1:-}" ]]; }
  
  # Validate URL format (basic check)
  # Usage: isValidUrl "https://example.com" && echo "valid"
  isValidUrl() {
    local url="${1:-}"
    [[ "$url" =~ ^https?://[^[:space:]]+$ ]]
  }
  
  # Safely create directory with parents
  # Usage: ensureDir "/path/to/dir" && echo "created/exists"
  ensureDir() {
    local dir="${1:-}"
    [[ -n "$dir" ]] && mkdir -p "$dir" 2>/dev/null
  }
  
  # Get file size in bytes (portable)
  # Usage: size=$(getFileSize "/path/to/file")
  getFileSize() {
    local file="${1:-}"
    [[ -f "$file" ]] && stat -c '%s' "$file" 2>/dev/null || echo "0"
  }
  
  # Check if command exists in PATH
  # Usage: hasCommand "jq" && echo "jq available"
  hasCommand() { command -v "${1:-}" >/dev/null 2>&1; }
  
  # Trim whitespace from string
  # Usage: trimmed=$(trimString "  hello world  ")
  trimString() {
    local str="${1:-}"
    str="${str#"${str%%[![:space:]]*}"}"   # remove leading whitespace
    str="${str%"${str##*[![:space:]]}"}"   # remove trailing whitespace
    echo "$str"
  }

fi

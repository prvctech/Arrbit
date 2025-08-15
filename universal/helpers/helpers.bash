# -------------------------------------------------------------------------------------------------------------
# Arrbit - helpers.bash
# Version: v2.0.0-gs3.0.0
# Purpose: Reusable helper functions for Arrbit scripts (config parsing, validation, file ops, etc)
# Change (gs3.0.0 migration): Auto-detection removed. Base path is now FIXED at /app/arrbit.
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_HELPERS_INCLUDED:-}" ]]; then
  ARRBIT_HELPERS_INCLUDED=1

  # ---------------------------------------------------------------------------------------------------------
  # Fixed base path (auto-detection deprecated): All Arrbit assets live under /app/arrbit
  # ---------------------------------------------------------------------------------------------------------
  ARRBIT_BASE="/app/arrbit"
  ARRBIT_CONFIG_DIR="${ARRBIT_BASE}/config"
  ARRBIT_DATA_DIR="${ARRBIT_BASE}/data"
  ARRBIT_LOGS_DIR="${ARRBIT_DATA_DIR}/logs"
  ARRBIT_HELPERS_DIR="${ARRBIT_BASE}/universal/helpers"
  ARRBIT_SCRIPTS_DIR="${ARRBIT_BASE}/scripts"
  ARRBIT_ENVIRONMENTS_DIR="${ARRBIT_BASE}/environments"

  # Ensure critical directories (best-effort; silent on failure)
  mkdir -p "${ARRBIT_CONFIG_DIR}" "${ARRBIT_LOGS_DIR}" "${ARRBIT_DATA_DIR}" 2>/dev/null || true

  # -------------------------------------------------------
  # Safely get a flag value from the config file (case-insensitive, ignores comments/spaces)
  # Usage: getFlag "ENABLE_PLUGINS" || echo "Config missing or flag not found"
  # Returns: 0 + stdout if found, 1 if config missing or flag not found
  # -------------------------------------------------------
  getFlag() {
    local flag_name="$1"
    local config_file="${ARRBIT_CONFIG_DIR}/arrbit-config.conf"
    
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
  # Returns 0 if the path exists and is readable, 1 otherwise
  isReadable() { [[ -n "${1:-}" && -e "${1:-}" && -r "${1:-}" ]]; }
  
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
  # Returns 0 if the directory exists (or was created), 1 on failure or bad input
  ensureDir() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
      return 1
    fi
    if [[ -d "$dir" ]]; then
      return 0
    fi
    mkdir -p -- "$dir" 2>/dev/null && [[ -d "$dir" ]]
  }
  
  # Get file size in bytes (portable)
  # Usage: size=$(getFileSize "/path/to/file")
  # Returns size on stdout and exit 0 if file exists; prints 0 and returns 1 otherwise
  getFileSize() {
    local file="${1:-}"
    if [[ -f "$file" ]]; then
      # Prefer GNU stat, fall back to BSD stat, then to wc -c
      if command -v stat >/dev/null 2>&1; then
        local size
        size=$(stat -c '%s' -- "$file" 2>/dev/null) || size=$(stat -f '%z' -- "$file" 2>/dev/null) || size=""
        if [[ -n "$size" ]]; then
          printf '%s' "$size"
          return 0
        fi
      fi
      # Final fallback
      local wcsize
      wcsize=$(wc -c < "$file" 2>/dev/null || echo 0)
      printf '%s' "${wcsize:-0}"
      return 0
    fi
    printf '0'
    return 1
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

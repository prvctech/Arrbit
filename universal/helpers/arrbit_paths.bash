# -------------------------------------------------------------------------------------------------------------
# Arrbit - arrbit_paths.bash
# Version: v1.0.0-gs2.8.3
# Purpose: Auto-detection and path management for Arrbit across different container environments
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_PATHS_INCLUDED:-}" ]]; then
  ARRBIT_PATHS_INCLUDED=1

  # -------------------------------------------------------
  # Auto-detect Arrbit base directory across different container environments
  # Usage: arrbit_base=$(detectArrbitBase)
  # Returns: Full path to arrbit directory or empty if not found
  # -------------------------------------------------------
  detectArrbitBase() {
    local search_paths=(
      "/app/arrbit"           # Tdarr
      "/config/arrbit"        # Most *Arr apps (Lidarr, Radarr, Sonarr, Bazarr)
      "/data/arrbit"          # Alternative data mount
      "/opt/arrbit"           # Alternative install location
      "$HOME/arrbit"          # User home fallback
    )
    
    for path in "${search_paths[@]}"; do
      if [[ -d "$path" ]]; then
        echo "$path"
        return 0
      fi
    done
    
    # If none found, try to find any arrbit directory recursively (limited depth for performance)
    local found_path
    found_path=$(find /app /config /data /opt 2>/dev/null -maxdepth 3 -type d -name "arrbit" | head -1)
    if [[ -n "$found_path" && -d "$found_path" ]]; then
      echo "$found_path"
      return 0
    fi
    
    return 1
  }

  # -------------------------------------------------------
  # Get the detected Arrbit base path (cached for performance)
  # Usage: base_path=$(getArrbitBase)
  # -------------------------------------------------------
  getArrbitBase() {
    if [[ -z "${ARRBIT_BASE_PATH:-}" ]]; then
      ARRBIT_BASE_PATH=$(detectArrbitBase)
      export ARRBIT_BASE_PATH
    fi
    echo "${ARRBIT_BASE_PATH:-}"
  }

  # -------------------------------------------------------
  # Arrbit-specific path helpers (auto-detecting base)
  # -------------------------------------------------------
  
  # Get Arrbit config directory
  # Usage: config_dir=$(getArrbitConfigDir)
  getArrbitConfigDir() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" ]] && echo "$base/config"
  }
  
  # Get Arrbit data directory  
  # Usage: data_dir=$(getArrbitDataDir)
  getArrbitDataDir() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" ]] && echo "$base/data"
  }
  
  # Get Arrbit logs directory
  # Usage: logs_dir=$(getArrbitLogsDir)  
  getArrbitLogsDir() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" ]] && echo "$base/data/logs"
  }
  
  # Get Arrbit helpers directory
  # Usage: helpers_dir=$(getArrbitHelpersDir)
  getArrbitHelpersDir() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" ]] && echo "$base/helpers"
  }

  # Get Arrbit scripts directory
  # Usage: scripts_dir=$(getArrbitScriptsDir)
  getArrbitScriptsDir() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" ]] && echo "$base/scripts"
  }

  # Get Arrbit environments directory
  # Usage: env_dir=$(getArrbitEnvironmentsDir)
  getArrbitEnvironmentsDir() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" ]] && echo "$base/environments"
  }
  
  # Check if Arrbit is properly installed/detected
  # Usage: isArrbitInstalled && echo "Arrbit found and ready"
  isArrbitInstalled() {
    local base
    base=$(getArrbitBase)
    [[ -n "$base" && -d "$base/helpers" && -d "$base/config" ]]
  }

  # Reset cached base path (useful for testing or if structure changes)
  # Usage: resetArrbitCache
  resetArrbitCache() {
    unset ARRBIT_BASE_PATH
  }

fi

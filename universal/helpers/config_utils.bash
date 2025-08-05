#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - config_utils.bash
# Version: v1.0-gs2.7.1
# Purpose: Configuration utilities for reading both traditional and YAML config formats
# -------------------------------------------------------------------------------------------------------------

# Source guard to prevent multiple inclusion
if [[ -z "${ARRBIT_CONFIG_UTILS_INCLUDED:-}" ]]; then
  ARRBIT_CONFIG_UTILS_INCLUDED=1

  # Default paths
  DEFAULT_CONF_PATH="/config/arrbit/config/arrbit-config.conf"
  DEFAULT_YAML_PATH="/config/arrbit/config/arrbit-config.yaml"
  
  # -------------------------------------------------------------------------------------------------------------
  # get_flag: Get a configuration value from the traditional config file (backward compatible)
  # Usage: get_flag "ENABLE_PLUGINS"
  # Returns: the value (e.g., true/false), or blank if not found
  # -------------------------------------------------------------------------------------------------------------
  get_flag() {
    local flag_name="$1"
    local config_file="${CONFIG_FILE:-$DEFAULT_CONF_PATH}"
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

  # -------------------------------------------------------------------------------------------------------------
  # yaml_installed: Check if YAML parsing tools are installed
  # Returns: 0 if installed, 1 if not
  # -------------------------------------------------------------------------------------------------------------
  yaml_installed() {
    if command -v yq >/dev/null 2>&1; then
      return 0
    elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # get_yaml_value: Get a configuration value from the YAML config file
  # Usage: get_yaml_value "plugins.enable"
  # Returns: the value, or blank if not found
  # -------------------------------------------------------------------------------------------------------------
  get_yaml_value() {
    local key_path="$1"
    local config_file="${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}"
    
    # Check if file exists
    if [[ ! -f "$config_file" ]]; then
      return 1
    fi
    
    # Try yq first (preferred for performance)
    if command -v yq >/dev/null 2>&1; then
      yq eval ".$key_path" "$config_file" 2>/dev/null || echo ""
      return
    fi
    
    # Fall back to Python if yq is not available
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "
import yaml, sys
try:
    with open('$config_file', 'r') as f:
        config = yaml.safe_load(f)
    
    keys = '$key_path'.split('.')
    value = config
    for key in keys:
        if isinstance(value, dict) and key in value:
            value = value[key]
        else:
            value = None
            break
    
    if value is not None:
        if isinstance(value, bool):
            print(str(value).lower())
        else:
            print(value)
except Exception:
    print('')
" 2>/dev/null || echo ""
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # get_config: Get a configuration value from either YAML or traditional config
  # Usage: get_config "plugins.enable" "ENABLE_PLUGINS"
  # Returns: the value from YAML if available, otherwise from traditional config
  # -------------------------------------------------------------------------------------------------------------
  get_config() {
    local yaml_key="$1"
    local conf_key="$2"
    local value=""
    
    # Try YAML first if installed and file exists
    if yaml_installed && [[ -f "${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}" ]]; then
      value=$(get_yaml_value "$yaml_key")
    fi
    
    # Fall back to traditional config if YAML value is empty
    if [[ -z "$value" ]]; then
      value=$(get_flag "$conf_key")
    fi
    
    echo "$value"
  }

  # -------------------------------------------------------------------------------------------------------------
  # config_exists: Check if either config file exists
  # Returns: 0 if at least one exists, 1 if neither exists
  # -------------------------------------------------------------------------------------------------------------
  config_exists() {
    if [[ -f "${CONFIG_FILE:-$DEFAULT_CONF_PATH}" ]] || [[ -f "${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}" ]]; then
      return 0
    else
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # detect_config_format: Detect which config format is being used
  # Returns: "yaml", "conf", or "both"
  # -------------------------------------------------------------------------------------------------------------
  detect_config_format() {
    local conf_exists=false
    local yaml_exists=false
    
    [[ -f "${CONFIG_FILE:-$DEFAULT_CONF_PATH}" ]] && conf_exists=true
    [[ -f "${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}" ]] && yaml_exists=true
    
    if $yaml_exists && $conf_exists; then
      echo "both"
    elif $yaml_exists; then
      echo "yaml"
    elif $conf_exists; then
      echo "conf"
    else
      echo "none"
    fi
  }

fi # End of source guard
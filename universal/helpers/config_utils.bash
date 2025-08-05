#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - config_utils.bash
# Version: v1.1-gs2.7.1
# Purpose: Configuration utilities for reading YAML config format with debugging
# -------------------------------------------------------------------------------------------------------------

# Source guard to prevent multiple inclusion
if [[ -z "${ARRBIT_CONFIG_UTILS_INCLUDED:-}" ]]; then
  ARRBIT_CONFIG_UTILS_INCLUDED=1

  # Default path
  DEFAULT_YAML_PATH="/config/arrbit/config/arrbit-config.yaml"
  
  # -------------------------------------------------------------------------------------------------------------
  # yaml_installed: Check if YAML parsing tools are installed
  # Returns: 0 if installed, 1 if not
  # -------------------------------------------------------------------------------------------------------------
  yaml_installed() {
    if command -v yq >/dev/null 2>&1; then
      echo "DEBUG: yq is installed" >> /config/logs/yaml_debug.log
      return 0
    elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
      echo "DEBUG: python3 with yaml module is installed" >> /config/logs/yaml_debug.log
      return 0
    else
      echo "DEBUG: No YAML parsing tools found" >> /config/logs/yaml_debug.log
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
      echo "DEBUG: Config file not found: $config_file" >> /config/logs/yaml_debug.log
      return 1
    fi
    
    echo "DEBUG: Reading $key_path from $config_file" >> /config/logs/yaml_debug.log
    
    # Try yq first (preferred for performance)
    if command -v yq >/dev/null 2>&1; then
      echo "DEBUG: Using yq to parse YAML" >> /config/logs/yaml_debug.log
      local result=$(yq eval ".$key_path" "$config_file" 2>/dev/null || echo "")
      echo "DEBUG: yq result for $key_path: '$result'" >> /config/logs/yaml_debug.log
      echo "$result"
      return
    fi
    
    # Fall back to Python if yq is not available
    if command -v python3 >/dev/null 2>&1; then
      echo "DEBUG: Using python3 to parse YAML" >> /config/logs/yaml_debug.log
      local result=$(python3 -c "
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
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    print('')
" 2>>/config/logs/yaml_debug.log || echo "")
      echo "DEBUG: python result for $key_path: '$result'" >> /config/logs/yaml_debug.log
      echo "$result"
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # config_exists: Check if config file exists
  # Returns: 0 if exists, 1 if not
  # -------------------------------------------------------------------------------------------------------------
  config_exists() {
    local config_file="${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}"
    if [[ -f "$config_file" ]]; then
      echo "DEBUG: Config file exists: $config_file" >> /config/logs/yaml_debug.log
      return 0
    else
      echo "DEBUG: Config file does not exist: $config_file" >> /config/logs/yaml_debug.log
      return 1
    fi
  }

fi

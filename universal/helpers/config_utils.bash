#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - simple_config_utils.bash
# Version: v1.0-gs2.7.1
# Purpose: Simple and reliable YAML configuration reader
# -------------------------------------------------------------------------------------------------------------

# Source guard to prevent multiple inclusion
if [[ -z "${ARRBIT_CONFIG_UTILS_INCLUDED:-}" ]]; then
  ARRBIT_CONFIG_UTILS_INCLUDED=1

  # Default path
  DEFAULT_YAML_PATH="/config/arrbit/config/arrbit-config.yaml"
  
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
      echo ""
      return 1
    fi
    
    # Use yq from /usr/local/bin
    if [[ -x "/usr/local/bin/yq" ]]; then
      /usr/local/bin/yq eval ".$key_path" "$config_file" 2>/dev/null || echo ""
      return
    fi
    
    # Fall back to system yq if available
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
  # config_exists: Check if config file exists
  # Returns: 0 if exists, 1 if not
  # -------------------------------------------------------------------------------------------------------------
  config_exists() {
    if [[ -f "${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}" ]]; then
      return 0
    else
      return 1
    fi
  }

fi # End of source guard

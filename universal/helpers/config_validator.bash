#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - config_validator.bash
# Version: v1.0-gs2.7.1
# Purpose: Configuration validation for Arrbit (Golden Standard v2.7.1 compliant)
# -------------------------------------------------------------------------------------------------------------

# Source guard to prevent multiple inclusion
if [[ -z "${ARRBIT_CONFIG_VALIDATOR_INCLUDED:-}" ]]; then
  ARRBIT_CONFIG_VALIDATOR_INCLUDED=1

  # Source required files if not already sourced
  if [[ -z "${ARRBIT_CONFIG_UTILS_INCLUDED:-}" ]]; then
    source /config/arrbit/helpers/config_utils.bash
  fi
  
  if [[ -z "${ARRBIT_HELPERS_INCLUDED:-}" ]]; then
    source /config/arrbit/helpers/helpers.bash
  fi
  
  if [[ -z "${ARRBIT_LOGGING_UTILS_INCLUDED:-}" ]]; then
    source /config/arrbit/helpers/logging_utils.bash
  fi

  # -------------------------------------------------------------------------------------------------------------
  # validate_boolean: Validate that a value is a boolean (true/false)
  # Usage: validate_boolean "enable_plugins" "$value"
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_boolean() {
    local key="$1"
    local value="${2,,}" # Convert to lowercase
    
    if [[ "$value" == "true" || "$value" == "false" ]]; then
      return 0
    else
      log_error "Invalid boolean value for $key: '$value' (must be 'true' or 'false') (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Invalid boolean value for $key: '$value'
[WHY]: Configuration value must be a boolean (true/false)
[FIX]: Update the configuration to use either 'true' or 'false' for this setting
EOF
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_path: Validate that a path exists
  # Usage: validate_path "beets_config_path" "$value" [optional]
  # Returns: 0 if valid or optional and empty, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_path() {
    local key="$1"
    local value="$2"
    local optional="${3:-false}"
    
    # If optional and empty, it's valid
    if [[ "$optional" == "true" && -z "$value" ]]; then
      return 0
    fi
    
    if [[ -e "$value" ]]; then
      return 0
    else
      log_error "Invalid path for $key: '$value' (path does not exist) (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Invalid path for $key: '$value'
[WHY]: The specified path does not exist
[FIX]: Create the directory/file or update the configuration with a valid path
EOF
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_enum: Validate that a value is one of the allowed options
  # Usage: validate_enum "video_format" "$value" "mp4 mkv avi"
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_enum() {
    local key="$1"
    local value="${2,,}" # Convert to lowercase
    local allowed="$3"
    
    if [[ "$allowed" == *"$value"* ]]; then
      return 0
    else
      log_error "Invalid value for $key: '$value' (must be one of: $allowed) (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Invalid value for $key: '$value'
[WHY]: The value must be one of the allowed options: $allowed
[FIX]: Update the configuration to use one of the allowed values
EOF
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_dependencies: Validate that required dependencies are installed
  # Usage: validate_dependencies
  # Returns: 0 if all dependencies are installed, 1 if any are missing
  # -------------------------------------------------------------------------------------------------------------
  validate_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in curl jq grep awk sed; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_deps+=("$cmd")
      fi
    done
    
    # Check for YAML support
    if ! yaml_installed; then
      missing_deps+=("yq or python3-yaml")
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
      local deps_list=$(printf ", %s" "${missing_deps[@]}")
      deps_list=${deps_list:2} # Remove leading ", "
      
      log_error "Missing required dependencies: $deps_list (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Missing required dependencies: $deps_list
[WHY]: These tools are required for Arrbit to function properly
[FIX]: Install the missing dependencies using your package manager
EOF
      return 1
    fi
    
    return 0
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_config: Validate the entire configuration
  # Usage: validate_config
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_config() {
    local valid=true
    
    # Check if config exists
    if ! config_exists; then
      log_error "No configuration file found (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR No configuration file found
[WHY]: arrbit-config.yaml does not exist
[FIX]: Create a configuration file in /config/arrbit/config/
EOF
      return 1
    fi
    
    # Validate dependencies
    validate_dependencies || valid=false
    
    # Core settings
    local enable_arrbit=$(get_yaml_value "enable_arrbit")
    validate_boolean "enable_arrbit" "$enable_arrbit" || valid=false
    
    # Plugin settings
    local enable_plugins=$(get_yaml_value "plugins.enable")
    validate_boolean "plugins.enable" "$enable_plugins" || valid=false
    
    # Plugin installation settings
    local install_deezer=$(get_yaml_value "plugins.install.deezer")
    validate_boolean "plugins.install.deezer" "$install_deezer" || valid=false
    
    local install_tidal=$(get_yaml_value "plugins.install.tidal")
    validate_boolean "plugins.install.tidal" "$install_tidal" || valid=false
    
    local install_tubifarry=$(get_yaml_value "plugins.install.tubifarry")
    validate_boolean "plugins.install.tubifarry" "$install_tubifarry" || valid=false
    
    # Premium settings
    local enable_premium=$(get_yaml_value "plugins.premium.enable")
    validate_boolean "plugins.premium.enable" "$enable_premium" || valid=false
    
    # Autoconfig settings
    local enable_autoconfig=$(get_yaml_value "autoconfig.enable")
    validate_boolean "autoconfig.enable" "$enable_autoconfig" || valid=false
    
    # Beets config path (optional)
    local beets_config=$(get_yaml_value "beets_config_path")
    if [[ -n "$beets_config" ]]; then
      validate_path "beets_config_path" "$beets_config" "true" || valid=false
    fi
    
    # Video settings (if present)
    local enable_videos=$(get_yaml_value "videos.enable")
    if [[ -n "$enable_videos" ]]; then
      validate_boolean "videos.enable" "$enable_videos" || valid=false
      
      local video_format=$(get_yaml_value "videos.format")
      if [[ -n "$video_format" ]]; then
        validate_enum "videos.format" "$video_format" "mkv mp4 avi webm" || valid=false
      fi
      
      local deduplicate=$(get_yaml_value "videos.deduplicate")
      if [[ -n "$deduplicate" ]]; then
        validate_boolean "videos.deduplicate" "$deduplicate" || valid=false
      fi
    fi
    
    # Check for configuration conflicts - Fixed the syntax error here
    if [[ "$enable_plugins" == "true" ]]; then
      # Check if no plugins are selected
      if [[ "$install_deezer" != "true" ]]; then
        if [[ "$install_tidal" != "true" ]]; then
          if [[ "$install_tubifarry" != "true" ]]; then
            log_warning "Plugins are enabled but no specific plugins are selected for installation"
          fi
        fi
      fi
    fi
    
    if [[ "$valid" == "true" ]]; then
      return 0
    else
      return 1
    fi
  }

fi # End of source guard

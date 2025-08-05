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
    
    # Check for YAML support if YAML config is used
    if [[ "$(detect_config_format)" == "yaml" || "$(detect_config_format)" == "both" ]]; then
      if ! yaml_installed; then
        missing_deps+=("yq or python3-yaml")
      fi
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
    local format=$(detect_config_format)
    local valid=true
    
    # Check if any config exists
    if [[ "$format" == "none" ]]; then
      log_error "No configuration file found (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR No configuration file found
[WHY]: Neither arrbit-config.conf nor arrbit-config.yaml exists
[FIX]: Create a configuration file in /config/arrbit/config/
EOF
      return 1
    fi
    
    # Validate dependencies
    validate_dependencies || valid=false
    
    # Core settings
    if [[ "$format" == "yaml" || "$format" == "both" ]]; then
      # YAML validation
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
      
    else
      # Traditional config validation
      local enable_arrbit=$(get_flag "ENABLE_ARRBIT")
      validate_boolean "ENABLE_ARRBIT" "$enable_arrbit" || valid=false
      
      local enable_plugins=$(get_flag "ENABLE_PLUGINS")
      validate_boolean "ENABLE_PLUGINS" "$enable_plugins" || valid=false
      
      local install_deezer=$(get_flag "INSTALL_PLUGIN_DEEZER")
      validate_boolean "INSTALL_PLUGIN_DEEZER" "$install_deezer" || valid=false
      
      local install_tidal=$(get_flag "INSTALL_PLUGIN_TIDAL")
      validate_boolean "INSTALL_PLUGIN_TIDAL" "$install_tidal" || valid=false
      
      local install_tubifarry=$(get_flag "INSTALL_PLUGIN_TUBIFARRY")
      validate_boolean "INSTALL_PLUGIN_TUBIFARRY" "$install_tubifarry" || valid=false
      
      local enable_premium=$(get_flag "ENBALE_PREMIUM")
      if [[ -n "$enable_premium" ]]; then
        validate_boolean "ENBALE_PREMIUM" "$enable_premium" || valid=false
      fi
      
      local enable_autoconfig=$(get_flag "ENABLE_AUTOCONFIG")
      validate_boolean "ENABLE_AUTOCONFIG" "$enable_autoconfig" || valid=false
      
      # Beets config path (optional)
      local beets_config=$(get_flag "BEETS_CONFIG_PATH")
      if [[ -n "$beets_config" ]]; then
        validate_path "BEETS_CONFIG_PATH" "$beets_config" "true" || valid=false
      fi
    fi
    
    # Check for configuration conflicts
    if [[ "$enable_plugins" == "true" ]]; then
      if [[ "$install_deezer" != "true" && "$install_tidal" != "true" && "$install_tubifarry" != "true" ]]; then
        log_warning "Plugins are enabled but no specific plugins are selected for installation"
      fi
    fi
    
    if [[ "$valid" == "true" ]]; then
      return 0
    else
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # config_to_yaml: Convert traditional config to YAML format
  # Usage: config_to_yaml "/path/to/input.conf" "/path/to/output.yaml"
  # Returns: 0 if successful, 1 if failed
  # -------------------------------------------------------------------------------------------------------------
  config_to_yaml() {
    local input_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$input_file" ]]; then
      log_error "Input file not found: $input_file (see log at /config/logs)"
      cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Input file not found: $input_file
[WHY]: The specified configuration file does not exist
[FIX]: Provide a valid path to an existing configuration file
EOF
      return 1
    fi
    
    # Create a temporary file for the YAML content
    local temp_file=$(mktemp)
    
    # Start with the header
    cat > "$temp_file" << EOF
# Arrbit Main Configuration
# Converted from $(basename "$input_file") on $(date)

EOF
    
    # Process the configuration file
    local section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines and comments
      if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        echo "$line" >> "$temp_file"
        continue
      fi
      
      # Detect section headers
      if [[ "$line" =~ ^#{2,}[[:space:]]*(.*)[[:space:]]*#{2,}$ ]]; then
        section="${BASH_REMATCH[1],,}"
        section="${section// /_}"
        echo "" >> "$temp_file"
        echo "# ${BASH_REMATCH[1]}" >> "$temp_file"
        continue
      fi
      
      # Process key-value pairs
      if [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*&quot;?([^&quot;#]*)&quot;?([[:space:]]*#.*)?$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        local comment="${BASH_REMATCH[3]}"
        
        # Remove trailing whitespace from value
        value="${value%"${value##*[![:space:]]}"}"
        
        # Convert key to lowercase
        key="${key,,}"
        
        # Handle special cases for nested structure
        case "$key" in
          enable_arrbit)
            echo "enable_arrbit: $value$comment" >> "$temp_file"
            ;;
          enable_plugins)
            echo "plugins:" >> "$temp_file"
            echo "  enable: $value$comment" >> "$temp_file"
            ;;
          install_plugin_*)
            local plugin="${key#install_plugin_}"
            if ! grep -q "  install:" "$temp_file"; then
              echo "  install:" >> "$temp_file"
            fi
            echo "    $plugin: $value$comment" >> "$temp_file"
            ;;
          enbale_premium)
            echo "  premium:" >> "$temp_file"
            echo "    enable: $value$comment" >> "$temp_file"
            ;;
          premium_*)
            local service="${key#premium_}"
            if ! grep -q "  premium:" "$temp_file"; then
              echo "  premium:" >> "$temp_file"
            fi
            echo "    $service: $value$comment" >> "$temp_file"
            ;;
          enable_autoconfig)
            echo "autoconfig:" >> "$temp_file"
            echo "  enable: $value$comment" >> "$temp_file"
            ;;
          configure_*)
            local module="${key#configure_}"
            if ! grep -q "  modules:" "$temp_file"; then
              echo "  modules:" >> "$temp_file"
            fi
            echo "    $module: $value$comment" >> "$temp_file"
            ;;
          beets_config_path)
            echo "beets_config_path: $value$comment" >> "$temp_file"
            ;;
          *)
            # Default case - just output as is
            echo "$key: $value$comment" >> "$temp_file"
            ;;
        esac
      fi
    done < "$input_file"
    
    # Add new video section
    cat >> "$temp_file" << EOF

# Video Download Settings (New section)
videos:
  enable: false                # Master ON/OFF switch for video downloads
  format: "mkv"                # Preferred video format
  quality: "best"              # Video quality (best, 1080p, 720p, etc.)
  deduplicate: true            # Enable deduplication of videos
  sources:
    tidal: true                # Use Tidal as source (requires premium)
    youtube: true              # Use YouTube as fallback source
    vimeo: false               # Use Vimeo as source
EOF
    
    # Move the temp file to the output location
    mv "$temp_file" "$output_file"
    chmod 777 "$output_file"
    
    log_info "Configuration converted to YAML format: $output_file"
    return 0
  }

fi # End of source guard
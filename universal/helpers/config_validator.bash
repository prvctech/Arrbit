#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - enhanced_config_validator.bash
# Version: v1.1-gs2.7.1
# Purpose: Comprehensive YAML configuration validator using schema definitions
# -------------------------------------------------------------------------------------------------------------

# Source guard to prevent multiple inclusion
if [[ -z "${ARRBIT_CONFIG_VALIDATOR_INCLUDED:-}" ]]; then
  ARRBIT_CONFIG_VALIDATOR_INCLUDED=1

  # Default paths
  DEFAULT_YAML_PATH="/config/arrbit/config/arrbit-config.yaml"
  DEFAULT_SCHEMA_PATH="/config/arrbit/config/config_schema.yaml"
  
  # Source config_utils if not already included
  if [[ -z "${ARRBIT_CONFIG_UTILS_INCLUDED:-}" ]]; then
    if [[ -f "/config/arrbit/helpers/config_utils.bash" ]]; then
      source "/config/arrbit/helpers/config_utils.bash"
    else
      echo "[Arrbit] ERROR: config_utils.bash not found. Validator requires config_utils.bash."
      return 1
    fi
  fi
  
  # -------------------------------------------------------------------------------------------------------------
  # validate_config: Validate the entire configuration file against schema
  # Usage: validate_config [config_file] [schema_file]
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_config() {
    local config_file="${1:-${YAML_CONFIG_FILE:-$DEFAULT_YAML_PATH}}"
    local schema_file="${2:-${YAML_SCHEMA_FILE:-$DEFAULT_SCHEMA_PATH}}"
    
    # Check if files exist
    if [[ ! -f "$config_file" ]]; then
      log_error "Configuration file not found: $config_file"
      return 1
    fi
    
    if [[ ! -f "$schema_file" ]]; then
      log_error "Schema file not found: $schema_file"
      return 1
    fi
    
    # Check if Python is available for validation
    if ! command -v python3 >/dev/null 2>&1; then
      log_error "Python3 is required for configuration validation"
      return 1
    fi
    
    # Validate using Python and PyYAML
    python3 -c "
import yaml, sys, re
from pathlib import Path

def log_error(message):
    print(f'[Arrbit] \033[91mERROR:\033[0m {message}')

def log_warning(message):
    print(f'[Arrbit] \033[93mWARNING:\033[0m {message}')

def log_info(message):
    print(f'[Arrbit] {message}')

try:
    # Load schema and config
    with open('$schema_file', 'r') as f:
        schema = yaml.safe_load(f)
    
    with open('$config_file', 'r') as f:
        config = yaml.safe_load(f)
    
    if not config:
        log_error('Configuration file is empty or invalid YAML')
        sys.exit(1)
    
    if not schema:
        log_error('Schema file is empty or invalid YAML')
        sys.exit(1)
    
    # Track validation errors
    errors = []
    warnings = []
    
    # Validate schema version
    schema_version = schema.get('schema_version')
    if not schema_version:
        warnings.append('Schema version not specified in schema file')
    
    # Helper function to validate a property against its schema definition
    def validate_property(property_path, value, schema_def):
        prop_type = schema_def.get('type')
        required = schema_def.get('required', False)
        
        # Check if required property is missing
        if required and value is None:
            errors.append(f'Required property {property_path} is missing')
            return False
        
        # Skip validation for optional properties that are not present
        if value is None:
            return True
        
        # Type validation
        if prop_type == 'boolean':
            if not isinstance(value, bool):
                errors.append(f'Property {property_path} must be a boolean, got {type(value).__name__}')
                return False
        elif prop_type == 'string':
            if not isinstance(value, str):
                errors.append(f'Property {property_path} must be a string, got {type(value).__name__}')
                return False
            
            # Enum validation
            if 'enum' in schema_def and value not in schema_def['enum']:
                errors.append(f'Property {property_path} must be one of {schema_def[&quot;enum&quot;]}, got {value}')
                return False
        elif prop_type == 'number':
            if not isinstance(value, (int, float)):
                errors.append(f'Property {property_path} must be a number, got {type(value).__name__}')
                return False
            
            # Range validation
            if 'minimum' in schema_def and value < schema_def['minimum']:
                errors.append(f'Property {property_path} must be >= {schema_def[&quot;minimum&quot;]}, got {value}')
                return False
            if 'maximum' in schema_def and value > schema_def['maximum']:
                errors.append(f'Property {property_path} must be <= {schema_def[&quot;maximum&quot;]}, got {value}')
                return False
        elif prop_type == 'object':
            if not isinstance(value, dict):
                errors.append(f'Property {property_path} must be an object, got {type(value).__name__}')
                return False
            
            # Validate object properties
            if 'properties' in schema_def:
                for prop_name, prop_schema in schema_def['properties'].items():
                    prop_value = value.get(prop_name)
                    validate_property(f'{property_path}.{prop_name}', prop_value, prop_schema)
            
            # Check for unknown properties
            if 'properties' in schema_def:
                known_props = set(schema_def['properties'].keys())
                actual_props = set(value.keys())
                unknown_props = actual_props - known_props
                if unknown_props:
                    for prop in unknown_props:
                        warnings.append(f'Unknown property {property_path}.{prop} not defined in schema')
        elif prop_type == 'array':
            if not isinstance(value, list):
                errors.append(f'Property {property_path} must be an array, got {type(value).__name__}')
                return False
            
            # Validate array items
            if 'items' in schema_def and value:
                item_schema = schema_def['items']
                for i, item in enumerate(value):
                    validate_property(f'{property_path}[{i}]', item, item_schema)
        
        return True
    
    # Start validation from root properties
    root_schema = schema.get('properties', {})
    for prop_name, prop_schema in root_schema.items():
        prop_value = config.get(prop_name)
        validate_property(prop_name, prop_value, prop_schema)
    
    # Check for unknown root properties
    known_root_props = set(root_schema.keys())
    actual_root_props = set(config.keys())
    unknown_root_props = actual_root_props - known_root_props
    if unknown_root_props:
        for prop in unknown_root_props:
            warnings.append(f'Unknown root property {prop} not defined in schema')
    
    # Report validation results
    if errors:
        log_error(f'Configuration validation failed with {len(errors)} errors:')
        for error in errors:
            log_error(f'  - {error}')
        sys.exit(1)
    
    if warnings:
        log_warning(f'Configuration validated with {len(warnings)} warnings:')
        for warning in warnings:
            log_warning(f'  - {warning}')
    else:
        log_info('Configuration validated successfully')
    
    sys.exit(0)
except Exception as e:
    log_error(f'Validation error: {str(e)}')
    sys.exit(1)
" || return 1

    return 0
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_boolean: Validate a boolean configuration value
  # Usage: validate_boolean "key.path" "value"
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_boolean() {
    local key_path="$1"
    local value="$2"
    
    # Convert to lowercase for string comparison
    local value_lower="${value,,}"
    
    if [[ "$value_lower" == "true" || "$value_lower" == "false" ]]; then
      return 0
    else
      log_error "Invalid boolean value for $key_path: '$value'. Must be 'true' or 'false'."
      cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Invalid boolean value for $key_path
[WHY]: The value '$value' is not a valid boolean.
[FIX]: Use 'true' or 'false' (case insensitive) for boolean configuration values.
EOF
      return 1
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_enum: Validate a value against a list of allowed values
  # Usage: validate_enum "key.path" "value" "value1 value2 value3"
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_enum() {
    local key_path="$1"
    local value="$2"
    local allowed_values="$3"
    
    # Check if value is in the allowed values list
    for allowed in $allowed_values; do
      if [[ "$value" == "$allowed" ]]; then
        return 0
      fi
    done
    
    log_error "Invalid value for $key_path: '$value'. Must be one of: $allowed_values."
    cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Invalid value for $key_path
[WHY]: The value '$value' is not in the allowed list.
[FIX]: Use one of the following values: $allowed_values
EOF
    return 1
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_number: Validate a numeric value with optional min/max
  # Usage: validate_number "key.path" "value" [min] [max]
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_number() {
    local key_path="$1"
    local value="$2"
    local min="${3:-}"
    local max="${4:-}"
    
    # Check if value is a number
    if ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      log_error "Invalid number for $key_path: '$value'. Must be a numeric value."
      cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Invalid number for $key_path
[WHY]: The value '$value' is not a valid number.
[FIX]: Use a numeric value (integer or decimal).
EOF
      return 1
    fi
    
    # Check minimum if specified
    if [[ -n "$min" ]] && (( $(echo "$value < $min" | bc -l) )); then
      log_error "Value for $key_path is too small: '$value'. Minimum allowed is $min."
      cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Value for $key_path is too small
[WHY]: The value '$value' is less than the minimum allowed value of $min.
[FIX]: Use a value greater than or equal to $min.
EOF
      return 1
    fi
    
    # Check maximum if specified
    if [[ -n "$max" ]] && (( $(echo "$value > $max" | bc -l) )); then
      log_error "Value for $key_path is too large: '$value'. Maximum allowed is $max."
      cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Value for $key_path is too large
[WHY]: The value '$value' is greater than the maximum allowed value of $max.
[FIX]: Use a value less than or equal to $max.
EOF
      return 1
    fi
    
    return 0
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_string: Validate a string value with optional pattern
  # Usage: validate_string "key.path" "value" [pattern]
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_string() {
    local key_path="$1"
    local value="$2"
    local pattern="${3:-}"
    
    # Check if value is empty
    if [[ -z "$value" ]]; then
      log_warning "Empty string for $key_path."
      return 0
    fi
    
    # Check pattern if specified
    if [[ -n "$pattern" ]] && ! [[ "$value" =~ $pattern ]]; then
      log_error "Invalid format for $key_path: '$value'. Must match pattern: $pattern."
      cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Invalid format for $key_path
[WHY]: The value '$value' does not match the required pattern.
[FIX]: Ensure the value matches the pattern: $pattern
EOF
      return 1
    fi
    
    return 0
  }

  # -------------------------------------------------------------------------------------------------------------
  # validate_path: Validate a file or directory path
  # Usage: validate_path "key.path" "value" [type] [must_exist]
  # type: "file" or "dir" (default: any)
  # must_exist: "true" or "false" (default: false)
  # Returns: 0 if valid, 1 if invalid
  # -------------------------------------------------------------------------------------------------------------
  validate_path() {
    local key_path="$1"
    local value="$2"
    local type="${3:-}"
    local must_exist="${4:-false}"
    
    # Check if path is empty
    if [[ -z "$value" ]]; then
      log_warning "Empty path for $key_path."
      return 0
    fi
    
    # Check if path must exist
    if [[ "${must_exist,,}" == "true" ]]; then
      if [[ ! -e "$value" ]]; then
        log_error "Path for $key_path does not exist: '$value'."
        cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Path for $key_path does not exist
[WHY]: The path '$value' was not found on the system.
[FIX]: Provide a valid path that exists on the system.
EOF
        return 1
      fi
      
      # Check path type if specified
      if [[ "$type" == "file" && ! -f "$value" ]]; then
        log_error "Path for $key_path is not a file: '$value'."
        cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Path for $key_path is not a file
[WHY]: The path '$value' exists but is not a regular file.
[FIX]: Provide a path to a valid file.
EOF
        return 1
      elif [[ "$type" == "dir" && ! -d "$value" ]]; then
        log_error "Path for $key_path is not a directory: '$value'."
        cat <<EOF | arrbitLogClean >> "${LOG_FILE:-/dev/null}"
[Arrbit] ERROR Path for $key_path is not a directory
[WHY]: The path '$value' exists but is not a directory.
[FIX]: Provide a path to a valid directory.
EOF
        return 1
      fi
    fi
    
    return 0
  }

fi # End of source guard

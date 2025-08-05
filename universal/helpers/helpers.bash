# -------------------------------------------------------------------------------------------------------------
# Arrbit - helpers.bash
# Version: v2.0-gs2.7.1
# Purpose: Reusable helper functions for Arrbit scripts (YAML config reading, source guard, joinBy, etc)
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_HELPERS_INCLUDED:-}" ]]; then
  ARRBIT_HELPERS_INCLUDED=1

  # -------------------------------------------------------
  # Safely get a value from the YAML config file
  # Usage: getFlag "enable_plugins" (for backward compatibility)
  # Returns: the value (e.g., true/false), or blank if not found
  # -------------------------------------------------------
  getFlag() {
    local flag_name="$1"
    local yaml_key
    
    # Convert traditional flag names to YAML paths
    case "${flag_name,,}" in
      enable_arrbit)
        yaml_key="enable_arrbit"
        ;;
      enable_plugins)
        yaml_key="plugins.enable"
        ;;
      install_plugin_deezer)
        yaml_key="plugins.install.deezer"
        ;;
      install_plugin_tidal)
        yaml_key="plugins.install.tidal"
        ;;
      install_plugin_tubifarry)
        yaml_key="plugins.install.tubifarry"
        ;;
      enbale_premium)
        yaml_key="plugins.premium.enable"
        ;;
      premium_tidal)
        yaml_key="plugins.premium.tidal"
        ;;
      premium_deezer)
        yaml_key="plugins.premium.deezer"
        ;;
      enable_autoconfig)
        yaml_key="autoconfig.enable"
        ;;
      configure_*)
        module="${flag_name#configure_}"
        module="${module,,}"
        yaml_key="autoconfig.modules.$module"
        ;;
      beets_config_path)
        yaml_key="beets_config_path"
        ;;
      *)
        # Default case - use lowercase flag name
        yaml_key="${flag_name,,}"
        ;;
    esac
    
    # Source config_utils.bash if available
    if [[ -f "/config/arrbit/helpers/config_utils.bash" ]]; then
      source "/config/arrbit/helpers/config_utils.bash"
      get_yaml_value "$yaml_key"
    else
      # Fallback to traditional config if config_utils.bash is not available
      local config_file="${CONFIG_DIR:-/config/arrbit/config}/arrbit-config.conf"
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
    fi
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

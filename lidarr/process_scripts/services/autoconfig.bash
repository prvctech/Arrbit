#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - autoconfig.bash
# Version: v2.0-gs2.7.1
# Purpose: Orchestrates Arrbit modules based on config flags in arrbit-config.yaml (Golden Standard enforced)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/config_utils.bash

arrbitPurgeOldLogs

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v2.0-gs2.7.1"
ARRBIT_ROOT="/config/arrbit"
MODULES_DIR="$ARRBIT_ROOT/modules"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner 
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION} ..."
echo -e "${CYAN}[Arrbit]${NC} Initializing modules..."

# --- 1. Check YAML configuration exists ---
if ! config_exists; then
  log_error "Configuration file missing: arrbit-config.yaml (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Configuration file missing
[WHY]: arrbit-config.yaml not found in /config/arrbit/config/
[FIX]: Create a configuration file based on the example in the repository
EOF
  exit 1
fi

# --- 2. Check ENABLE_AUTOCONFIG flag first, fail fast with warning if not true ---
ENABLE_AUTOCONFIG=$(get_yaml_value "autoconfig.enable")

# Validate if validator is available
if type validate_boolean >/dev/null 2>&1; then
  if ! validate_boolean "autoconfig.enable" "$ENABLE_AUTOCONFIG"; then
    ENABLE_AUTOCONFIG="false"
  fi
fi

if [[ "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  log_warning "Autoconfig service is OFF. Set autoconfig.enable to 'true' in arrbit-config.yaml."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# --- 3. MODULES LIST (Add/remove modules here as required) ---
MODULES=(
  custom_formats
  custom_scripts  
  media_management
  metadata_consumer
  metadata_plugin
  metadata_profiles
  metadata_write
  quality_definitions
  quality_profiles
  track_naming
  ui_settings
)

# --- 4. CHECK IF ANY MODULES ARE ENABLED (error if all are disabled) ---
ENABLED_COUNT=0
for NAME in "${MODULES[@]}"; do
  # Convert module name to YAML path: custom_formats -> autoconfig.modules.custom_formats
  YAML_PATH="autoconfig.modules.${NAME}"
  VAL=$(get_yaml_value "$YAML_PATH")
  
  # Validate if validator is available
  if type validate_boolean >/dev/null 2>&1; then
    if ! validate_boolean "$YAML_PATH" "$VAL"; then
      VAL="false"
    fi
  fi
  
  if [[ -n "${VAL}" && "${VAL,,}" == "true" ]]; then
    ((ENABLED_COUNT++))
  fi
done

if (( ENABLED_COUNT == 0 )); then
  log_error "Autoconfig stopped: no modules enabled in autoconfig.modules. Update your configuration."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# --- 5. RUN ENABLED MODULES ONLY (no internal flag logic in modules) ---
for NAME in "${MODULES[@]}"; do
  # Convert module name to YAML path: custom_formats -> autoconfig.modules.custom_formats
  YAML_PATH="autoconfig.modules.${NAME}"
  VAL=$(get_yaml_value "$YAML_PATH")
  
  # Validate if validator is available
  if type validate_boolean >/dev/null 2>&1; then
    if ! validate_boolean "$YAML_PATH" "$VAL"; then
      VAL="false"
    fi
  fi
  
  if [[ -z "${VAL}" || "${VAL,,}" != "true" ]]; then
    log_warning "${NAME} module is disabled by config; skipping."
    continue
  fi

  SCRIPT="$MODULES_DIR/${NAME}.bash"
  if [ -x "$SCRIPT" ]; then
    if ! bash "$SCRIPT"; then
      log_warning "${NAME} module failed. See log for details."
    fi
  else
    log_warning "${NAME} module not found or not executable; skipped."
  fi
done

# --- 6. WRAP UP ---
log_info "Log saved to $LOG_FILE"
log_info "Done with ${SCRIPT_NAME} service"

exit 0

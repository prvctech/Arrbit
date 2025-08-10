#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - autoconfig.bash
# Version: v1.0-gs2.7
# Purpose: Orchestrates Arrbit modules based on config flags in arrbit-config.conf (Golden Standard enforced)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v1.0-gs2.7"
ARRBIT_ROOT="/config/arrbit"
CONFIG_FILE="$ARRBIT_ROOT/config/arrbit-config.conf"
MODULES_DIR="$ARRBIT_ROOT/modules"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner 
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION} ..."
echo -e "${CYAN}[Arrbit]${NC} Initializing modules..."

# --- 1. Check ENABLE_AUTOCONFIG flag first, fail fast with warning if not true ---
ENABLE_AUTOCONFIG=$(getFlag ENABLE_AUTOCONFIG)
if [[ "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  log_warning "Autoconfig service is OFF. Update ENABLE_AUTOCONFIG to 'true' in arrbit-config.conf."
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
  quality_definitions    # new
  quality_profiles
  track_naming
  ui_settings
)

# --- 4. CHECK IF ANY MODULES ARE ENABLED (error if all are disabled) ---
ENABLED_COUNT=0
for NAME in "${MODULES[@]}"; do
  FLAG="CONFIGURE_$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
  VAL=$(getFlag "$FLAG")
  if [[ -n "${VAL}" && "${VAL,,}" == "true" ]]; then
    ((ENABLED_COUNT++))
  fi
done
if (( ENABLED_COUNT == 0 )); then
  log_error "Autoconfig stopped: no CONFIGURE_* modules enabled. Update your configuration."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# --- 5. RUN ENABLED MODULES ONLY (no internal flag logic in modules) ---
for NAME in "${MODULES[@]}"; do
  FLAG="CONFIGURE_$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
  VAL=$(getFlag "$FLAG")
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
#log_info "Log saved to $LOG_FILE"
#log_info "Done with ${SCRIPT_NAME} service"

exit 0

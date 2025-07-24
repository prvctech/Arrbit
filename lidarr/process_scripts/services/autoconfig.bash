#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - autoconfig.bash
# Version: v5.2-gs2.6
# Purpose: Orchestrates Arrbit modules based on config flags in arrbit-config.conf (Golden Standard enforced)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v5.2-gs2.6"
ARRBIT_ROOT="/config/arrbit"
CONFIG_FILE="$ARRBIT_ROOT/config/arrbit-config.conf"
MODULES_DIR="$ARRBIT_ROOT/modules"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Banner (only first line with color is allowed)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION} ..."
echo

# ----------------------------------------------------------------------------
# 1. CONNECT TO ARRBRIDGE (exports arr_api)
# ----------------------------------------------------------------------------
if ! source "$ARRBIT_ROOT/connectors/arr_bridge.bash"; then
  log_error "arr_bridge.bash not found or failed; exiting."
  exit 1
fi

# ----------------------------------------------------------------------------
# 2. MODULES LIST (Add/remove modules here as required)
# ----------------------------------------------------------------------------
MODULES=(
  custom_formats
  custom_scripts
  delay_profiles
  media_management
  metadata_consumer
  metadata_plugin
  metadata_profiles
  metadata_write
  quality_profiles
  track_naming
  ui_settings
)

# ----------------------------------------------------------------------------
# 3. CHECK IF ANY MODULES ARE ENABLED (fail early if none enabled)
# ----------------------------------------------------------------------------
ENABLED_COUNT=0
for NAME in "${MODULES[@]}"; do
  FLAG="CONFIGURE_$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
  VAL=$(getFlag "$FLAG")
  if [[ -n "${VAL}" && "${VAL,,}" == "true" ]]; then
    ((ENABLED_COUNT++))
  fi
done
if (( ENABLED_COUNT == 0 )); then
  log_error "Autoconfig aborted - all modules are off (all CONFIGURE_* flags are false)."
  exit 0
fi

# ----------------------------------------------------------------------------
# 4. RUN ENABLED MODULES ONLY (no internal flag logic in modules)
# ----------------------------------------------------------------------------
for NAME in "${MODULES[@]}"; do
  FLAG="CONFIGURE_$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
  VAL=$(getFlag "$FLAG")
  if [[ -z "${VAL}" || "${VAL,,}" != "true" ]]; then
    log_warning "${NAME} module is disabled by config; skipping."
    continue
  fi

  SCRIPT="$MODULES_DIR/${NAME}.bash"
  if [ -x "$SCRIPT" ]; then
    log_info "Launching ${NAME} module..."
    if ! bash "$SCRIPT"; then
      log_warning "${NAME} module failed. See log for details."
    fi
  else
    log_warning "${NAME} module not found or not executable; skipped."
  fi
done

# ----------------------------------------------------------------------------
# 5. WRAP UP
# ----------------------------------------------------------------------------
log_info "Log saved to $LOG_FILE"
log_info "Done with ${SCRIPT_NAME} service"

exit 0

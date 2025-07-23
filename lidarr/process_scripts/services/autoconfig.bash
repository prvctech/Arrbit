#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - autoconfig.bash
# Version: v4.9
# Purpose: Orchestrates Arrbit modules based on config flags in arrbit-config.conf (Golden Standard enforced)
# -------------------------------------------------------------------------------------------------------------

# Source helpers
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v4.9"
ARRBIT_ROOT="/config/arrbit"
CONFIG_FILE="$ARRBIT_ROOT/config/arrbit-config.conf"
MODULES_DIR="$ARRBIT_ROOT/modules"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

# Override log_info/log_error for Golden Standard color
log_info() {
  echo -e "${CYAN}[Arrbit]${NC} $*"
  printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
}
log_error() {
  echo -e "${CYAN}[Arrbit]${NC} ERROR: $*" >&2
  printf '[Arrbit] ERROR: %s\n' "$*" >> "$LOG_FILE"
}

# Banner: Only this line with extra color
log_info "${YELLOW}${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION} ..."

# ----------------------------------------------------------------------------
# 1. MASTER FLAG: ENABLE_AUTOCONFIG (Always enforce)
# ----------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
if [[ -z "${ENABLE_AUTOCONFIG}" || "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  log_error "Autoconfig is off; check config settings. ENABLE_AUTOCONFIG=false (Set ENABLE_AUTOCONFIG=\"true\" in ${CONFIG_FILE})"
  exit 0
fi

# ----------------------------------------------------------------------------
# 2. CONNECT TO ARRBRIDGE (exports arr_api)
# ----------------------------------------------------------------------------
if ! source "$ARRBIT_ROOT/connectors/arr_bridge.bash"; then
  log_error "arr_bridge.bash not found or failed; exiting."
  exit 1
fi

# ----------------------------------------------------------------------------
# 3. MODULES LIST (Add/remove modules here as required)
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
# 4. CHECK IF ANY MODULES ARE ENABLED (fail early if none enabled)
# ----------------------------------------------------------------------------
enabled_count=0
for name in "${MODULES[@]}"; do
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  if [[ -n "${val}" && "${val,,}" == "true" ]]; then
    ((enabled_count++))
  fi
done
if (( enabled_count == 0 )); then
  log_error "Autoconfig disabled - all modules are off. ENABLE_AUTOCONFIG is true but all CONFIGURE_* flags are false."
  exit 0
fi

# ----------------------------------------------------------------------------
# 5. RUN ENABLED MODULES ONLY (no internal flag logic in modules)
# ----------------------------------------------------------------------------
for name in "${MODULES[@]}"; do
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  if [[ -z "${val}" || "${val,,}" != "true" ]]; then
    log_info "${YELLOW}${name} module${NC} is disabled by config; skipping."
    continue
  fi

  script="$MODULES_DIR/${name}.bash"
  if [ -x "$script" ]; then
    if ! bash "$script"; then
      log_error "${YELLOW}${name} module${NC} failed. See log for details."
    fi
  else
    log_error "${YELLOW}${name} module${NC} not found or not executable; skipped."
  fi
done

# ----------------------------------------------------------------------------
# 6. WRAP UP
# ----------------------------------------------------------------------------
log_info "Log saved to $LOG_FILE"
log_info "Done with ${SCRIPT_NAME} service"

exit 0

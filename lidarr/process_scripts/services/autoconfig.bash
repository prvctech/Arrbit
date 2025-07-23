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

ARRBIT_TAG_TTY="\033[36m[Arrbit]\033[0m"
ARRBIT_TAG_LOG="[Arrbit]"
SERVICE_YELLOW="\033[33m"
MODULE_YELLOW="\033[33m"
RESET="\033[0m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

# Terminal: colorized
echo -e "${ARRBIT_TAG_TTY} ${SERVICE_YELLOW}${SCRIPT_NAME} service${RESET} ${SCRIPT_VERSION} ..."
# Log: clean
echo "${ARRBIT_TAG_LOG} ${SCRIPT_NAME} service ${SCRIPT_VERSION} started." | arrbitLogClean >> "$LOG_FILE"

# ----------------------------------------------------------------------------
# 1. MASTER FLAG: ENABLE_AUTOCONFIG (Always enforce)
# ----------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
if [[ -z "${ENABLE_AUTOCONFIG}" || "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  echo -e "${ARRBIT_TAG_TTY} Autoconfig is off; check config settings."
  log_error "${ARRBIT_TAG_LOG} Autoconfig is off; check config settings. ENABLE_AUTOCONFIG=false (Set ENABLE_AUTOCONFIG=\"true\" in ${CONFIG_FILE})"
  exit 0
fi

# ----------------------------------------------------------------------------
# 2. CONNECT TO ARRBRIDGE (exports arr_api)
# ----------------------------------------------------------------------------
if ! source "$ARRBIT_ROOT/connectors/arr_bridge.bash"; then
  echo -e "${ARRBIT_TAG_TTY} arr_bridge.bash not found or failed; exiting."
  log_error "${ARRBIT_TAG_LOG} arr_bridge.bash not found or failed; exiting."
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
  echo -e "${ARRBIT_TAG_TTY} All modules disabled; nothing to do."
  log_error "${ARRBIT_TAG_LOG} Autoconfig disabled - all modules are off. ENABLE_AUTOCONFIG is true but all CONFIGURE_* flags are false."
  exit 0
fi

# ----------------------------------------------------------------------------
# 5. RUN ENABLED MODULES ONLY (no internal flag logic in modules)
# ----------------------------------------------------------------------------
for name in "${MODULES[@]}"; do
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  if [[ -z "${val}" || "${val,,}" != "true" ]]; then
    # Terminal
    echo -e "${ARRBIT_TAG_TTY} ${MODULE_YELLOW}${name} module${RESET} is disabled by config; skipping."
    # Log
    echo "${ARRBIT_TAG_LOG} ${name} module is disabled by config; skipping." | arrbitLogClean >> "$LOG_FILE"
    continue
  fi

  script="$MODULES_DIR/${name}.bash"
  if [ -x "$script" ]; then
    if ! bash "$script"; then
      echo -e "${ARRBIT_TAG_TTY} ${MODULE_YELLOW}${name} module${RESET} failed. See log for details."
      log_error "${ARRBIT_TAG_LOG} ${name} module failed. (${script})"
    fi
  else
    echo -e "${ARRBIT_TAG_TTY} ${MODULE_YELLOW}${name} module${RESET} not found or not executable; skipped."
    echo "${ARRBIT_TAG_LOG} ${name} module not found or not executable; skipped." | arrbitLogClean >> "$LOG_FILE"
  fi
done

# ----------------------------------------------------------------------------
# 6. WRAP UP
# ----------------------------------------------------------------------------
echo -e "${ARRBIT_TAG_TTY} Log saved to $LOG_FILE"
echo -e "${ARRBIT_TAG_TTY} Done with ${SCRIPT_NAME} service"
echo "${ARRBIT_TAG_LOG} Log saved to $LOG_FILE" | arrbitLogClean >> "$LOG_FILE"
echo "${ARRBIT_TAG_LOG} Done with ${SCRIPT_NAME} service" | arrbitLogClean >> "$LOG_FILE"

exit 0

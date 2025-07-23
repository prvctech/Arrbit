#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - autoconfig.bash
# Version: v4.8
# Purpose: Orchestrates Arrbit modules based on config flags in arrbit-config.conf (Golden Standard enforced)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash

arrbitPurgeOldLogs 5

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v4.8"
ARRBIT_ROOT="/config/arrbit"
CONFIG_FILE="$ARRBIT_ROOT/config/arrbit-config.conf"
MODULES_DIR="$ARRBIT_ROOT/modules"
LOG_DIR="/config/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
CYAN="\033[1;36m"
RESET="\033[0m"
SERVICE_YELLOW="\033[1;33m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

# Colorized first line for terminal, cleaned for log file
echo -e "${ARRBIT_TAG} ${SERVICE_YELLOW}${SCRIPT_NAME} service${RESET} ${SCRIPT_VERSION} ..." | tee >(arrbitLogClean >> "$LOG_FILE")

# ----------------------------------------------------------------------------
# 1. MASTER FLAG: ENABLE_AUTOCONFIG (Always enforce)
# ----------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
if [[ -z "${ENABLE_AUTOCONFIG}" || "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  log_error "${ARRBIT_TAG} Autoconfig is off; check config settings." \
    "ENABLE_AUTOCONFIG=false" \
    "autoconfig.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "service disabled" \
    "Set ENABLE_AUTOCONFIG=\"true\" in ${CONFIG_FILE}"
  echo -e "${ARRBIT_TAG} Autoconfig is off; exiting." | arrbitLogClean >> "$LOG_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 2. CONNECT TO ARRBRIDGE (exports arr_api)
# ----------------------------------------------------------------------------
if ! source "$ARRBIT_ROOT/connectors/arr_bridge.bash"; then
  log_error "${ARRBIT_TAG} Failed to source arr_bridge.bash" \
    "arr_bridge.bash source" \
    "$ARRBIT_ROOT/connectors/arr_bridge.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "file missing or error" \
    "Ensure file exists and is valid"
  echo -e "${ARRBIT_TAG} arr_bridge.bash not found or failed; exiting." | arrbitLogClean >> "$LOG_FILE"
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
  log_error "${ARRBIT_TAG} Autoconfig disabled - all modules are off; check your config settings." \
    "no modules enabled" \
    "autoconfig.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "ENABLE_AUTOCONFIG is true but all CONFIGURE_* flags are false" \
    "Enable at least one module or disable Autoconfig"
  echo -e "${ARRBIT_TAG} No modules enabled in config; exiting." | arrbitLogClean >> "$LOG_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 5. RUN ENABLED MODULES ONLY (no internal flag logic in modules)
# ----------------------------------------------------------------------------
for name in "${MODULES[@]}"; do
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  if [[ -z "${val}" || "${val,,}" != "true" ]]; then
    log_info "${ARRBIT_TAG} ${MODULE_YELLOW}${name} module${RESET} is disabled by config; skipping."
    echo -e "${ARRBIT_TAG} ${MODULE_YELLOW}${name} module${RESET} is disabled by config; skipping." | arrbitLogClean >> "$LOG_FILE"
    continue
  fi

  script="$MODULES_DIR/${name}.bash"
  if [ -x "$script" ]; then
    if ! bash "$script"; then
      log_error "${ARRBIT_TAG} ${name} module failed" \
        "${name}.bash execution" \
        "$script" \
        "${SCRIPT_NAME}:${LINENO}" \
        "exit non-zero" \
        "Check module script"
      echo -e "${ARRBIT_TAG} ${MODULE_YELLOW}${name} module${RESET} failed. See log for details." | arrbitLogClean >> "$LOG_FILE"
    fi
  else
    log_info "${ARRBIT_TAG} ${MODULE_YELLOW}${name} module${RESET} missing; skipping."
    echo -e "${ARRBIT_TAG} ${MODULE_YELLOW}${name} module${RESET} not found or not executable; skipped." | arrbitLogClean >> "$LOG_FILE"
  fi
done

# ----------------------------------------------------------------------------
# 6. WRAP UP
# ----------------------------------------------------------------------------
log_info "${ARRBIT_TAG} Log saved to $LOG_FILE"
log_info "${ARRBIT_TAG} Done with ${SCRIPT_NAME} service"
echo -e "${ARRBIT_TAG} Log saved to $LOG_FILE" | arrbitLogClean >> "$LOG_FILE"
echo -e "${ARRBIT_TAG} Done with ${SCRIPT_NAME} service" | arrbitLogClean >> "$LOG_FILE"

exit 0

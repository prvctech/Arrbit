#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - autoconfig.bash
# Version: v4.6
# Purpose: Orchestrates Arrbit modules to configure services based on config flags.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/error_utils.bash

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v4.6"
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

# ----------------------------------------------------------------------------
# 1. INIT: Ensure log directory and file
# ----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 777 "$LOG_FILE"

arrbitLog "${ARRBIT_TAG} Starting ${SERVICE_YELLOW}${SCRIPT_NAME} service${RESET} ${SCRIPT_VERSION}..."

# ----------------------------------------------------------------------------
# 2. MASTER FLAG: ENABLE_AUTOCONFIG
# ----------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
: "${ENABLE_AUTOCONFIG:=true}"
if [[ "$(echo "$ENABLE_AUTOCONFIG" | tr '[:upper:]' '[:lower:]')" != "true" ]]; then
  arrbitErrorLog "${ARRBIT_TAG} Autoconfig is off; check config settings." \
    "ENABLE_AUTOCONFIG=false" \
    "autoconfig.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "service disabled" \
    "Set ENABLE_AUTOCONFIG=\"true\" in ${CONFIG_FILE}"
  exit 0
fi

# ----------------------------------------------------------------------------
# 3. CONNECT TO ARRBRIDGE
# ----------------------------------------------------------------------------
if ! source "$ARRBIT_ROOT/connectors/arr_bridge.bash"; then
  arrbitErrorLog "${ARRBIT_TAG} Failed to source arr_bridge.bash" \
    "arr_bridge.bash source" \
    "$ARRBIT_ROOT/connectors/arr_bridge.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "file missing or error" \
    "Ensure file exists and is valid"
  exit 1
fi

# ----------------------------------------------------------------------------
# 4. MODULES LIST
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
# 4.a CHECK IF ANY MODULES ENABLED
# ----------------------------------------------------------------------------
enabledCount=0
for name in "${MODULES[@]}"; do
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  : "${val:=true}"
  if [[ "$(echo "$val" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
    ((enabledCount++))
  fi
done
if (( enabledCount == 0 )); then
  arrbitErrorLog "${ARRBIT_TAG} Autoconfig disabled - all modules are off; check your config settings." \
    "no modules enabled" \
    "autoconfig.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "ENABLE_AUTOCONFIG is true but all CONFIGURE_* flags are false" \
    "Enable at least one module or disable Autoconfig"
  exit 0
fi

# ----------------------------------------------------------------------------
# 5. RUN MODULES BASED ON FLAGS
# ----------------------------------------------------------------------------
for name in "${MODULES[@]}"; do
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  : "${val:=true}"
  if [[ "$(echo "$val" | tr '[:upper:]' '[:lower:]')" != "true" ]]; then
    continue
  fi

  script="$MODULES_DIR/${name}.bash"
  if [ -x "$script" ]; then
    # No running log here! Module prints its own "Starting ..." line.
    if ! bash "$script"; then
      arrbitErrorLog "${ARRBIT_TAG} ${name} module failed" \
        "${name}.bash execution" \
        "$script" \
        "${SCRIPT_NAME}:${LINENO}" \
        "exit non-zero" \
        "Check module script"
    fi
  else
    arrbitLog "${ARRBIT_TAG} ${MODULE_YELLOW}${name} module${RESET} missing; skipping"
  fi
done

# ----------------------------------------------------------------------------
# 6. WRAP UP
# ----------------------------------------------------------------------------
arrbitLog "${ARRBIT_TAG} Log saved to $LOG_FILE"
arrbitLog "${ARRBIT_TAG} Done with ${SCRIPT_NAME} service"

exit 0

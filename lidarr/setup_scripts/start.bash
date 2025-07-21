#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit start.bash
# Version: v2.1
# Purpose: Launches Arrbit services based on config flags. Installs dependencies from local copy. Supervises service modules.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="start"
SCRIPT_VERSION="v2.1"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
SETUP_DIR="$SERVICE_DIR/setup"
# Updated services directory path
SERVICES_DIR="$SERVICE_DIR/process_scripts/services"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
SERVICE_YELLOW="\033[1;33m"

# ----------------------------------------------------------------------------
# 1. INIT LOG FILE, CLEAN OLD LOGS, PERMISSIONS
# ----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
# Clean old logs if > 3 exist
log_count=$(ls -1 "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log 2>/dev/null | wc -l)
if [ "$log_count" -gt 3 ]; then
  ls -1tr "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log | head -n -3 | xargs rm -f
fi

touch "$log_file_path"
chmod 777 "$log_file_path"
chmod -R 777 "$SERVICE_DIR"

# ----------------------------------------------------------------------------
# 2. LOGO & HEADER
# ----------------------------------------------------------------------------
sleep 8  # Let container logs settle before Arrbit logo
if [ -f "$SERVICE_DIR/modules/data/arrbit_logo.bash" ]; then
  source "$SERVICE_DIR/modules/data/arrbit_logo.bash"
  arrbit_logo
  echo
fi

# ----------------------------------------------------------------------------
# 3. CHECK MASTER ARRBIT ENABLE FLAG
# ----------------------------------------------------------------------------
ENABLE_ARRBIT=$(getFlag "ENABLE_ARRBIT")
: "${ENABLE_ARRBIT:=true}"
if [[ "${ENABLE_ARRBIT,,}" != "true" ]]; then
  arrbitLog "⚠️   ${ARRBIT_TAG} Arrbit is OFF."
  arrbitLog "⚠️   ${ARRBIT_TAG} Before starting, enable Arrbit by setting ENABLE_ARRBIT=\"true\" in ${CONFIG_DIR}/arrbit-config.conf."
  sleep infinity
fi

# ----------------------------------------------------------------------------
# 4. INSTALL DEPENDENCIES IF PRESENT
# ----------------------------------------------------------------------------
if [ -f "$SETUP_DIR/dependencies.bash" ]; then
  chmod 777 "$SETUP_DIR/dependencies.bash"
  arrbitLog "📥  ${ARRBIT_TAG} Installing dependencies..."
  bash "$SETUP_DIR/dependencies.bash"
else
  arrbitLog "⚠️   ${ARRBIT_TAG} dependencies.bash not found in setup/. Skipping dependency install."
fi

# ----------------------------------------------------------------------------
# 5. PARSE FLAGS FOR SERVICES
# ----------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
: "${ENABLE_AUTOCONFIG:=true}"
ENABLE_PLUGINS=$(getFlag "ENABLE_PLUGINS")
: "${ENABLE_PLUGINS:=false}"

# ----------------------------------------------------------------------------
# 6. BUILD SERVICE LIST
# ----------------------------------------------------------------------------
ARRBIT_SERVICES=()
if [[ "${ENABLE_PLUGINS,,}" == "true" ]]; then
  ARRBIT_SERVICES+=("plugins.bash")
fi
if [[ "${ENABLE_AUTOCONFIG,,}" == "true" ]]; then
  ARRBIT_SERVICES+=("autoconfig.bash")
fi

# ----------------------------------------------------------------------------
# 7. EXECUTE SERVICES
# ----------------------------------------------------------------------------
for script in "${ARRBIT_SERVICES[@]}"; do
  service_path="$SERVICES_DIR/$script"
  if [ -x "$service_path" ]; then
    arrbitLog "🚀  ${ARRBIT_TAG} Running $script..."
    bash "$service_path"
    ret=$?
    if [ $ret -ne 0 ]; then
      arrbitErrorLog "❌" \
        "[Arrbit] $script exited with errors!" \
        "$script service failed" \
        "$service_path" \
        "${SCRIPT_NAME}:${LINENO}" \
        "$script returned $ret" \
        "Check $service_path for errors or missing dependencies"
    else
      arrbitLog "✅  ${ARRBIT_TAG} $script completed successfully."
    fi
  else
    arrbitLog "⏩  ${ARRBIT_TAG} $script not found or not executable; skipping."
  fi
done

# ----------------------------------------------------------------------------
# 8. DONE — WRAP UP & SLEEP
# ----------------------------------------------------------------------------
arrbitLog "📄  ${ARRBIT_TAG} Log saved to $log_file_path"
arrbitLog "✅  ${ARRBIT_TAG} All enabled services processed."

sleep infinity

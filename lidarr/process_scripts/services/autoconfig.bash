#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit autoconfig.bash
# Version: v3.6
# Purpose: Orchestrates Arrbit modules to configure Lidarr, Readarr, etc., based on config flags.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v3.6"
LOG_DIR="/config/logs"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
SERVICE_DIR="/etc/services.d/arrbit"
MODULES_DIR="$SERVICE_DIR/modules"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULE_YELLOW="\033[1;33m"

# init log directory and cleanup
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}${SCRIPT_NAME}\033[0m service ${SCRIPT_VERSION}..."

# ------------------------------------------------------------
# 2. Master Flag Check: ENABLE_AUTOCONFIG must be "true"
# ------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
: "${ENABLE_AUTOCONFIG:=true}"

if [[ "${ENABLE_AUTOCONFIG,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} autoconfig is disabled by flag. Skipping service."
  sleep infinity
fi

# ------------------------------------------------------------
# 3. Source LOCAL arr_bridge.bash (no remote exec!)
# ------------------------------------------------------------
if [ -f "$SERVICE_DIR/connectors/arr_bridge.bash" ]; then
  source "$SERVICE_DIR/connectors/arr_bridge.bash"
else
  arrbitErrorLog "❌" \
    "[Arrbit] Missing arr_bridge.bash in connectors!" \
    "arr_bridge.bash missing" \
    "arr_bridge.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "arr_bridge.bash not found in $SERVICE_DIR/connectors/" \
    "Check your Arrbit installation or re-pull repository"
  sleep infinity
fi

# ------------------------------------------------------------
# 4. Load CONFIGURE_* flags
# ------------------------------------------------------------
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# ------------------------------------------------------------
# 5. Check if all modules are disabled
# ------------------------------------------------------------
MODULES_TO_RUN=(
  "custom_formats.bash"
  "custom_scripts.bash"
  "delay_profiles.bash"
  "media_management.bash"
  "metadata_consumer.bash"
  "metadata_plugin.bash"
  "metadata_profiles.bash"
  "metadata_write.bash"
  "quality_profile.bash"
  "track_naming.bash"
  "ui_settings.bash"
)

enabledCount=0
for module in "${MODULES_TO_RUN[@]}"; do
  module_name="${module%.bash}"
  flag_var="CONFIGURE_${module_name^^}"
  cfg_val=$(getFlag "$flag_var")
  : "${cfg_val:=true}"
  if [[ "${cfg_val,,}" == "true" ]]; then
    ((enabledCount++))
  fi
done

if [ "$enabledCount" -eq 0 ]; then
  arrbitLog "⏩  ${ARRBIT_TAG} All modules are disabled. Skipping service (even though ENABLE_AUTOCONFIG is true)."
  sleep infinity
fi

# ------------------------------------------------------------
# 6. Run Each Enabled Module
# ------------------------------------------------------------
for module in "${MODULES_TO_RUN[@]}"; do
  module_name="${module%.bash}"
  module_path="$MODULES_DIR/$module"
  flag_var="CONFIGURE_${module_name^^}"
  cfg_val=$(getFlag "$flag_var")
  : "${cfg_val:=true}"

  if [[ "${cfg_val,,}" != "true" ]]; then
    arrbitLog "⏩  ${ARRBIT_TAG} Skipping ${module_name} (flag disabled)"
    continue
  fi

  if [ -f "$module_path" ]; then
    arrbitLog "🔄  ${ARRBIT_TAG} Running ${module_name}..."
    module_output=$(bash "$module_path" 2>&1)
    arrbitLog "$module_output"
    if [ $? -ne 0 ]; then
      arrbitErrorLog "❌" \
        "[Arrbit] ${module_name} failed" \
        "${module_name} module failed" \
        "${module_name}" \
        "${SCRIPT_NAME}:${LINENO}" \
        "${module_name} exited nonzero" \
        "Check ${module_path} for errors or missing dependencies"
    else
      arrbitLog "✅  ${ARRBIT_TAG} ${module_name} complete"
    fi
  else
    arrbitLog "⚠️   ${ARRBIT_TAG} ${module_name} missing, skipping"
  fi
done

# ------------------------------------------------------------
# 7. Wrap Up
# ------------------------------------------------------------
arrbitLog "📄  ${ARRBIT_TAG} Log saved to ${log_file_path}"
arrbitLog "✅  ${ARRBIT_TAG} Done with ${MODULE_YELLOW}${SCRIPT_NAME}\033[0m service!"

sleep infinity

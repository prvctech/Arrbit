#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit autoconfig.bash
# Version: v3.9
# Purpose: Orchestrates Arrbit modules to configure Lidarr, Readarr, etc., based on config flags.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="autoconfig"
SCRIPT_VERSION="v3.9"
SERVICE_DIR="/etc/services.d/arrbit"
LOG_DIR="/config/logs"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
MODULES_DIR="$SERVICE_DIR/modules"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
SERVICE_YELLOW="\033[1;33m"
MODULE_YELLOW="\033[1;33m"

# ----------------------------------------------------------------------------
# 1. INIT: log dir, cleanup, permissions
# ----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path" && chmod -R 777 "$SERVICE_DIR"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${SERVICE_YELLOW}${SCRIPT_NAME}\033[0m service ${SCRIPT_VERSION}..."

# ----------------------------------------------------------------------------
# 2. Master Flag Check: ENABLE_AUTOCONFIG
# ----------------------------------------------------------------------------
ENABLE_AUTOCONFIG=$(getFlag "ENABLE_AUTOCONFIG")
: "${ENABLE_AUTOCONFIG:=true}"
# normalize
ENABLE_AUTOCONFIG_LC=$(echo "$ENABLE_AUTOCONFIG" | tr '[:upper:]' '[:lower:]')
if [[ "$ENABLE_AUTOCONFIG_LC" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} ${SERVICE_YELLOW}${SCRIPT_NAME}\033[0m disabled by flag. Skipping."
  sleep infinity
fi

# ----------------------------------------------------------------------------
# 3. Source LOCAL arr_bridge.bash
# ----------------------------------------------------------------------------
if [[ -f "$SERVICE_DIR/connectors/arr_bridge.bash" ]]; then
  source "$SERVICE_DIR/connectors/arr_bridge.bash"
else
  arrbitErrorLog "❌" \
    "[Arrbit] Missing arr_bridge.bash in connectors!" \
    "arr_bridge.bash missing" \
    "connectors/arr_bridge.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Connector script absent" \
    "Ensure Arrbit installation is correct"
  sleep infinity
fi

# ----------------------------------------------------------------------------
# 4. Determine enabled modules
# ----------------------------------------------------------------------------
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
  name="${module%.bash}"
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  : "${val:=true}"
  val_lc=$(echo "$val" | tr '[:upper:]' '[:lower:]')
  if [[ "$val_lc" == "true" ]]; then
    ((enabledCount++))
  fi
done
if (( enabledCount == 0 )); then
  arrbitLog "⏩  ${ARRBIT_TAG} All modules disabled. Skipping service."
  sleep infinity
fi

# ----------------------------------------------------------------------------
# 5. Run enabled modules
# ----------------------------------------------------------------------------
for module in "${MODULES_TO_RUN[@]}"; do
  name="${module%.bash}"
  flag="CONFIGURE_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  val=$(getFlag "$flag")
  : "${val:=true}"
  val_lc=$(echo "$val" | tr '[:upper:]' '[:lower:]')
  if [[ "$val_lc" != "true" ]]; then
    arrbitLog "⏩  ${ARRBIT_TAG} Skipping ${MODULE_YELLOW}${name}\033[0m (flag disabled)"
    continue
  fi

  path="$MODULES_DIR/$module"
  if [[ -f "$path" ]]; then
    arrbitLog "🔄  ${ARRBIT_TAG} Running ${MODULE_YELLOW}${name}\033[0m..."
    output=$(bash "$path" 2>&1)
    arrbitLog "$output"
    exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      arrbitErrorLog "❌" \
        "[Arrbit] ${name} failed" \
        "${name} module failed" \
        "$module" \
        "${SCRIPT_NAME}:${LINENO}" \
        "exited code $exit_code" \
        "Check $path for errors"
    else
      arrbitLog "✅  ${ARRBIT_TAG} ${MODULE_YELLOW}${name}\033[0m complete"
    fi
  else
    arrbitLog "⚠️   ${ARRBIT_TAG} ${MODULE_YELLOW}${name}\033[0m missing, skipping"
  fi
done

# ----------------------------------------------------------------------------
# 6. Wrap Up
# ----------------------------------------------------------------------------
arrbitLog "📄  ${ARRBIT_TAG} Log saved to $log_file_path"
arrbitLog "✅  ${ARRBIT_TAG} Done with ${SERVICE_YELLOW}${SCRIPT_NAME}\033[0m service!"

sleep infinity

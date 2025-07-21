#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit start.bash
# Version: v3.3
# Purpose: Launch dependencies, plugins, and autoconfig services.
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
SETUP_DIR="$SERVICE_DIR/setup"
SERVICES_DIR="$SERVICE_DIR/services"

SERVICE_YELLOW="\033[1;33m"

# ----------------------------------------------------------------------------
# 1. INIT: Ensure logs dir and executables
# ----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
find "$SETUP_DIR" "$SERVICES_DIR" -type f -name "*.bash" -exec chmod +x {} \;

# ----------------------------------------------------------------------------
# 2. RUN DEPENDENCIES
# ----------------------------------------------------------------------------
if [ -x "$SETUP_DIR/dependencies.bash" ]; then
  bash "$SETUP_DIR/dependencies.bash" || arrbitErrorLog "❌" \
    "[Arrbit] dependencies failed" "dependencies.bash" "$SETUP_DIR/dependencies.bash" "start:${LINENO}" "exit non-zero" "Check setup script"
else
  arrbitLog "⚠️   [Arrbit] dependencies.bash not found; skipping."
fi

# ----------------------------------------------------------------------------
# 3. PLUGINS SERVICE
# ----------------------------------------------------------------------------
if [[ "$(getFlag ENABLE_PLUGINS || echo true)" == "true" ]]; then
  if [ -x "$SERVICES_DIR/plugins.bash" ]; then
    bash "$SERVICES_DIR/plugins.bash"
  else
    arrbitLog "⚠️   [Arrbit] plugins.bash not found or not executable; skipping."
  fi
fi

# ----------------------------------------------------------------------------
# 4. AUTOCONFIG SERVICE
# ----------------------------------------------------------------------------
if [[ "$(getFlag ENABLE_AUTOCONFIG || echo true)" == "true" ]]; then
  if [ -x "$SERVICES_DIR/autoconfig.bash" ]; then
    bash "$SERVICES_DIR/autoconfig.bash"
  else
    arrbitLog "⚠️   [Arrbit] autoconfig.bash not found or not executable; skipping."
  fi
fi

# ----------------------------------------------------------------------------
# 5. WRAP UP
# ----------------------------------------------------------------------------
arrbitLog "✅  [Arrbit] All services processed."

sleep infinity

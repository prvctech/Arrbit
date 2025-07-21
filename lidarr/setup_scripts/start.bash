#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit start.bash
# Version: v3.2
# Purpose: Launch dependencies and run enabled services (autoconfig & plugins).
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

# ----------------------------------------------------------------------------
# 1. INIT: Ensure logs directory and executable permissions
# ----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
# Make sure all bash scripts in setup and services are executable
find "$SETUP_DIR" "$SERVICES_DIR" -type f -name "*.bash" -exec chmod +x {} \;

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
# 3. RUN DEPENDENCIES
# ----------------------------------------------------------------------------
if [ -x "$SETUP_DIR/dependencies.bash" ]; then
  arrbitLog "📥  [Arrbit] Installing dependencies..."
  bash "$SETUP_DIR/dependencies.bash" || \
    arrbitErrorLog "❌" "[Arrbit] dependencies failed" "dependencies.bash" "$SETUP_DIR/dependencies.bash" "start:${LINENO}" "exit non-zero" "Check setup script"
else
  arrbitLog "⚠️   [Arrbit] No dependencies script found; skipping."
fi

# ----------------------------------------------------------------------------
# 4. AUTOCONFIG SERVICE
# ----------------------------------------------------------------------------
if [[ "$(getFlag ENABLE_AUTOCONFIG)" != "false" ]]; then
  if [ -x "$SERVICES_DIR/autoconfig.bash" ]; then
    arrbitLog "🚀  [Arrbit] Running autoconfig service..."
    bash "$SERVICES_DIR/autoconfig.bash"
  else
    arrbitLog "⚠️   [Arrbit] autoconfig.bash not found or not executable; skipping."
  fi
fi

# ----------------------------------------------------------------------------
# 5. PLUGINS SERVICE
# ----------------------------------------------------------------------------
if [[ "$(getFlag ENABLE_PLUGINS)" != "false" ]]; then
  if [ -x "$SERVICES_DIR/plugins.bash" ]; then
    arrbitLog "🚀  [Arrbit] Running plugins service..."
    bash "$SERVICES_DIR/plugins.bash"
  else
    arrbitLog "⚠️   [Arrbit] plugins.bash not found or not executable; skipping."
  fi
fi

# ----------------------------------------------------------------------------
# 6. WRAP UP
# ----------------------------------------------------------------------------
arrbitLog "✅  [Arrbit] All services processed."

sleep infinity

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [plugins]
# Version: v2.2
# Purpose: Install community plugins for Lidarr (Tidal, Deezer, Tubifarry)
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="plugins"
SCRIPT_VERSION="v2.2"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_FILE="/config/arrbit/arrbit-config.conf"
LOG_DIR="/config/logs"
PLUGINS_DIR="/config/plugins"
: "${ENABLE_PLUGINS:=true}"
: "${INSTALL_PLUGIN_DEEZER:=false}"
: "${INSTALL_PLUGIN_TIDAL:=false}"
: "${INSTALL_PLUGIN_TUBIFARRY:=false}"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# ------------------------------------------------------------
# 0. INIT
# ------------------------------------------------------------
mkdir -p "$LOG_DIR"
# Rotate old logs
ls -1t "$LOG_DIR"/arrbit-${SCRIPT_NAME}-*.log 2>/dev/null | tail -n +4 | xargs -r rm -f
touch "$log_file_path"
chmod 777 "$log_file_path"
chmod -R 777 "$PLUGINS_DIR"

# Trap any uncaught error
trap 'arrbitErrorLog "❌" "[Arrbit] Unexpected error in plugins" "uncaught error" "plugins.bash" "${SCRIPT_NAME}:${LINENO}" "check script" "Review log file"; exit 1' ERR

sleep 8  # Let container logs settle before Arrbit logo

# ------------------------------------------------------------
# 1. LOGO & HEADER
# ------------------------------------------------------------
echo
if [ -f "$SERVICE_DIR/modules/data/arrbit_logo.bash" ]; then
  source "$SERVICE_DIR/modules/data/arrbit_logo.bash"
  arrbit_logo
  echo
fi
arrbitLog "🚀  [Arrbit] Starting plugins service\033[0m v${SCRIPT_VERSION}"

# ------------------------------------------------------------
# 2. MASTER FLAG CHECK
# ------------------------------------------------------------
ENABLE_PLUGINS=$(getFlag "ENABLE_PLUGINS" || echo "$ENABLE_PLUGINS")
if [[ "${ENABLE_PLUGINS,,}" != "true" ]]; then
  arrbitLog "⏩  [Arrbit] Plugin install is disabled by flag. Skipping."
  exit 0
fi

# ------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------
has_dll() {
  shopt -s nullglob
  local files=("$1"/*.dll)
  (( ${#files[@]} > 0 ))
}

print_unzip_clean() {
  while IFS= read -r line; do
    [[ "$line" =~ ^Archive:\ (.*) ]]   && arrbitLog "📦  [Arrbit] Archive:    ${BASH_REMATCH[1]}"
    [[ "$line" =~ ^\ \ inflating:\ (.*) ]] && arrbitLog "📁  [Arrbit] inflating:  ${BASH_REMATCH[1]}"
  done
}

# ------------------------------------------------------------
# 3. INSTALLATION LOGIC (Deezer, Tidal, Tubifarry)
# ------------------------------------------------------------
install_plugin() {
  local name="$1" target="$2" url="$3" flag="$4"
  if [[ "${!flag,,}" != "true" ]]; then
    arrbitLog "⏩  [Arrbit] ${name} plugin disabled; skipping."
    return
  fi

  if has_dll "$target"; then
    arrbitLog "⏩  [Arrbit] ${name} plugin already installed; skipping."
  else
    arrbitLog "🌐  [Arrbit] Downloading ${name} plugin..."
    rm -rf /tmp/arrbit-plugins && mkdir -p /tmp/arrbit-plugins
    curl -fsSL -o /tmp/arrbit-plugins/${name}.zip "$url"
    arrbitLog "📦  [Arrbit] ${name} archive downloaded."
    unzip -q /tmp/arrbit-plugins/${name}.zip -d /tmp/arrbit-plugins | print_unzip_clean
    arrbitLog "📥  [Arrbit] Installing ${name} plugin..."
    mkdir -p "$target"
    mv /tmp/arrbit-plugins/* "$target/"
    chmod -R 777 "$target"
    arrbitLog "✅  [Arrbit] ${name} plugin installed."
  fi
}

install_plugin "Deezer"   "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer"      "https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip"     INSTALL_PLUGIN_DEEZER
install_plugin "Tidal"    "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"       "https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip"       INSTALL_PLUGIN_TIDAL
install_plugin "Tubifarry" "$PLUGINS_DIR/TypNull/Tubifarry"               "https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip"        INSTALL_PLUGIN_TUBIFARRY

# ------------------------------------------------------------
# 4. WRAP UP
# ------------------------------------------------------------
arrbitLog "📄  [Arrbit] Log saved to $log_file_path"
arrbitLog "✅  [Arrbit] Done with plugins service!"
exit 0

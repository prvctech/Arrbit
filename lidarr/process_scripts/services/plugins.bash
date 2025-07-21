#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit [plugins]
# Version: v2.6
# Purpose: Install community plugins for Lidarr (Tidal, Deezer, Tubifarry)
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="plugins"
SCRIPT_VERSION="v2.6"
SERVICE_DIR="/etc/services.d/arrbit"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
PLUGINS_DIR="/config/plugins"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
SERVICE_YELLOW="\033[1;33m"
PLUGIN_PURPLE="\033[1;35m"

# ----------------------------------------------------------------------------
# 1. INIT: Prepare directories and permissions
# ----------------------------------------------------------------------------
mkdir -p "$LOG_DIR" "$PLUGINS_DIR"
# Ensure plugin and service scripts are executable
find "/etc/services.d/arrbit/services" -type f -name "*.bash" -exec chmod +x {} \;

touch "$log_file_path"
chmod 777 "$log_file_path"

# ----------------------------------------------------------------------------
# 2. STARTUP & MASTER FLAG
# ----------------------------------------------------------------------------
arrbitLog "🚀  ${ARRBIT_TAG} Starting ${SERVICE_YELLOW} service\033[0m v${SCRIPT_VERSION}"
if [ ! -r "$CONFIG_DIR/arrbit-config.conf" ]; then
  arrbitLog "⚠️   ${ARRBIT_TAG} Config file missing; skipping ${SERVICE_YELLOW}${SCRIPT_NAME}\033[0m."
  exit 0
fi

ENABLE_PLUGINS=$(getFlag "ENABLE_PLUGINS")
: "${ENABLE_PLUGINS:=true}"
if [[ "${ENABLE_PLUGINS,,}" != "true" ]]; then
  arrbitLog "⏩  ${ARRBIT_TAG} Plugin install is disabled; skipping ${SERVICE_YELLOW}${SCRIPT_NAME}\033[0m."
  exit 0
fi

# ----------------------------------------------------------------------------
# 3. HELPER FUNCTIONS
# ----------------------------------------------------------------------------
has_dll() {
  shopt -s nullglob
  local files=("$1"/*.dll)
  (( ${#files[@]} > 0 ))
}

print_unzip_clean() {
  while IFS= read -r line; do
    [[ "$line" =~ ^Archive:\ (.*) ]]   && arrbitLog "📦  ${ARRBIT_TAG} Archive:    ${BASH_REMATCH[1]}"
    [[ "$line" =~ ^\ +inflating:\ (.*) ]] && arrbitLog "📁  ${ARRBIT_TAG} Inflating:  ${BASH_REMATCH[1]}"
  done
}

# ----------------------------------------------------------------------------
# 4. INSTALL FUNCTION
# ----------------------------------------------------------------------------
install_plugin() {
  local name="$1" target="$2" url="$3"
  if has_dll "$target"; then
    arrbitLog "⏩  ${ARRBIT_TAG} ${PLUGIN_PURPLE}${name}\033[0m plugin already installed; skipping"
    return
  fi

  arrbitLog "🌐  ${ARRBIT_TAG} Downloading ${PLUGIN_PURPLE}${name}\033[0m plugin..."
  tmpdir=$(mktemp -d)
  if ! curl -fsSL -o "$tmpdir/${name}.zip" "$url"; then
    arrbitErrorLog "❌" "[Arrbit] Failed to download ${name}" "download ${name}" "$name" "plugins:${LINENO}" "curl error" "Check URL/network"
    return
  fi

  arrbitLog "📦  ${ARRBIT_TAG} ${name} archive downloaded."
  unzip -q "$tmpdir/${name}.zip" -d "$tmpdir" | print_unzip_clean
  arrbitLog "📥  ${ARRBIT_TAG} Installing ${PLUGIN_PURPLE}${name}\033[0m plugin..."
  mkdir -p "$target"
  mv "$tmpdir"/* "$target/"
  chmod -R 777 "$target"
  rm -rf "$tmpdir"
  arrbitLog "✅  ${ARRBIT_TAG} ${PLUGIN_PURPLE}${name}\033[0m plugin installed"
}

# ----------------------------------------------------------------------------
# 5. PLUGINS INSTALLATION
# ----------------------------------------------------------------------------
install_plugin "Deezer"    "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer"   "https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip"
install_plugin "Tidal"     "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"    "https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip"
install_plugin "Tubifarry" "$PLUGINS_DIR/TypNull/Tubifarry"          "https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip"

# ----------------------------------------------------------------------------
# 6. WRAP UP
# ----------------------------------------------------------------------------
arrbitLog "📄  ${ARRBIT_TAG} Log saved to $log_file_path"
arrbitLog "✅  ${ARRBIT_TAG} Done with ${SCRIPT_NAME} service"

exit 0

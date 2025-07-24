#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - plugins
# Version: v3.7-gs2.6
# Purpose: Install or update Deezer, Tidal, Tubifarry plug-ins for Lidarr (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Golden Standard: Always source logging_utils first, then helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

arrbitPurgeOldLogs 2

chmod -R 777 /config/arrbit/
chmod -R 777 /config/plugins/
chmod -R 777 /config/logs/

PLUGINS_DIR="/config/plugins"
SCRIPT_NAME="plugins"
SCRIPT_VERSION="v3.7-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
CONFIG_FILE="/config/arrbit/config/arrbit-config.conf"

touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- Banner (color allowed on first line) ---
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}${SCRIPT_NAME}${NC} service ${MAGENTA}Deezer, Tidal, Tubifarry${NC} ${SCRIPT_VERSION}"
echo

# --- Check ENABLE_PLUGINS flag (Golden Standard: fail fast) ---
ENABLE_PLUGINS=$(getFlag ENABLE_PLUGINS)
if [[ "${ENABLE_PLUGINS,,}" != "true" ]]; then
  log_warning "Plugins service is OFF. Update ENABLE_PLUGINS to 'true' in arrbit-config.conf."
  log_info "Log saved to $LOG_FILE"
  exit 0
fi

# --- FUNCTIONS ---
has_dll() {
  shopt -s nullglob
  local dll_files=("$1"/*.dll)
  (( ${#dll_files[@]} ))
}

install_plugin() {  # $1 = plugin_name, $2 = plugin_dir, $3 = plugin_url
  local plugin_name="$1"
  local plugin_dir="$2"
  local plugin_url="$3"

  if has_dll "$plugin_dir"; then
    log_info "$plugin_name already present – skipping"
    return
  fi

  log_info "Downloading $plugin_name …"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  if curl -fsSL -o "$tmp_dir/plugin.zip" "$plugin_url" >>"$LOG_FILE" 2>&1; then
    if unzip -q "$tmp_dir/plugin.zip" -d "$tmp_dir" >>"$LOG_FILE" 2>&1; then
      mkdir -p "$plugin_dir"
      find "$tmp_dir" -type f \( -iname "*.dll" -o -iname "*.json" -o -iname "*.pdb" \) -exec mv {} "$plugin_dir/" \;
      chmod -R 777 "$plugin_dir"
      log_info "$plugin_name installed"
    else
      log_warning "Failed to unzip $plugin_name – skipped"
    fi
  else
    log_warning "Failed to download $plugin_name – skipped"
  fi

  rm -rf "$tmp_dir"
}

# --- PLUGIN INSTALLATION ---
install_plugin "Deezer"    "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer" \
  "https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip"

install_plugin "Tidal"     "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"  \
  "https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip"

install_plugin "Tubifarry" "$PLUGINS_DIR/TypNull/Tubifarry" \
  "https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip"

log_info "Log saved to $LOG_FILE"
log_info "Done with ${SCRIPT_NAME} service"

exit 0

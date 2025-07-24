#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - plugins
# Version: v3.4-gs2.6
# Purpose: Install or update Deezer, Tidal, Tubifarry plug-ins for Lidarr (Golden Standard v2.6 compliant).
# -------------------------------------------------------------------------------------------------------------

# Golden Standard: Always source logging_utils first, then helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

# Golden Standard: Purge old logs (>2 days)
arrbitPurgeOldLogs

# Golden Standard: Recursively set full permissions (clear comment)
chmod -R 777 /config/arrbit/
chmod -R 777 /config/plugins/
chmod -R 777 /config/logs/

# ------------------ GLOBAL CONSTANTS --------------------------
PLUGINS_DIR="/config/plugins"
SCRIPT_NAME="plugins"
SCRIPT_VERSION="v3.4-gs2.6"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# ------------------ BANNER (single line, colored as per GS v2.6) --------------------------
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}${SCRIPT_NAME}${NC} service ${MAGENTA}Deezer, Tidal, Tubifarry${NC} ${SCRIPT_VERSION}"

# ------------------ FUNCTIONS --------------------------
has_dll() {
  # Enable nullglob for empty glob expansion
  shopt -s nullglob
  local dll_files=("$1"/*.dll)
  (( ${#dll_files[@]} ))
}

install_plugin() {  # $1 = plugin_name, $2 = plugin_dir, $3 = plugin_url
  local plugin_name="$1"
  local plugin_dir="$2"
  local plugin_url="$3"

  # Check if DLL already exists
  if has_dll "$plugin_dir"; then
    log_info "$plugin_name already present – skipping"
    return
  fi

  log_info "Downloading $plugin_name …"

  # Create temporary download directory
  local tmp_dir
  tmp_dir=$(mktemp -d)

  if curl -fsSL -o "$tmp_dir/plugin.zip" "$plugin_url" >>"$LOG_FILE" 2>&1; then
    if unzip -q "$tmp_dir/plugin.zip" -d "$tmp_dir" >>"$LOG_FILE" 2>&1; then
      mkdir -p "$plugin_dir"
      # Only move allowed plugin files
      find "$tmp_dir" -type f \( -iname "*.dll" -o -iname "*.json" -o -iname "*.pdb" \) -exec mv {} "$plugin_dir/" \;
      chmod -R 777 "$plugin_dir"
      log_info "$plugin_name installed"
    else
      log_error "Failed to unzip $plugin_name – skipped"
    fi
  else
    log_error "Failed to download $plugin_name – skipped"
  fi

  # Cleanup temporary directory
  rm -rf "$tmp_dir"
}

# ------------------ PLUGIN INSTALLATION --------------------------
install_plugin "Deezer"    "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer" \
  "https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip"

install_plugin "Tidal"     "$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"  \
  "https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip"

install_plugin "Tubifarry" "$PLUGINS_DIR/TypNull/Tubifarry" \
  "https://github.com/TypNull/Tubifarry/releases/download/v1.8.1.1/Tubifarry-v1.8.1.1.net6.0-develop.zip"

# ------------------ LOG LOCATION (PLAIN) --------------------------
log_info "Log saved to $LOG_FILE"

exit 0

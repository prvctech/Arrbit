#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - plugins
# Version: v3.3
# Purpose: Install or update Deezer, Tidal, Tubifarry plug-ins for Lidarr.
# -------------------------------------------------------------------------------------------------------------

# Golden Standard: Always source helpers and logging first
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash

# Golden Standard: Purge old logs (default >2 days)
arrbitPurgeOldLogs

# Golden Standard: Recursively set full permissions
chmod -R 777 /config/arrbit/
chmod -R 777 /config/plugins/
chmod -R 777 /config/logs/

# ------------------ GLOBAL CONSTANTS --------------------------
PLUGINS_DIR="/config/plugins"
SCRIPT_NAME="plugins"
SCRIPT_VERSION="v3.3"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Color codes (only use for the banner, not for subsequent logs)
CYAN='\033[36m'
PURPLE='\033[35m'
YELLOW='\033[33m'
NC='\033[0m'

# ------------------ BANNER LOG (COLOR ONLY HERE) --------------------------
echo -e "${CYAN}[Arrbit]${NC} ${YELLOW}${SCRIPT_NAME}${NC} service ${PURPLE}Deezer, Tidal, Tubifarry${NC} ${SCRIPT_VERSION}"

# ------------------ FUNCTIONS --------------------------
# Check if a directory contains any .dll file
has_dll() {
  # One-line comment: enable nullglob for empty glob expansion
  shopt -s nullglob
  local dll_files=("$1"/*.dll)
  (( ${#dll_files[@]} ))
}

# Install a plugin if not already present
install_plugin() {  # $1 = plugin_name, $2 = plugin_dir, $3 = plugin_url
  local plugin_name="$1"
  local plugin_dir="$2"
  local plugin_url="$3"

  # One-line comment: Check if DLL already exists
  if has_dll "$plugin_dir"; then
    log_info "[Arrbit] $plugin_name already present – skipping"
    return
  fi

  log_info "[Arrbit] Downloading $plugin_name …"

  # One-line comment: Create temporary download directory
  local tmp_dir
  tmp_dir=$(mktemp -d)

  if curl -fsSL -o "$tmp_dir/plugin.zip" "$plugin_url" >>"$LOG_FILE" 2>&1; then
    if unzip -q "$tmp_dir/plugin.zip" -d "$tmp_dir" >>"$LOG_FILE" 2>&1; then
      mkdir -p "$plugin_dir"
      # Only move allowed plugin files
      find "$tmp_dir" -type f \( -iname "*.dll" -o -iname "*.json" -o -iname "*.pdb" \) -exec mv {} "$plugin_dir/" \;
      chmod -R 777 "$plugin_dir"
      log_info "[Arrbit] $plugin_name installed"
    else
      log_error "[Arrbit] Failed to unzip $plugin_name – skipped"
    fi
  else
    log_error "[Arrbit] Failed to download $plugin_name – skipped"
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
log_info "[Arrbit] Log saved to $LOG_FILE"

exit 0

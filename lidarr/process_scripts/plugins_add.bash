#!/usr/bin/env bash
#
# Arrbit community plugins installer
# Version: v1.1
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

echo "*** [Arrbit] Starting community plugins installation... ***"

CONFIG_FILE="/config/arrbit/config/arrbit.conf"
PLUGINS_DIR="/config/plugins"

# 1) Load config
if [ ! -r "$CONFIG_FILE" ]; then
  echo "✖ Config file not found: $CONFIG_FILE. Skipping plugins."
  exit 0
fi
source "$CONFIG_FILE"

# 2) Master switch
if [ "${ENABLE_COMMUNITY_PLUGINS,,}" != "true" ]; then
  echo "⏭ ENABLE_COMMUNITY_PLUGINS != true. Skipping all."
  exit 0
fi

has_dll() {
  shopt -s nullglob
  files=("$1"/*.dll)
  ((${#files[@]} > 0))
}

# Deezer
DEEZER_TARGET="$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Deezer"
if [ "${INSTALL_PLUGIN_DEEZER,,}" = "true" ]; then
  if has_dll "$DEEZER_TARGET"; then
    echo "✔ Deezer already installed. Skipping."
  else
    echo "*** Installing Deezer plugin ***"
    rm -rf /tmp/*
    mkdir -p /tmp/deezer
    curl -sfL -o /tmp/deezer.zip \
      https://github.com/TrevTV/Lidarr.Plugin.Deezer/releases/latest/download/Lidarr.Plugin.Deezer.net6.0.zip
    unzip -o /tmp/deezer.zip -d /tmp/deezer
    mkdir -p "$DEEZER_TARGET"
    mv /tmp/deezer/* "$DEEZER_TARGET/"
    chmod -R 777 "$DEEZER_TARGET"
    echo "✔ Deezer installed."
  fi
else
  echo "⏭ INSTALL_PLUGIN_DEEZER != true. Skipping Deezer."
fi

# Tidal
TIDAL_TARGET="$PLUGINS_DIR/TrevTV/Lidarr.Plugin.Tidal"
if [ "${INSTALL_PLUGIN_TIDAL,,}" = "true" ]; then
  if has_dll "$TIDAL_TARGET"; then
    echo "✔ Tidal already installed. Skipping."
  else
    echo "*** Installing Tidal plugin ***"
    rm -rf /tmp/*
    mkdir -p /tmp/tidal
    curl -sfL -o /tmp/tidal.zip \
      https://github.com/TrevTV/Lidarr.Plugin.Tidal/releases/latest/download/Lidarr.Plugin.Tidal.net6.0.zip
    unzip -o /tmp/tidal.zip -d /tmp/tidal
    mkdir -p "$TIDAL_TARGET"
    mv /tmp/tidal/* "$TIDAL_TARGET/"
    chmod -R 777 "$TIDAL_TARGET"
    echo "✔ Tidal installed."
  fi
else
  echo "⏭ INSTALL_PLUGIN_TIDAL != true. Skipping Tidal."
fi

# Tubifarry
TUBI_TARGET="$PLUGINS_DIR/TypNull/Tubifarry"
if [ "${INSTALL_PLUGIN_TUBIFARRY,,}" = "true" ]; then
  if has_dll "$TUBI_TARGET"; then
    echo "✔ Tubifarry already installed. Skipping."
  else
    echo "*** Installing Tubifarry plugin ***"
    rm -rf /tmp/*
    mkdir -p /tmp/tubifarry
    curl -sfL -o /tmp/tubifarry.zip \
      https://github.com/TypNull/Tubifarry/releases/download/v1.8.0.7/Tubifarry-v1.8.0.7.net6.0-develop.zip
    unzip -o /tmp/tubifarry.zip -d /tmp/tubifarry
    mkdir -p "$TUBI_TARGET"
    mv /tmp/tubifarry/* "$TUBI_TARGET/"
    chmod -R 777 "$TUBI_TARGET"
    echo "✔ Tubifarry installed."
  fi
else
  echo "⏭ INSTALL_PLUGIN_TUBIFARRY != true. Skipping Tubifarry."
fi

echo "*** [Arrbit] Plugin installation complete. ***"

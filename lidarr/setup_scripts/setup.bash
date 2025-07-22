#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.1
# Purpose: Prepare folder structure, install dependencies, download/refresh Arrbit scripts, and manage config files.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

# ------------------ 0. ENV AND PATHS ------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"

SERVICE_DIR="/custom-services.d"
HELPERS_DIR="$SERVICE_DIR/helpers"
CONNECTORS_DIR="$SERVICE_DIR/connectors"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit_update_$$"
SETUP_DIR="$SERVICE_DIR/setup"

SCRIPT_NAME="setup"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# ------------------ 1. BASIC OUTPUT HEADER ------------------
echo "[Arrbit] running setup v1.1"

# ------------------ 2. FAILSAFE ------------------
if [ -f /custom-cont-init.d/initial_run.bash ]; then
  echo "[Arrbit] initial_run.bash present in /custom-cont-init.d – halting to avoid conflict."
  sleep infinity
fi

# ------------------ 3. CREATE FOLDERS ------------------
mkdir -p "$SERVICE_DIR" "$HELPERS_DIR" "$CONNECTORS_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$SETUP_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$SETUP_DIR"

# ------------------ 4. INSTALL DEPENDENCIES ------------------
echo "[Arrbit] installing Alpine packages ..."
apk add -U --upgrade --no-cache \
  tidyhtml \
  musl-locales \
  musl-locales-lang \
  flac \
  jq \
  git \
  gcc \
  ffmpeg \
  imagemagick \
  opus-tools \
  opustags \
  python3-dev \
  libc-dev \
  uv \
  parallel \
  npm \
  perl \
  ripgrep

echo "[Arrbit] installing AtomicParsley ..."
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley

echo "[Arrbit] installing Python packages (uv) ..."
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
  jellyfish \
  beautifulsoup4 \
  yt-dlp \
  beets \
  yq \
  pyxDamerauLevenshtein \
  pyacoustid \
  requests \
  colorama \
  python-telegram-bot \
  pylast \
  mutagen \
  r128gain \
  tidal-dl

# ------------------ 5. DOWNLOAD & UNZIP REPO ------------------
echo "[Arrbit] downloading Arrbit repository ..."
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip"
echo "Arrbit: extracting repository ..."
unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR"

# ------------------ 6. COPY CODE ------------------
cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICE_DIR/"

if [ -d "$TMP_DIR/Arrbit-main/universal/helpers" ]; then
  cp -rf "$TMP_DIR/Arrbit-main/universal/helpers/"* "$HELPERS_DIR/"
fi

if [ -d "$TMP_DIR/Arrbit-main/universal/connectors" ]; then
  cp -rf "$TMP_DIR/Arrbit-main/universal/connectors/"* "$CONNECTORS_DIR/"
fi

chmod -R 777 "$SERVICE_DIR"
echo "Arrbit: modules, helpers, and connectors copied."

# ----- Strip .bash from service scripts -----
if [ -d "$SERVICE_DIR/services" ]; then
  for f in "$SERVICE_DIR/services/"*.bash; do
    [ -e "$f" ] || break
    mv "$f" "${f%.bash}"
    chmod 777 "${f%.bash}"
  done
fi

# ------------------ 7. COPY SETUP SCRIPTS ------------------
for setup_script in start.bash dependencies.bash; do
  src="$TMP_DIR/Arrbit-main/lidarr/setup_scripts/$setup_script"
  if [ -f "$src" ]; then
    cp -f "$src" "$SETUP_DIR/"
    chmod 777 "$SETUP_DIR/$setup_script"
    echo "Arrbit: $setup_script copied."
  fi
done

# ------------------ 8. COPY CONFIG FILES IF MISSING ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  src_cfg="$TMP_DIR/Arrbit-main/lidarr/config/$cfg"
  if [ -f "$src_cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    cp "$src_cfg" "$CONFIG_DIR/"
    chmod 666 "$CONFIG_DIR/$cfg"
    echo "Arrbit: $cfg saved to config directory."
  fi
done

# ------------------ 9. CLEANUP & PERMISSIONS ------------------
rm -rf "$TMP_DIR"
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$SETUP_DIR" || true
echo "[Arrbit] setup complete."
echo "[Arrbit] See your config settings to enable Arrbit, everything if off by default."

# ------------------ 10. HOLD CONTAINER ------------------
sleep infinity

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup
# Version: v1.4
# Purpose: Prepare folder structure, install/upgrade dependencies once, download/refresh Arrbit scripts,
#          and manage config files. All verbose installer output is kept only in the log file.
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

scriptVersion="1.4"                       # bump this whenever the dependency list changes

# ------------------ ENV & PATHS ------------------
GITHUB_REPO="https://github.com/prvctech/Arrbit"
GITHUB_BRANCH="main"

SERVICE_DIR="/custom-services.d"
HELPERS_DIR="$SERVICE_DIR/helpers"
CONNECTORS_DIR="$SERVICE_DIR/connectors"
CONFIG_DIR="/config/arrbit"
LOG_DIR="/config/logs"
TMP_DIR="/tmp/arrbit_update_$$"

# Ensure log dir exists and create a run-time log file
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/arrbit-setup-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE"

# ------------------ HEADER ------------------
echo "[Arrbit] running setup v${scriptVersion}" | tee -a "$LOG_FILE"

# ------------------ FAILSAFE ------------------
if [ -f /custom-cont-init.d/initial_run.bash ]; then
  echo "[Arrbit] initial_run.bash detected – halting to avoid conflict." | tee -a "$LOG_FILE"
  sleep infinity
fi

# ------------------ CREATE FOLDERS ------------------
mkdir -p "$SERVICE_DIR" "$HELPERS_DIR" "$CONNECTORS_DIR" "$CONFIG_DIR" "$TMP_DIR"
chmod -R 777 "$SERVICE_DIR" "$CONFIG_DIR"
echo "[Arrbit] folder structure ready" | tee -a "$LOG_FILE"

# ------------------ DEPENDENCY LOGIC ------------------
# deps marker now lives under /custom-services/helpers
deps_marker="/custom-services/helpers/deps_version.txt"
mkdir -p "$(dirname "$deps_marker")"

if [ -f "$deps_marker" ]; then
  # shellcheck source=/dev/null
  source "$deps_marker"
fi

needs_install=false
if ! command -v atomicparsley >/dev/null 2>&1; then
  needs_install=true
fi

if [ "${depsversion:-}" = "$scriptVersion" ] && [ "$needs_install" = false ]; then
  echo "[Arrbit] dependencies already installed - skipping" | tee -a "$LOG_FILE"
else
  if [ -n "${depsversion:-}" ] && [ "$depsversion" != "$scriptVersion" ]; then
    echo "[Arrbit] upgrading dependencies (details in log file)" | tee -a "$LOG_FILE"
  else
    echo "[Arrbit] installing dependencies (details in log file)" | tee -a "$LOG_FILE"
  fi

  # --- Alpine / system packages ---
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
    ripgrep >> "$LOG_FILE" 2>&1

  # AtomicParsley (edge)
  apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley >> "$LOG_FILE" 2>&1

  # --- Python packages ---
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
    tidal-dl >> "$LOG_FILE" 2>&1

  # Record the installed dependency version
  echo "depsversion=$scriptVersion" > "$deps_marker"
  echo "[Arrbit] dependency installation/upgrade complete" | tee -a "$LOG_FILE"
fi

# ------------------ DOWNLOAD & EXTRACT REPO ------------------
echo "[Arrbit] downloading Arrbit repository ..." | tee -a "$LOG_FILE"
curl -sfL "$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip" -o "$TMP_DIR/arrbit.zip" >> "$LOG_FILE" 2>&1
echo "[Arrbit] extracting repository ..." | tee -a "$LOG_FILE"
unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR" >> "$LOG_FILE" 2>&1

# ------------------ COPY CODE ------------------
cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICE_DIR/"

[ -d "$TMP_DIR/Arrbit-main/universal/helpers" ]    && cp -rf "$TMP_DIR/Arrbit-main/universal/helpers/"*    "$HELPERS_DIR/"
[ -d "$TMP_DIR/Arrbit-main/universal/connectors" ] && cp -rf "$TMP_DIR/Arrbit-main/universal/connectors/"* "$CONNECTORS_DIR/"

chmod -R 777 "$SERVICE_DIR"
echo "[Arrbit] modules, helpers, connectors copied" | tee -a "$LOG_FILE"

# ----- Strip .bash from service scripts -----
if [ -d "$SERVICE_DIR/services" ]; then
  for f in "$SERVICE_DIR/services/"*.bash; do
    [ -e "$f" ] || break
    mv "$f" "${f%.bash}"
    chmod 777 "${f%.bash}"
  done
fi

# ------------------ COPY DEFAULT CONFIGS (if missing) ------------------
for cfg in arrbit-config.conf beets-config.yaml; do
  src_cfg="$TMP_DIR/Arrbit-main/lidarr/config/$cfg"
  if [ -f "$src_cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    cp "$src_cfg" "$CONFIG_DIR/"
    chmod 666 "$CONFIG_DIR/$cfg"
    echo "[Arrbit] $cfg added to config directory" | tee -a "$LOG_FILE"
  fi
done

# ------------------ CLEANUP ------------------
rm -rf "$TMP_DIR"
chmod -R 777 "$LOG_DIR" "$CONFIG_DIR" "$SERVICE_DIR" || true
echo "[Arrbit] Setup complete – log saved in $LOG_DIR"
echo "[Arrbit] See config settings to enable Arrbit, everything is off by default."

# ------------------ HOLD CONTAINER ------------------
sleep infinity

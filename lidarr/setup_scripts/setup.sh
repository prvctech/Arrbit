#!/usr/bin/env bash
#
# Arrbit initial setup script
# Version: v1.14
# Author: prvctech
# Purpose: Download arrbit-config.conf & beets-config.yaml once; always refresh other scripts/modules
# ---------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
BASE_URL="https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr"

echo -e "🚀  ${ARRBIT_TAG} Starting initial setup run"

# -----------------------------------------------------------------------------
# 1) Ensure directory structure & permissions
# -----------------------------------------------------------------------------
mkdir -p /config/arrbit/{config,process_scripts,process_scripts/modules,setup_scripts}
chmod -R 777 /config/arrbit

# -----------------------------------------------------------------------------
# 2) Download arrbit-config.conf only if missing
# -----------------------------------------------------------------------------
CONF="/config/arrbit/config/arrbit-config.conf"
if [ ! -f "$CONF" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading arrbit-config.conf..."
  if curl -sfL "${BASE_URL}/config/arrbit-config.conf" -o "$CONF"; then
    echo -e "   • ✅ arrbit-config.conf saved"
    chmod 777 "$CONF"
  else
    echo -e "   • ⚠️ Failed to download arrbit-config.conf"
  fi
else
  echo -e "⏭️  ${ARRBIT_TAG} arrbit-config.conf exists; skipping download"
fi

# -----------------------------------------------------------------------------
# 2.5) Download beets-config.yaml only if missing
# -----------------------------------------------------------------------------
BEETS_CONF="/config/arrbit/config/beets-config.yaml"
if [ ! -f "$BEETS_CONF" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading beets-config.yaml..."
  if curl -sfL "${BASE_URL}/config/beets-config.yaml" -o "$BEETS_CONF"; then
    echo -e "   • ✅ beets-config.yaml saved"
    chmod 777 "$BEETS_CONF"
  else
    echo -e "   • ⚠️ Failed to download beets-config.yaml"
  fi
else
  echo -e "⏭️  ${ARRBIT_TAG} beets-config.yaml exists; skipping download"
fi

# -----------------------------------------------------------------------------
# 3) Source config so downstream modules get their flags
# -----------------------------------------------------------------------------
# shellcheck disable=SC1091
source "$CONF"

# -----------------------------------------------------------------------------
# 4) Always download core scripts
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Fetching core scripts..."
for file in tagger.bash functions.bash genre-whitelist.txt plugins_add.bash autoconfig.bash; do
  TARGET="/config/arrbit/process_scripts/${file}"
  curl -sfL "${BASE_URL}/process_scripts/${file}" -o "$TARGET" \
    && echo -e "   • ✅ ${file}" \
    || echo -e "   • ⚠️ ${file} failed"
  chmod 777 "$TARGET"
done

# -----------------------------------------------------------------------------
# 5) Always download modules
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Fetching modules..."
for mod in media_management.bash metadata_consumer.bash metadata_write.bash metadata_plugin.bash metadata_profiles.bash track_naming.bash ui_settings.bash custom_scripts.bash custom_formats.bash delay_profiles.bash quality_profile.bash; do
  TARGET="/config/arrbit/process_scripts/modules/${mod}"
  curl -sfL "${BASE_URL}/process_scripts/modules/${mod}" -o "$TARGET" \
    && echo -e "   • ✅ ${mod}" \
    || echo -e "   • ⚠️ ${mod} failed"
  chmod 777 "$TARGET"
done

# -----------------------------------------------------------------------------
# 6) Always download custom_formats folder
# -----------------------------------------------------------------------------
echo -e "📦  ${ARRBIT_TAG} Refreshing custom_formats..."
CF_DIR="/config/arrbit/process_scripts/modules/custom_formats"
TMP_ZIP="/tmp/arrbit_cf.zip"
TMP_DIR="/tmp/arrbit_cf"
curl -sfL -o "$TMP_ZIP" "https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip" \
  && { rm -rf "$CF_DIR"; unzip -q "$TMP_ZIP" -d "$TMP_DIR"; mv "$TMP_DIR"/Arrbit-main/lidarr/process_scripts/modules/custom_formats "$CF_DIR"; } \
  && echo -e "   • ✅ custom_formats updated" \
  || echo -e "   • ⚠️ custom_formats update failed"
chmod -R 777 "$CF_DIR"
rm -rf "$TMP_ZIP" "$TMP_DIR"

# -----------------------------------------------------------------------------
# 7) Always download dependencies script
# -----------------------------------------------------------------------------
echo -e "🔧  ${ARRBIT_TAG} Fetching dependencies script..."
DEP="/config/arrbit/setup_scripts/dependencies.bash"
curl -sfL "${BASE_URL}/setup_scripts/dependencies.bash" -o "$DEP" \
  && echo -e "   • ✅ dependencies.bash" \
  || echo -e "   • ⚠️ dependencies.bash failed"
chmod 777 "$DEP"

# -----------------------------------------------------------------------------
# 8) Run dependencies
# -----------------------------------------------------------------------------
echo -e "🛠️  ${ARRBIT_TAG} Running dependencies script..."
bash "$DEP" || echo -e "⚠️  ${ARRBIT_TAG} dependencies.bash failed"

# -----------------------------------------------------------------------------
# 9) Conditionally run plugins_add and autoconfig
# -----------------------------------------------------------------------------
if [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ]; then
  echo -e "🔌  ${ARRBIT_TAG} Running plugins_add.bash..."
  bash /config/arrbit/process_scripts/plugins_add.bash || echo -e "⚠️  ${ARRBIT_TAG} plugins_add.bash failed"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping plugins_add.bash"
fi

if [ "${ENABLE_AUTOCONFIG:-false}" = "true" ]; then
  echo -e "⚙️  ${ARRBIT_TAG} Running autoconfig.bash..."
  bash /config/arrbit/process_scripts/autoconfig.bash || echo -e "⚠️  ${ARRBIT_TAG} autoconfig.bash failed"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping autoconfig.bash"
fi

echo -e "✅  ${ARRBIT_TAG} Initial setup run complete!"
exit 0

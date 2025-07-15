#!/usr/bin/env bash
#
# Arrbit initial setup script
# Version: v1.11
# Author: prvctech
# Purpose: Download arrbit.conf once, but always refresh all other scripts & modules
# ---------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
BASE_URL="https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr"

echo -e "🚀  ${ARRBIT_TAG} Starting initial setup run"

# -----------------------------------------------------------------------------
# 1) Ensure directory structure & perms
# -----------------------------------------------------------------------------
mkdir -p /config/arrbit/{config,process_scripts,process_scripts/modules,setup_scripts}
chmod -R 777 /config/arrbit

# -----------------------------------------------------------------------------
# 2) Download arrbit.conf only if missing
# -----------------------------------------------------------------------------
CONF="/config/arrbit/config/arrbit.conf"
if [ ! -f "$CONF" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading arrbit.conf..."
  if curl -sfL "$BASE_URL/config/arrbit.conf" -o "$CONF"; then
    echo -e "   • ✅ arrbit.conf saved"
    chmod 777 "$CONF"
  else
    echo -e "   • ⚠️ Failed to download arrbit.conf"
  fi
else
  echo -e "⏭️  ${ARRBIT_TAG} arrbit.conf exists; skipping download"
fi

# -----------------------------------------------------------------------------
# 3) Source config & check ENABLE_ARRBIT
# -----------------------------------------------------------------------------
# shellcheck disable=SC1091
source "$CONF"
if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  echo -e "\n🚨  ${ARRBIT_TAG} Arrbit is NOT enabled!"
  echo -e "    Please edit ENABLE_ARRBIT=\"true\" in arrbit.conf to enable it."
  echo -e "    Then restart Lidarr to activate Arrbit.\n"
  # continue so logs show full setup
fi

# -----------------------------------------------------------------------------
# 4) Always download core scripts
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Fetching core scripts..."
for file in tagger.bash functions.bash beets-config.yaml genre-whitelist.txt plugins_add.bash autoconfig.bash; do
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
CF_DIR="/config/arrbit/process_scripts/modules/custom_formats"
echo -e "📦  ${ARRBIT_TAG} Refreshing custom_formats..."
tmp_zip="/tmp/arrbit_cf.zip"
tmp_dir="/tmp/arrbit_cf"
curl -sfL -o "$tmp_zip" "https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip" \
  && { rm -rf "$CF_DIR"; unzip -q "$tmp_zip" -d "$tmp_dir"; \
       mv "$tmp_dir"/Arrbit-main/lidarr/process_scripts/modules/custom_formats "$CF_DIR"; } \
  && echo -e "   • ✅ custom_formats updated" \
  || echo -e "   • ⚠️ custom_formats update failed"
chmod -R 777 "$CF_DIR"
rm -rf "$tmp_zip" "$tmp_dir"

# -----------------------------------------------------------------------------
# 7) Always download dependencies script
# -----------------------------------------------------------------------------
DEP="/config/arrbit/setup_scripts/dependencies.bash"
echo -e "🔧  ${ARRBIT_TAG} Fetching dependencies script..."
curl -sfL "${BASE_URL}/setup_scripts/dependencies.bash" -o "$DEP" \
  && echo -e "   • ✅ dependencies.bash" \
  || echo -e "   • ⚠️ dependencies.bash failed"
chmod 777 "$DEP"

# -----------------------------------------------------------------------------
# 8) Run dependencies.bash if present
# -----------------------------------------------------------------------------
if [ -x "$DEP" ]; then
  echo -e "🛠️  ${ARRBIT_TAG} Running dependencies script..."
  bash "$DEP" || echo -e "⚠️  ${ARRBIT_TAG} dependencies.bash failed"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping dependencies.bash"
fi

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

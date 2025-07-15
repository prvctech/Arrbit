#!/usr/bin/env bash
#
# Arrbit initial setup script
# Version: v1.8
# Author: prvctech
# Purpose: Download Arrbit config & scripts, then verify ENABLE_ARRBIT and proceed
# ---------------------------------------------

set -euo pipefail

# Colored Arrbit tag for terminal visibility
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

echo -e "🚀  ${ARRBIT_TAG} Starting initial setup run"

# -----------------------------------------------------------------------------
# 1) Create all target folders
# -----------------------------------------------------------------------------
mkdir -p /config/arrbit/config \
         /config/arrbit/process_scripts \
         /config/arrbit/process_scripts/modules \
         /config/arrbit/setup_scripts

# -----------------------------------------------------------------------------
# 2) Always download arrbit.conf (from lidarr/config)
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Downloading arrbit.conf..."
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/config/arrbit.conf \
     -o /config/arrbit/config/arrbit.conf; then
  echo -e "✅  ${ARRBIT_TAG} arrbit.conf saved to /config/arrbit/config"
else
  echo -e "⚠️  ${ARRBIT_TAG} Failed to download arrbit.conf"
fi

# -----------------------------------------------------------------------------
# 2a) Source arrbit.conf
# -----------------------------------------------------------------------------
if [ ! -f /config/arrbit/config/arrbit.conf ]; then
  echo -e "⚠️  ${ARRBIT_TAG} arrbit.conf missing after download. Exiting."
  exit 1
fi
# shellcheck disable=SC1091
source /config/arrbit/config/arrbit.conf

# -----------------------------------------------------------------------------
# 2b) Master flag check: ENABLE_ARRBIT
# -----------------------------------------------------------------------------
if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  echo -e "\n🚨  ${ARRBIT_TAG} Arrbit is NOT enabled!"
  echo -e "    Please edit ENABLE_ARRBIT=\"true\" in arrbit.conf to enable it."
  echo -e "    Then restart Lidarr to activate Arrbit.\n"
  # continue so user sees full setup logs
fi

# -----------------------------------------------------------------------------
# 3) Download core scripts (including tagger.bash)
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Downloading core scripts..."
for file in \
  tagger.bash \
  functions.bash \
  beets-config.yaml \
  genre-whitelist.txt \
  plugins_add.bash \
  autoconfig.bash; do
  if curl -sfL \
       https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/${file} \
       -o /config/arrbit/process_scripts/${file}; then
    echo -e "   • ✅ ${file}"
  else
    echo -e "   • ⚠️ ${file} failed"
  fi
done

# -----------------------------------------------------------------------------
# 4) Download modules
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Downloading modules..."
for mod in \
  media_management.bash \
  metadata_consumer.bash \
  metadata_write.bash \
  metadata_plugin.bash \
  metadata_profiles.bash \
  track_naming.bash \
  ui_settings.bash \
  custom_scripts.bash \
  custom_formats.bash \
  delay_profiles.bash \
  quality_profile.bash; do
  if curl -sfL \
       https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/modules/${mod} \
       -o /config/arrbit/process_scripts/modules/${mod}; then
    echo -e "   • ✅ ${mod}"
  else
    echo -e "   • ⚠️ ${mod} failed"
  fi
done

# -----------------------------------------------------------------------------
# 5) Download custom_formats folder via zip
# -----------------------------------------------------------------------------
echo -e "📦  ${ARRBIT_TAG} Downloading custom_formats..."
tmp_zip="/tmp/arrbit_main.zip"
tmp_dir="/tmp/arrbit_extracted"
if curl -sfL -o "$tmp_zip" \
     https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip \
   && unzip -q "$tmp_zip" -d "$tmp_dir" \
   && cp -r "$tmp_dir"/Arrbit-main/lidarr/process_scripts/modules/custom_formats \
         /config/arrbit/process_scripts/modules/; then
  echo -e "   • ✅ custom_formats"
else
  echo -e "   • ⚠️ custom_formats failed"
fi
rm -rf "$tmp_zip" "$tmp_dir"

# -----------------------------------------------------------------------------
# 6) Download dependencies script
# -----------------------------------------------------------------------------
echo -e "🔧  ${ARRBIT_TAG} Downloading dependencies script..."
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/dependencies.bash \
     -o /config/arrbit/setup_scripts/dependencies.bash; then
  echo -e "   • ✅ dependencies.bash"
else
  echo -e "   • ⚠️ dependencies.bash failed"
fi

# -----------------------------------------------------------------------------
# 7) Make scripts executable
# -----------------------------------------------------------------------------
echo -e "🔒  ${ARRBIT_TAG} Setting execute permissions..."
chmod +x /config/arrbit/process_scripts/*.bash        2>/dev/null || true
chmod +x /config/arrbit/process_scripts/modules/*.bash 2>/dev/null || true
chmod +x /config/arrbit/setup_scripts/*.bash           2>/dev/null || true

# -----------------------------------------------------------------------------
# 8) Ensure permissive permissions
# -----------------------------------------------------------------------------
echo -e "🔑  ${ARRBIT_TAG} Setting 777 on config & plugins dirs..."
chmod -R 777 /config/arrbit 2>/dev/null || true
chmod -R 777 /config/plugins  2>/dev/null || true

# -----------------------------------------------------------------------------
# 9) Run dependencies.bash
# -----------------------------------------------------------------------------
if [ -x /config/arrbit/setup_scripts/dependencies.bash ]; then
  echo -e "🛠️  ${ARRBIT_TAG} Running dependencies script..."
  bash /config/arrbit/setup_scripts/dependencies.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} dependencies.bash failed, continuing"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping dependencies.bash (not executable)"
fi

# -----------------------------------------------------------------------------
# 10) Conditionally run plugins_add.bash
# -----------------------------------------------------------------------------
if [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ] && [ -x /config/arrbit/process_scripts/plugins_add.bash ]; then
  echo -e "🔌  ${ARRBIT_TAG} Running plugins_add.bash..."
  bash /config/arrbit/process_scripts/plugins_add.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} plugins_add.bash failed, continuing"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping plugins_add.bash"
fi

# -----------------------------------------------------------------------------
# 11) Conditionally run autoconfig.bash
# -----------------------------------------------------------------------------
if [ "${ENABLE_AUTOCONFIG:-false}" = "true" ] && [ -x /config/arrbit/process_scripts/autoconfig.bash ]; then
  echo -e "⚙️  ${ARRBIT_TAG} Running autoconfig.bash..."
  bash /config/arrbit/process_scripts/autoconfig.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} autoconfig.bash failed, continuing"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping autoconfig.bash"
fi

echo -e "✅  ${ARRBIT_TAG} Initial setup run complete!"
exit 0

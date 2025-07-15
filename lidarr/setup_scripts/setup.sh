#!/usr/bin/env bash
#
# Arrbit initial setup script
# Version: v1.2
# Author: prvctech
# Purpose: Download Arrbit config & scripts, then trigger setup if ENABLE_ARRBIT is true
# ---------------------------------------------

set -euo pipefail

# Colored Arrbit tag for better terminal visibility
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
# 2) Always download arrbit.conf
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Downloading arrbit.conf..."
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/config/arrbit.conf \
     -o /config/arrbit/config/arrbit.conf; then
  echo -e "✅  ${ARRBIT_TAG} arrbit.conf saved to /config/arrbit/config"
else
  echo -e "⚠️  ${ARRBIT_TAG} Failed to download arrbit.conf"
fi

# -----------------------------------------------------------------------------
# 2a) Source arrbit.conf
# -----------------------------------------------------------------------------
if [ -f /config/arrbit/config/arrbit.conf ]; then
  # shellcheck disable=SC1091
  source /config/arrbit/config/arrbit.conf
else
  echo -e "⚠️  ${ARRBIT_TAG} arrbit.conf missing after download. Exiting."
  exit 1
fi

# -----------------------------------------------------------------------------
# 2b) Master flag check
# -----------------------------------------------------------------------------
if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  echo -e "🚨  ${ARRBIT_TAG} ENABLE_ARRBIT not set to true."
  echo -e "    Please edit /config/arrbit/config/arrbit.conf and set:"
  echo -e "      ENABLE_ARRBIT=\"true\""
  echo -e "    Then restart Lidarr to enable Arrbit."
  exit 0
fi

# -----------------------------------------------------------------------------
# 3) Download all top-level process_scripts
# -----------------------------------------------------------------------------
echo -e "📥  ${ARRBIT_TAG} Downloading core scripts..."
for file in \
  ArrbitTagger.bash \
  functions.bash \
  beets-config.yaml \
  genre-whitelist.txt \
  plugins_add.bash \
  autoconfig.bash; do
  curl -sfL \
    https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/${file} \
    -o /config/arrbit/process_scripts/${file} \
    && echo -e "   • ${file} downloaded" \
    || echo -e "   • ⚠️ Failed: ${file}"
done

# -----------------------------------------------------------------------------
# 4) Download each core module under modules/
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
  curl -sfL \
    https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/modules/${mod} \
    -o /config/arrbit/process_scripts/modules/${mod} \
    && echo -e "   • ${mod} downloaded" \
    || echo -e "   • ⚠️ Failed: ${mod}"
done

# -----------------------------------------------------------------------------
# 5) Download custom_formats folder via zip
# -----------------------------------------------------------------------------
echo -e "📦  ${ARRBIT_TAG} Downloading custom_formats folder..."
tmp_zip="/tmp/arrbit_main.zip"
tmp_dir="/tmp/arrbit_extracted"
curl -sfL -o "$tmp_zip" https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip \
  && unzip -q "$tmp_zip" -d "$tmp_dir" \
  && cp -r "$tmp_dir"/Arrbit-main/lidarr/process_scripts/modules/custom_formats \
        /config/arrbit/process_scripts/modules/ \
  && echo -e "✅  ${ARRBIT_TAG} custom_formats folder downloaded" \
  || echo -e "⚠️  ${ARRBIT_TAG} Failed custom_formats download"
rm -rf "$tmp_zip" "$tmp_dir"

# -----------------------------------------------------------------------------
# 6) Download dependencies script
# -----------------------------------------------------------------------------
echo -e "🔧  ${ARRBIT_TAG} Downloading dependencies script..."
curl -sfL \
  https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/dependencies.bash \
  -o /config/arrbit/setup_scripts/dependencies.bash \
  && echo -e "✅  ${ARRBIT_TAG} dependencies.bash downloaded" \
  || echo -e "⚠️  ${ARRBIT_TAG} Failed to download dependencies.bash"

# -----------------------------------------------------------------------------
# 7) Make all .bash scripts executable
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
# 9) Run dependencies.bash (always)
# -----------------------------------------------------------------------------
if [ -x /config/arrbit/setup_scripts/dependencies.bash ]; then
  echo -e "🛠️  ${ARRBIT_TAG} Running dependencies script..."
  bash /config/arrbit/setup_scripts/dependencies.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} dependencies.bash failed, continuing"
else
  echo -e "⏭️  ${ARRBIT_TAG} dependencies.bash not found or not executable. Skipping."
fi

# -----------------------------------------------------------------------------
# 10) Conditionally run plugins_add.bash
# -----------------------------------------------------------------------------
if [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ] && [ -x /config/arrbit/process_scripts/plugins_add.bash ]; then
  echo -e "🔌  ${ARRBIT_TAG} ENABLE_COMMUNITY_PLUGINS is true – running plugins_add.bash..."
  bash /config/arrbit/process_scripts/plugins_add.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} plugins_add.bash failed, continuing"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping plugins_add.bash (ENABLE_COMMUNITY_PLUGINS=${ENABLE_COMMUNITY_PLUGINS:-false})"
fi

# -----------------------------------------------------------------------------
# 11) Conditionally run autoconfig.bash
# -----------------------------------------------------------------------------
if [ "${ENABLE_AUTOCONFIG:-false}" = "true" ] && [ -x /config/arrbit/process_scripts/autoconfig.bash ]; then
  echo -e "⚙️  ${ARRBIT_TAG} ENABLE_AUTOCONFIG is true – running autoconfig.bash..."
  bash /config/arrbit/process_scripts/autoconfig.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} autoconfig.bash failed, continuing"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping autoconfig.bash (ENABLE_AUTOCONFIG=${ENABLE_AUTOCONFIG:-false})"
fi

echo -e "✅  ${ARRBIT_TAG} Initial setup run complete!"
exit 0

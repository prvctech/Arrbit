#!/usr/bin/env bash
#
# Arrbit initial setup script
# Version: v1.9
# Author: prvctech
# Purpose: Download Arrbit config & scripts once, set perms, then verify ENABLE_ARRBIT and proceed
# ---------------------------------------------

set -euo pipefail

# Colored Arrbit tag for terminal visibility
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

echo -e "🚀  ${ARRBIT_TAG} Starting initial setup run"

# -----------------------------------------------------------------------------
# 1) Create & secure config folder
# -----------------------------------------------------------------------------
CONFIG_DIR="/config/arrbit/config"
mkdir -p "${CONFIG_DIR}"
chmod 777 "${CONFIG_DIR}"

# -----------------------------------------------------------------------------
# 2) Download arrbit.conf only if missing
# -----------------------------------------------------------------------------
CONF_FILE="${CONFIG_DIR}/arrbit.conf"
echo -e "📥  ${ARRBIT_TAG} Ensuring arrbit.conf exists..."
if [ ! -f "${CONF_FILE}" ]; then
  if curl -sfL \
       https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/config/arrbit.conf \
       -o "${CONF_FILE}"; then
    echo -e "✅  ${ARRBIT_TAG} arrbit.conf downloaded to ${CONF_FILE}"
    chmod 777 "${CONF_FILE}"
  else
    echo -e "⚠️  ${ARRBIT_TAG} Failed to download arrbit.conf"
  fi
else
  echo -e "⏭️  ${ARRBIT_TAG} arrbit.conf already exists; skipping download"
fi

# -----------------------------------------------------------------------------
# 3) Source arrbit.conf & check ENABLE_ARRBIT
# -----------------------------------------------------------------------------
if [ ! -f "${CONF_FILE}" ]; then
  echo -e "⚠️  ${ARRBIT_TAG} arrbit.conf missing. Exiting."
  exit 1
fi
# shellcheck disable=SC1091
source "${CONF_FILE}"

if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  echo -e "\n🚨  ${ARRBIT_TAG} Arrbit is NOT enabled!"
  echo -e "    Please edit ENABLE_ARRBIT=\"true\" in arrbit.conf to enable it."
  echo -e "    Then restart Lidarr to activate Arrbit.\n"
  # continue so user sees full setup logs
fi

# -----------------------------------------------------------------------------
# 4) Create & secure other script folders
# -----------------------------------------------------------------------------
mkdir -p /config/arrbit/process_scripts \
         /config/arrbit/process_scripts/modules \
         /config/arrbit/setup_scripts
chmod -R 777 /config/arrbit/process_scripts \
             /config/arrbit/process_scripts/modules \
             /config/arrbit/setup_scripts

# -----------------------------------------------------------------------------
# 5) Download core scripts (tagger.bash, etc.)
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
    chmod 777 "/config/arrbit/process_scripts/${file}"
  else
    echo -e "   • ⚠️ ${file} failed"
  fi
done

# -----------------------------------------------------------------------------
# 6) Download modules
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
    chmod 777 "/config/arrbit/process_scripts/modules/${mod}"
  else
    echo -e "   • ⚠️ ${mod} failed"
  fi
done

# -----------------------------------------------------------------------------
# 7) Download custom_formats folder once
# -----------------------------------------------------------------------------
CUSTOM_DIR="/config/arrbit/process_scripts/modules/custom_formats"
if [ ! -d "${CUSTOM_DIR}" ]; then
  echo -e "📦  ${ARRBIT_TAG} Downloading custom_formats..."
  tmp_zip="/tmp/arrbit_main.zip"
  tmp_dir="/tmp/arrbit_extracted"
  if curl -sfL -o "$tmp_zip" \
       https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip \
     && unzip -q "$tmp_zip" -d "$tmp_dir" \
     && cp -r "$tmp_dir"/Arrbit-main/lidarr/process_scripts/modules/custom_formats "${CUSTOM_DIR}"; then
    echo -e "   • ✅ custom_formats"
    chmod -R 777 "${CUSTOM_DIR}"
  else
    echo -e "   • ⚠️ custom_formats failed"
  fi
  rm -rf "$tmp_zip" "$tmp_dir"
else
  echo -e "⏭️  ${ARRBIT_TAG} custom_formats already exists; skipping"
fi

# -----------------------------------------------------------------------------
# 8) Download dependencies script
# -----------------------------------------------------------------------------
echo -e "🔧  ${ARRBIT_TAG} Downloading dependencies script..."
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/dependencies.bash \
     -o /config/arrbit/setup_scripts/dependencies.bash; then
  echo -e "   • ✅ dependencies.bash"
  chmod 777 /config/arrbit/setup_scripts/dependencies.bash
else
  echo -e "   • ⚠️ dependencies.bash failed"
fi

# -----------------------------------------------------------------------------
# 9) Run dependencies.bash
# -----------------------------------------------------------------------------
if [ -x /config/arrbit/setup_scripts/dependencies.bash ]; then
  echo -e "🛠️  ${ARRBIT_TAG} Running dependencies script..."
  bash /config/arrbit/setup_scripts/dependencies.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} dependencies.bash failed"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping dependencies.bash"
fi

# -----------------------------------------------------------------------------
# 10) Conditionally run plugins_add.bash
# -----------------------------------------------------------------------------
if [ "${ENABLE_COMMUNITY_PLUGINS:-false}" = "true" ] && [ -x /config/arrbit/process_scripts/plugins_add.bash ]; then
  echo -e "🔌  ${ARRBIT_TAG} Running plugins_add.bash..."
  bash /config/arrbit/process_scripts/plugins_add.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} plugins_add.bash failed"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping plugins_add.bash"
fi

# -----------------------------------------------------------------------------
# 11) Conditionally run autoconfig.bash
# -----------------------------------------------------------------------------
if [ "${ENABLE_AUTOCONFIG:-false}" = "true" ] && [ -x /config/arrbit/process_scripts/autoconfig.bash ]; then
  echo -e "⚙️  ${ARRBIT_TAG} Running autoconfig.bash..."
  bash /config/arrbit/process_scripts/autoconfig.bash \
    || echo -e "⚠️  ${ARRBIT_TAG} autoconfig.bash failed"
else
  echo -e "⏭️  ${ARRBIT_TAG} Skipping autoconfig.bash"
fi

echo -e "✅  ${ARRBIT_TAG} Initial setup run complete!"
exit 0

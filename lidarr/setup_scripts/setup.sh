#!/usr/bin/env bash
set -euo pipefail

echo "*** [Arrbit] Starting initial setup run ***"

# 1) Create all target folders
mkdir -p /config/arrbit/config \
         /config/arrbit/process_scripts \
         /config/arrbit/process_scripts/modules \
         /config/arrbit/setup_scripts

# 2) Download arrbit.conf
echo "*** [Arrbit] Downloading config files ***"
if [ ! -f /config/arrbit/config/arrbit.conf ]; then
  curl -sfL \
    https://raw.githubusercontent.com/prvctech/Arrbit/main/config/arrbit.conf \
    -o /config/arrbit/config/arrbit.conf || true
  echo "*** [Arrbit] arrbit.conf downloaded. ***"
else
  echo "*** [Arrbit] arrbit.conf already exists. Skipping download. ***"
fi

# 2a) Source arrbit.conf so we can read your flags
if [ -f /config/arrbit/config/arrbit.conf ]; then
  # shellcheck disable=SC1091
  . /config/arrbit/config/arrbit.conf
fi

# 3) Download all top‑level process_scripts
echo "*** [Arrbit] Downloading process_scripts files ***"
for file in \
  ArrbitTagger.bash \
  functions.bash \
  beets-config.yaml \
  genre-whitelist.txt \
  plugins_add.bash \
  autoconfig.bash
do
  curl -sfL \
    https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/${file} \
    -o /config/arrbit/process_scripts/${file} || true
done

# 4) Download each core module under modules/, including all the new ones
echo "*** [Arrbit] Downloading autoconfig modules ***"
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
  quality_profile.bash
do
  curl -sfL \
    https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/process_scripts/modules/${mod} \
    -o /config/arrbit/process_scripts/modules/${mod} || true
done

# 5) Download custom_formats folder (all JSONs) in one go via zip
echo "*** [Arrbit] Downloading custom_formats folder from GitHub as zip ***"
tmp_zip="/tmp/arrbit_main.zip"
tmp_dir="/tmp/arrbit_extracted"
curl -sfL -o "$tmp_zip" \
     https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip
unzip -q "$tmp_zip" -d "$tmp_dir"
cp -r "$tmp_dir"/Arrbit-main/lidarr/process_scripts/modules/custom_formats \
      /config/arrbit/process_scripts/modules/
rm -rf "$tmp_zip" "$tmp_dir"
echo "*** [Arrbit] custom_formats folder downloaded and copied successfully! ***"

# 6) Download dependencies script
echo "*** [Arrbit] Downloading setup_scripts files ***"
curl -sfL \
  https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/dependencies.bash \
  -o /config/arrbit/setup_scripts/dependencies.bash || true

# 7) Make all .bash scripts executable
chmod +x /config/arrbit/process_scripts/*.bash        2>/dev/null || true
chmod +x /config/arrbit/process_scripts/modules/*.bash 2>/dev/null || true
chmod +x /config/arrbit/setup_scripts/*.bash           2>/dev/null || true

echo "*** [Arrbit] Config and scripts downloaded and organized successfully ***"

# 8) Ensure permissive permissions
echo "*** [Arrbit] Setting 777 permissions on /config/arrbit and /config/plugins ***"
chmod -R 777 /config/arrbit 2>/dev/null || true
chmod -R 777 /config/plugins  2>/dev/null || true

# 9) Run dependencies.bash (always)
if [ -x /config/arrbit/setup_scripts/dependencies.bash ]; then
  echo "*** [Arrbit] Running dependencies script... ***"
  bash /config/arrbit/setup_scripts/dependencies.bash \
    || echo "⚠ dependencies.bash failed, continuing"
else
  echo "*** [Arrbit] dependencies.bash not found or not executable. Skipping. ***"
fi

# 10) Conditionally run plugins_add.bash
if [ "${INSTALL_COMMUNITY_PLUGINS:-false}" = "true" ] \
   && [ -x /config/arrbit/process_scripts/plugins_add.bash ]; then
  echo "*** [Arrbit] INSTALL_COMMUNITY_PLUGINS is true – running plugins_add.bash... ***"
  bash /config/arrbit/process_scripts/plugins_add.bash \
    || echo "⚠ plugins_add.bash failed, continuing"
else
  echo "*** [Arrbit] Skipping plugins_add.bash (INSTALL_COMMUNITY_PLUGINS=${INSTALL_COMMUNITY_PLUGINS:-false}) ***"
fi

# 11) Conditionally run autoconfig.bash
if [ "${INSTALL_AUTOCONFIG:-false}" = "true" ] \
   && [ -x /config/arrbit/process_scripts/autoconfig.bash ]; then
  echo "*** [Arrbit] INSTALL_AUTOCONFIG is true – running autoconfig.bash... ***"
  bash /config/arrbit/process_scripts/autoconfig.bash \
    || echo "⚠ autoconfig.bash failed, continuing"
else
  echo "*** [Arrbit] Skipping autoconfig.bash (INSTALL_AUTOCONFIG=${INSTALL_AUTOCONFIG:-false}) ***"
fi

echo "*** [Arrbit] Initial run completed! ***"
exit 0

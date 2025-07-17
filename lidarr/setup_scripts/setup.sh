#!/usr/bin/env bash
#
# Arrbit Setup Bootstrap
# Version: v1.22
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
BASE_URL="https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr"

echo -e "🚀  ${ARRBIT_TAG} Running initial Arrbit setup..."

# 1. FOLDER STRUCTURE -------------------------------------------------------------------
echo -e "📁  ${ARRBIT_TAG} Ensuring folder structure is created"
mkdir -p /config/arrbit/{config,process_scripts}
mkdir -p /config/arrbit/process_scripts/modules/json_values
chmod -R 777 /config/arrbit

# 2. DOWNLOAD FILES ---------------------------------------------------------------------

# 2.1 Download arrbit-config.conf (only if not present)
CONF="/config/arrbit/config/arrbit-config.conf"
if [ ! -f "$CONF" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading arrbit-config.conf..."
  curl -sfL "${BASE_URL}/config/arrbit-config.conf" -o "$CONF" \
    && echo -e "    • ✅ arrbit-config.conf saved"
  chmod 777 "$CONF"
else
  echo -e "⏩  ${ARRBIT_TAG} arrbit-config.conf exists; skipping download"
fi

# 2.2 Download beets-config.yaml (only if not present)
BEETS="/config/arrbit/config/beets-config.yaml"
if [ ! -f "$BEETS" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading beets-config.yaml..."
  curl -sfL "${BASE_URL}/config/beets-config.yaml" -o "$BEETS" \
    && echo -e "    • ✅ beets-config.yaml saved"
  chmod 777 "$BEETS"
else
  echo -e "⏩  ${ARRBIT_TAG} beets-config.yaml exists; skipping download"
fi

# 2.3 Download metadata_profiles_master.json (only if not present)
MP_JSON="/config/arrbit/process_scripts/modules/json_values/metadata_profiles_master.json"
if [ ! -f "$MP_JSON" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading metadata_profiles_master.json..."
  curl -sfL "${BASE_URL}/process_scripts/modules/json_values/metadata_profiles_master.json" -o "$MP_JSON" \
    && echo -e "    • ✅ metadata_profiles_master.json saved"
  chmod 777 "$MP_JSON"
else
  echo -e "⏩  ${ARRBIT_TAG} metadata_profiles_master.json exists; skipping download"
fi

# 2.4 Download custom_formats_master.json (only if not present)
CF_JSON="/config/arrbit/process_scripts/modules/json_values/custom_formats_master.json"
if [ ! -f "$CF_JSON" ]; then
  echo -e "📥  ${ARRBIT_TAG} Downloading custom_formats_master.json..."
  curl -sfL "${BASE_URL}/process_scripts/modules/json_values/custom_formats_master.json" -o "$CF_JSON" \
    && echo -e "    • ✅ custom_formats_master.json saved"
  chmod 777 "$CF_JSON"
else
  echo -e "⏩  ${ARRBIT_TAG} custom_formats_master.json exists; skipping download"
fi

# 3. DOWNLOAD CORE FILES ----------------------------------------------------------------

echo -e "📁  ${ARRBIT_TAG} Syncing Arrbit modules/scripts from GitHub..."

FILES=(
  functions.bash
  autoconfig.bash
  plugins_add.bash
  dependencies.bash
  tagger.bash
  genre-whitelist.txt
)

MODULES=$(curl -s https://api.github.com/repos/prvctech/Arrbit/contents/lidarr/process_scripts/modules | jq -r '.[] | select(.name | endswith(".bash")) | .name')

for file in "${FILES[@]}"; do
  curl -sfL "${BASE_URL}/process_scripts/${file}" -o "/config/arrbit/process_scripts/${file}" \
    && echo -e "    • ✅ ${file} updated"
done

for mod in $MODULES; do
  curl -sfL "${BASE_URL}/process_scripts/modules/${mod}" -o "/config/arrbit/process_scripts/modules/${mod}" \
    && echo -e "    • ✅ ${mod} updated"
done

chmod -R 777 /config/arrbit/process_scripts

# 4. DEPENDENCY BOOTSTRAP ----------------------------------------------------------------

DEP="/config/arrbit/process_scripts/dependencies.bash"

if [ ! -f /config/arrbit/.dependencies_installed ]; then
  echo -e "🛠️   ${ARRBIT_TAG} Running dependencies script (first-time setup)..."
  bash "$DEP" \
    && echo -e "    • ✅ dependencies.bash executed"
  echo -e "⏩  ${ARRBIT_TAG} Skipping plugin install and autoconfig (waiting for next restart)"
else
  echo -e "🔁  ${ARRBIT_TAG} Dependencies already installed; continuing..."

  # 5. PLUGIN INSTALL --------------------------------------------------------------------
  echo -e "✨  ${ARRBIT_TAG} Checking plugin install flag..."
  if [ "$(grep -i 'ENABLE_COMMUNITY_PLUGINS=true' "$CONF")" ]; then
    bash /config/arrbit/process_scripts/plugins_add.bash
  else
    echo -e "⏩  ${ARRBIT_TAG} Plugin install flag disabled"
  fi

  # 6. AUTOCONFIG MODULE -----------------------------------------------------------------
  echo -e "✨  ${ARRBIT_TAG} Checking autoconfig flag..."
  if [ "$(grep -i 'ENABLE_AUTOCONFIG=true' "$CONF")" ]; then
    bash /config/arrbit/process_scripts/autoconfig.bash
  else
    echo -e "⏩  ${ARRBIT_TAG} Autoconfig flag disabled"
  fi
fi

# 7. FINAL THANK YOU ---------------------------------------------------------------------
echo -e "✨  ${ARRBIT_TAG} Thank you for using Arrbit!"
echo -e "✨  ${ARRBIT_TAG} To configure which modules run, edit: /config/arrbit/config/arrbit-config.conf"

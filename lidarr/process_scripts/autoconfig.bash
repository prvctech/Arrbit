#!/usr/bin/env bash
set -euo pipefail

ARRBIT_CONF=/config/arrbit/config/arrbit.conf
if [ ! -f "$ARRBIT_CONF" ]; then
  echo "*** [Arrbit] ERROR: arrbit.conf not found at $ARRBIT_CONF. Exiting. ***"
  exit 1
fi

# Load user’s flags
source "$ARRBIT_CONF"

echo "*** [Arrbit] Starting auto‑configuration run ***"

# Master toggle
if [ "${INSTALL_AUTOCONFIG:-false}" != "true" ]; then
  echo "*** [Arrbit] Auto‑configuration disabled (INSTALL_AUTOCONFIG=$INSTALL_AUTOCONFIG). Exiting. ***"
  exit 0
fi

# 1) Media Management
if [ "${CONFIGURE_MEDIA_MANAGEMENT:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Media Management ***"
  bash -c "/config/arrbit/process_scripts/modules/media_management.bash" \
    || echo "⚠ media_management.bash failed, continuing"
fi

# 2) Metadata Consumer
if [ "${CONFIGURE_METADATA_CONSUMER:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Metadata Consumer ***"
  bash -c "/config/arrbit/process_scripts/modules/metadata_consumer.bash" \
    || echo "⚠ metadata_consumer.bash failed, continuing"
fi

# 3) Metadata Provider / Write
if [ "${CONFIGURE_METADATA_PROVIDER:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Metadata Provider (write) ***"
  bash -c "/config/arrbit/process_scripts/modules/metadata_write.bash" \
    || echo "⚠ metadata_write.bash failed, continuing"
fi

# 4) Plugin‑specific Metadata
if [ "${CONFIGURE_PLUGIN_METADATA:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Plugin Metadata ***"
  bash -c "/config/arrbit/process_scripts/modules/metadata_plugin.bash" \
    || echo "⚠ metadata_plugin.bash failed, continuing"
fi

# 5) Metadata Profiles
if [ "${CONFIGURE_METADATA_PROFILES:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Metadata Profiles ***"
  bash -c "/config/arrbit/process_scripts/modules/metadata_profiles.bash" \
    || echo "⚠ metadata_profiles.bash failed, continuing"
fi

# 6) Track Naming
if [ "${CONFIGURE_TRACK_NAMING:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Track Naming ***"
  bash -c "/config/arrbit/process_scripts/modules/track_naming.bash" \
    || echo "⚠ track_naming.bash failed, continuing"
fi

# 7) UI Settings
if [ "${CONFIGURE_UI_SETTINGS:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring UI Settings ***"
  bash -c "/config/arrbit/process_scripts/modules/ui_settings.bash" \
    || echo "⚠ ui_settings.bash failed, continuing"
fi

# 8) Custom Scripts
if [ "${CONFIGURE_CUSTOM_SCRIPTS:-false}" = "true" ]; then
  echo "*** [Arrbit] Running Custom Scripts ***"
  bash -c "/config/arrbit/process_scripts/modules/custom_scripts.bash" \
    || echo "⚠ custom_scripts.bash failed, continuing"
fi

# 9) Custom Formats
if [ "${CONFIGURE_CUSTOM_FORMATS:-false}" = "true" ]; then
  echo "*** [Arrbit] Configuring Custom Formats ***"
  bash -c "/config/arrbit/process_scripts/modules/custom_formats.bash" \
    || echo "⚠ custom_formats.bash failed, continuing"
fi

echo "*** [Arrbit] Auto‑configuration run complete! ***"
exit 0

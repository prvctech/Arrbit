#!/usr/bin/env bash
#
# Arrbit initial run hook
# Version: v1.3
# Author: prvctech
# Purpose: Fetch & execute setup.sh, then force-enable prompt into Lidarr logs
# ---------------------------------------------

set -euo pipefail

# Coloured Arrbit tag
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

echo -e "🚀  ${ARRBIT_TAG} Starting Arrbit initial setup run"

# 1) Fetch & run setup.sh from GitHub
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/setup.sh \
     | bash -s; then
  echo -e "✅  ${ARRBIT_TAG} Remote setup.sh executed"
else
  echo -e "⚠️  ${ARRBIT_TAG} Remote setup.sh failed (expected if Arrbit isn’t enabled)" >&2
fi

# 2) If Arrbit is not enabled, force the prompt into both stderr and Lidarr UI logs
if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  PROMPT="🔔  ${ARRBIT_TAG} Please edit ENABLE_ARRBIT=\"true\" in arrbit.conf to enable Arrbit. Then restart Lidarr to activate Arrbit."
  # stderr for container logs
  echo -e "\n🚨  ${PROMPT}\n" >&2
  # append to Lidarr’s log file for UI
  mkdir -p /config/logs
  echo "$(date '+%Y-%m-%d %H:%M:%S') :: ${ARRBIT_TAG} :: INFO :: ${PROMPT}" \
    >> /config/logs/logback.txt
fi

exit 0

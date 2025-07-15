#!/usr/bin/env bash
#
# /etc/cont-init.d/01-arrbit-setup.sh
# Runs before any services do, so its output is the very first thing you see.
set -euo pipefail

ARBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# 1) Fetch & exec setup
echo -e "🚀  ${ARBIT_TAG} Running Arrbit setup…"
curl -fsSL \
  https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/setup.sh \
  | bash -s || true

# 2) If not enabled, print the prompt immediately
if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  echo -e "\n🚨  ${ARBIT_TAG} Arrbit is NOT enabled!"
  echo -e "    Please edit ENABLE_ARRBIT=\"true\" in arrbit.conf to enable it."
  echo -e "    Then restart Lidarr to activate Arrbit.\n"
fi

exit 0

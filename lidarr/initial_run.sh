#!/usr/bin/env bash
#
# Arrbit initial setup hook (cont-init.d)
# Runs before any service starts so messages appear in the console
# ---------------------------------------------

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

# 1) Run the remote setup script
echo -e "🚀  ${ARRBIT_TAG} Fetching and running setup.sh…"
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/setup.sh \
     | bash -s; then
  echo -e "✅  ${ARRBIT_TAG} setup.sh finished"
else
  echo -e "⚠️  ${ARRBIT_TAG} setup.sh failed (this is OK if Arrbit isn’t enabled)" >&2
fi

# 2) If Arrbit isn’t enabled, force the prompt now—before Lidarr starts
if [ "${ENABLE_ARRBIT:-false}" != "true" ]; then
  echo -e "\n🚨  ${ARRBIT_TAG} Arrbit is NOT enabled!"
  echo -e "    Please edit ENABLE_ARRBIT=\"true\" in arrbit.conf to enable it."
  echo -e "    Then restart Lidarr to activate Arrbit.\n"
fi

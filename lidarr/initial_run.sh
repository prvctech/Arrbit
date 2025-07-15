#!/usr/bin/env bash
#
# Arrbit initial run hook
# Version: v1.2
# Author: prvctech
# Purpose: Fetch and execute setup.sh directly from GitHub without local download
# ---------------------------------------------

set -euo pipefail

# Colored Arrbit tag for terminal visibility
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

echo -e "🚀  ${ARRBIT_TAG} Starting Arrbit initial setup run"

# -----------------------------------------------------------------------------
# Fetch & execute setup.sh from GitHub
# -----------------------------------------------------------------------------
if curl -sfL \
     https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/setup.sh \
     | bash -s; then
  echo -e "✅  ${ARRBIT_TAG} Remote setup.sh executed successfully"
else
  echo -e "⚠️  ${ARRBIT_TAG} Remote setup.sh execution failed (this may be expected if Arrbit isn’t enabled)" >&2
fi

exit 0

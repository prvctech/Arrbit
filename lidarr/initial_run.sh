#!/usr/bin/env bash

set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"

echo -e "🚀  ${ARRBIT_TAG} Starting initial setup run"

# Fetch & execute setup.sh from GitHub
curl -sfL \
  https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr/setup_scripts/setup.sh \
  | bash -s

exit 0

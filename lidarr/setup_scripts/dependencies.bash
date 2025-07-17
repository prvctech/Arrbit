#!/usr/bin/env bash
#
# Arrbit Dependencies Installer
# Version: v1.2
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

echo "🔧  Installing dependencies..."

apk add --no-cache jq curl bash coreutils unzip git

# Mark setup complete
touch /config/arrbit/.dependencies_installed
chmod 666 /config/arrbit/.dependencies_installed

echo "✅  Dependencies installed and marker file created"

#!/usr/bin/with-contenv bash
#
# Arrbit Dependencies Installer
# Version: v1.2
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

echo "🔧  Installing dependencies..."

apk add --no-cache jq curl bash coreutils unzip git

echo "✅  Dependencies installed

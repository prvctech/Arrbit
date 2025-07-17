#!/usr/bin/with-contenv bash
#
# Arrbit Dependencies Installer
# Version: v1.2
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Redirect all output to Docker logs, unbuffered
exec > >(tee /dev/stderr) 2>&1

echo "🔧  Installing dependencies..."

apk add --no-cache jq curl bash coreutils unzip git

# Mark setup complete
touch /config/arrbit/.dependencies_installed
chmod 666 /config/arrbit/.dependencies_installed

echo "✅  Dependencies installed and marker file created"

# Add a finish marker for debug/diagnostic purposes
echo "💡 deps script finished at $(date '+%T')"

# Optional: tiny pause to allow output to flush before exit
sleep 0.5

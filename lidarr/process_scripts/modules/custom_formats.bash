#!/usr/bin/env bash
set -euo pipefail

echo "*** [Arrbit] Processing custom formats modules... ***"

MODULES_DIR="/config/arrbit/process_scripts/modules/custom_formats"
LIDARR_API_KEY="${LIDARR_API_KEY:-}"
LIDARR_URL="${LIDARR_URL:-http://localhost:8686/api/v1}"

if [ -z "$LIDARR_API_KEY" ]; then
  echo "✖ LIDARR_API_KEY not set. Skipping custom formats."
  exit 0
fi

for json_file in "$MODULES_DIR"/*.json; do
  [ -e "$json_file" ] || continue

  echo "→ Adding custom format: $(basename "$json_file")"

  curl -sfL -H "X-Api-Key: $LIDARR_API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$json_file" \
    "$LIDARR_URL/customformat" \
    && echo "✔ Successfully added $(basename "$json_file")" \
    || echo "⚠ Failed to add $(basename "$json_file")"
done

echo "*** [Arrbit] All custom formats processed. ***"

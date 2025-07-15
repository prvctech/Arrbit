#!/usr/bin/env bash
#
# Module: Custom Formats
# Version: v0.7
# Author: prvctech
# ---------------------------------------------

set -euo pipefail

# Shared helpers
source /config/arrbit/process_scripts/functions.bash

# Discover & wait for Lidarr API
getArrAppInfo
verifyApiAccess

HEADER=( "-H" "X-Api-Key: ${arrApiKey}" "-H" "Content-Type: application/json" )

if [ "${CONFIGURE_CUSTOM_FORMATS,,}" != "true" ]; then
  log "⏭️  [Arrbit] Skipping Custom Formats"
  exit 0
fi

log "⚙️  [Arrbit] Starting Custom Formats import..."

MODULES_DIR="/config/arrbit/process_scripts/modules/custom_formats"

# Fetch existing formats
existing_formats=$(curl -s --fail --retry 3 --retry-delay 2 "${arrUrl}/api/${arrApiVersion}/customformat" "${HEADER[@]}")

for json_file in "$MODULES_DIR"/*.json; do
  [ -e "$json_file" ] || continue
  name=$(jq -r '.name' < "$json_file")

  # Validate required fields
  if ! jq 'has("specifications") and has("name")' "$json_file" | grep -q true; then
    log "⚠️  [Arrbit] Skipping '$json_file': Missing required fields."
    continue
  fi

  log "→ Processing custom format '$name'"

  id=$(jq -r ".[] | select(.name==\"$name\") | .id" <<<"$existing_formats")
  if [[ -n "$id" && "$id" != "null" ]]; then
    log "🗑️  [Arrbit] Deleting existing '$name' (ID: $id)..."
    curl -s --fail -X DELETE "${arrUrl}/api/${arrApiVersion}/customformat/$id" "${HEADER[@]}" \
      && log "✅  [Arrbit] Deleted '$name'" \
      || log "⚠️  [Arrbit] Failed deleting '$name'"
  fi

  log "➕  [Arrbit] Adding custom format '$name'..."
  response=$(curl -s -w "%{http_code}" -o /tmp/arrbit_cf_resp.txt \
    -X POST "${arrUrl}/api/${arrApiVersion}/customformat" \
    "${HEADER[@]}" \
    --data-binary @"$json_file")

  http_code=$(tail -c 3 <<<"$response")
  body=$(cat /tmp/arrbit_cf_resp.txt)

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    log "✅  [Arrbit] Added '$name'"
  else
    log "⚠️  [Arrbit] Failed adding '$name' (HTTP $http_code): $body"
  fi

done

log "✅  [Arrbit] Custom Formats import complete"
exit 0

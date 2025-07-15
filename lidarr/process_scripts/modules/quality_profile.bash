#!/usr/bin/env bash
#
# Module: Quality Profile
# Version: v0.4
# Author: prvctech
# ---------------------------------------------

# Identify this script for shared logging
scriptName="quality_profile"
scriptVersion="v0.4"

set -euo pipefail

# Bring in shared helpers (logging, config flags)
source /config/arrbit/process_scripts/functions.bash

# Discover Lidarr endpoint & API key
getArrAppInfo
# Wait for API readiness
verifyApiAccess

# Prepare HTTP headers for API calls
HEADER=( "-H" "X-Api-Key: ${arrApiKey}" "-H" "Content-Type: application/json" )

if [ "${CONFIGURE_QUALITY_PROFILE,,}" = "true" ]; then
  log "⚙️   [Arrbit] Starting Quality Profile configuration..."

  # 1) Fetch existing profiles
  existing_profiles=$(curl -s --fail --retry 3 --retry-delay 2 \
                       "${arrUrl}/api/${arrApiVersion}/qualityprofile" \
                       -H "X-Api-Key: ${arrApiKey}")

  # 2) Load & normalize default profiles JSON (to delete)
  default_raw=$(cat /config/arrbit/process_scripts/modules/json_values/quality_profiles-default_values-remove.json)
  default_profiles_json=$(jq -c . <<<"[${default_raw}]")

  # 3) Delete each default profile by name if it exists
  for name in $(jq -r '.[].name' <<<"$default_profiles_json"); do
    id=$(jq -r ".[] | select(.name==\"$name\") | .id" <<<"$existing_profiles")
    if [[ -n "$id" && "$id" != "null" ]]; then
      log "⚙️   [Arrbit] Deleting default profile '$name' (ID: $id)..."
      curl -s --fail --retry 3 --retry-delay 2 \
           -X DELETE \
           "${arrUrl}/api/${arrApiVersion}/qualityprofile/$id" \
           -H "X-Api-Key: ${arrApiKey}" \
        && log "✅  [Arrbit] Deleted profile '$name'" \
        || log "⚠️   [Arrbit] Failed deleting profile '$name'"
    fi
  done

  # 4) Load & normalize fallback profiles JSON (to add/update)
  fallback_raw=$(cat /config/arrbit/process_scripts/modules/json_values/quality_profiles-values_to_add_missing_values.json)
  fallback_profiles_json=$(jq -c . <<<"[${fallback_raw}]")

  # 5) For each fallback profile, update if exists else create it
  for profile in $(jq -c '.[]' <<<"$fallback_profiles_json"); do
    pname=$(jq -r '.name' <<<"$profile")
    exists=$(jq -r ".[] | select(.name==\"$pname\") | .id" <<<"$existing_profiles")

    if [[ -n "$exists" && "$exists" != "null" ]]; then
      log "⚙️   [Arrbit] Updating profile '$pname' (ID: $exists)..."
      curl -s --fail --retry 3 --retry-delay 2 \
           -X PUT \
           "${arrUrl}/api/${arrApiVersion}/qualityprofile/$exists" \
           "${HEADER[@]}" \
           --data-raw "$profile" \
        && log "✅  [Arrbit] Updated profile '$pname'" \
        || log "⚠️   [Arrbit] Failed updating profile '$pname'"
    else
      log "⚙️   [Arrbit] Creating profile '$pname'..."
      curl -s --fail --retry 3 --retry-delay 2 \
           -X POST \
           "${arrUrl}/api/${arrApiVersion}/qualityprofile" \
           "${HEADER[@]}" \
           --data-raw "$profile" \
        && log "✅  [Arrbit] Created profile '$pname'" \
        || log "⚠️   [Arrbit] Failed creating profile '$pname'"
    fi
  done

  log "✅  [Arrbit] Quality Profile configuration complete"
else
  log "⏭️   [Arrbit] Skipping Quality Profile"
fi

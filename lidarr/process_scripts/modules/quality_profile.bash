#!/usr/bin/env bash
#
# Module: Quality Profile
# Version: v1.0
# Author: prvctech
# ---------------------------------------------

# Identify this script for shared logging
scriptName="quality_profile"
scriptVersion="v1.0"

set -euo pipefail

# Shared helpers (sets up $arrUrl, $arrApiKey, logging, etc.)
source /config/arrbit/process_scripts/functions.bash

# Discover & wait for Lidarr API
getArrAppInfo
verifyApiAccess

# Prepare API headers
HEADER=( "-H" "X-Api-Key: ${arrApiKey}" "-H" "Content-Type: application/json" )

if [ "${CONFIGURE_QUALITY_PROFILE,,}" = "true" ]; then
  log "⚙️   [Arrbit] Starting Quality Profile configuration..."

  # 1) Fetch existing profiles
  existing_raw=$(curl -s --fail --retry 3 --retry-delay 2 \
    "${arrUrl}/api/${arrApiVersion}/qualityprofile" \
    -H "X-Api-Key: ${arrApiKey}")
  existing_profiles=$(jq -c . <<<"$existing_raw")

  # 2) Delete default profiles
  remove_file="/config/arrbit/process_scripts/modules/json_values/quality_profiles-default_values-remove.json"
  if [[ -f "$remove_file" ]] && default_profiles_json=$(jq -c . "$remove_file" 2>/dev/null); then
    for name in $(jq -r '.[].name' <<<"$default_profiles_json"); do
      id=$(jq -r ".[] | select(.name==\"$name\") | .id" <<<"$existing_profiles")
      if [[ -n "$id" && "$id" != "null" ]]; then
        log "⚙️   [Arrbit] Deleting default profile '$name' (ID: $id)..."
        curl -s --fail --retry 3 --retry-delay 2 \
          -X DELETE "${arrUrl}/api/${arrApiVersion}/qualityprofile/$id" \
          -H "X-Api-Key: ${arrApiKey}" \
          && log "✅  [Arrbit] Deleted profile '$name'" \
          || log "⚠️   [Arrbit] Failed deleting profile '$name'"
      fi
    done
  else
    log "⚠️   [Arrbit] Could not parse default-values JSON; skipping deletion"
  fi

  # 3) Load & normalize fallback JSON (wrap object into array if needed)
  add_file="/config/arrbit/process_scripts/modules/json_values/quality_profiles-values_to_add_missing_values.json"
  if [[ -f "$add_file" ]]; then
    fallback_raw=$(<"$add_file")
    fallback_profiles_json=$(jq -c 'if type=="array" then . else [.] end' <<<"$fallback_raw" 2>/dev/null) || fallback_profiles_json="[]"
    log "📦  [Arrbit] Loaded $(jq length <<<"$fallback_profiles_json") fallback profile(s)"
  else
    log "⚠️   [Arrbit] Fallback JSON file missing; skipping add/update"
    fallback_profiles_json="[]"
  fi

  # 4) Add or update each fallback profile
  for profile in $(jq -c '.[]' <<<"$fallback_profiles_json"); do
    pname=$(jq -r '.name' <<<"$profile")
    exists=$(jq -r ".[] | select(.name==\"$pname\") | .id" <<<"$existing_profiles")

    if [[ -n "$exists" && "$exists" != "null" ]]; then
      log "⚙️   [Arrbit] Updating profile '$pname' (ID: $exists)..."
      curl -s --fail --retry 3 --retry-delay 2 \
        -X PUT "${arrUrl}/api/${arrApiVersion}/qualityprofile/$exists" \
        "${HEADER[@]}" \
        --data-raw "$profile" \
        && log "✅  [Arrbit] Updated profile '$pname'" \
        || log "⚠️   [Arrbit] Failed updating profile '$pname'"
    else
      log "⚙️   [Arrbit] Creating profile '$pname'..."
      curl -s --fail --retry 3 --retry-delay 2 \
        -X POST "${arrUrl}/api/${arrApiVersion}/qualityprofile" \
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

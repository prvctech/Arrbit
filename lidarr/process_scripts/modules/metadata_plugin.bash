# Module: Tubifarry + Lyrics‑Enhancer Plugin Metadata
if [ "${CONFIGURE_METADATA_PLUGIN,,}" = "true" ]; then
  log "Configuring Tubifarry metadata consumer (Lidarr Custom)…"
  # 1) Tubifarry consumer (“Lidarr Custom”)
  endpoint="https://api.musicinfo.pro"
  cid=$(curl -s "${arrUrl}/api/${arrApiVersion}/metadata" "${HEADER[@]}" \
         | jq -r '.[] | select(.name=="Lidarr Custom") | .id')
  if [[ -n "$cid" && "$cid" != "null" ]]; then
    cfg=$(curl -s "${arrUrl}/api/${arrApiVersion}/metadata/${cid}" "${HEADER[@]}")
    new=$(echo "$cfg" | jq --arg url "$endpoint" '
      .enable = true
      | (.fields[] |= (if .name=="metadataSource" then .value=$url else . end))
    ')
    curl -s "${arrUrl}/api/${arrApiVersion}/metadata/${cid}" \
         -X PUT "${HEADER[@]}" \
         --data-raw "$new" \
      && log " → Tubifarry metadata consumer set to $endpoint" \
      || log " ⚠ Failed to configure Tubifarry consumer"
  else
    log " ⚠ Could not find metadata consumer 'Lidarr Custom'"
  fi

  # 2) Lyrics Enhancer (id=11)
  log "Configuring Lyrics Enhancer consumer…"
  lid=11
  le=$(curl -s "${arrUrl}/api/${arrApiVersion}/metadata/${lid}" "${HEADER[@]}")
  upd=$(echo "$le" | jq '
    .enable = true
    | (.fields[] |=
        if .name=="createLrcFiles" then .value=true
        elif .name=="lrcLibEnabled" then .value=true
        elif .name=="lrcLibInstanceUrl" then .value="https://lrclib.net"
        else . end
      )
  ')
  curl -s "${arrUrl}/api/${arrApiVersion}/metadata/${lid}" \
       -X PUT "${HEADER[@]}" \
       --data-raw "$upd" \
    && log " → Lyrics Enhancer configured" \
    || log " ⚠ Failed to configure Lyrics Enhancer"

else
  log "Skipping Tubifarry & Lyrics‑Enhancer metadata"
fi

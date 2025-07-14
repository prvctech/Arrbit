# Module: Custom Scripts (tagger.bash)
if [ "${CONFIGURE_CUSTOM_SCRIPTS,,}" = "true" ]; then
  log "Configuring Custom Scripts…"
  if ! curl -s "${arrUrl}/api/${arrApiVersion}/notification" "${HEADER[@]}" \
        | jq -e '.[] | select(.name=="tagger.bash")' >/dev/null; then
    log " → Adding tagger.bash (OnReleaseImport + OnUpgrade)"
    curl -s "${arrUrl}/api/${arrApiVersion}/notification" \
         -X POST "${HEADER[@]}" \
         --data-raw '{
  "name":           "tagger.bash",
  "implementation": "CustomScript",
  "configContract": "CustomScriptSettings",
  "onReleaseImport": true,
  "onUpgrade":       true,
  "fields":[
    {"name":"path","value":"/config/arrbit/process_scripts/tagger.bash"}
  ]
}' \
      && log "   • tagger.bash added" \
      || log " ⚠ Failed to add tagger.bash"
  else
    log " → tagger.bash already present, skipping"
  fi
else
  log "Skipping Custom Scripts"
fi

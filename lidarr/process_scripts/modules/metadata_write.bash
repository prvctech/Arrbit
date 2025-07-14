# Module: Metadata “writeAudioTags” Provider
if [ "${CONFIGURE_METADATA_WRITE,,}" = "true" ]; then
  log "Configuring Metadata Write Provider..."
  curl -s "${arrUrl}/api/${arrApiVersion}/config/metadataProvider" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "writeAudioTags":"newFiles",
  "scrubAudioTags":false,
  "id":1
}' \
    && log " → Metadata Write Provider configured" \
    || log " ⚠ Metadata Write API call failed"
else
  log "Skipping Metadata Write Provider"
fi

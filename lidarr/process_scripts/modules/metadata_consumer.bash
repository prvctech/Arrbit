# Module: Core Metadata Consumer (Kodi/XBMC)
if [ "${CONFIGURE_METADATA_CONSUMER,,}" = "true" ]; then
  log "Configuring Metadata Consumer..."
  curl -s "${arrUrl}/api/${arrApiVersion}/metadata/1" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "enable":true,
  "name":"Kodi (XBMC) / Emby",
  "fields":[
    {"name":"artistMetadata","value":true},
    {"name":"albumMetadata","value":true},
    {"name":"artistImages","value":true},
    {"name":"albumImages","value":true}
  ],
  "implementationName":"Kodi (XBMC) / Emby",
  "implementation":"XbmcMetadata",
  "configContract":"XbmcMetadataSettings",
  "infoLink":"https://wiki.servarr.com/lidarr/supported#xbmcmetadata",
  "tags":[],
  "id":1
}' \
    && log " → Metadata Consumer configured" \
    || log " ⚠ Metadata Consumer API call failed"
else
  log "Skipping Metadata Consumer"
fi

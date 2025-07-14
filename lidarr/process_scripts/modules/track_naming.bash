# Module: Track Naming
if [ "${CONFIGURE_TRACK_NAMING,,}" = "true" ]; then
  log "Configuring Track Naming..."
  curl -s "${arrUrl}/api/${arrApiVersion}/config/naming" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "renameTracks":true,
  "replaceIllegalCharacters":true,
  "standardTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
  "multiDiscTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
  "artistFolderFormat":"{Artist CleanName}{ (Artist Disambiguation)}",
  "includeArtistName":false,
  "includeAlbumTitle":false,
  "includeQuality":false,
  "replaceSpaces":false,
  "id":1
}' \
    && log " → Track Naming configured" \
    || log " ⚠ Track Naming API call failed"
else
  log "Skipping Track Naming"
fi


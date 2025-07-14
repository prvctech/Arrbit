# Module: Media Management
if [ "${CONFIGURE_MEDIA_MANAGEMENT,,}" = "true" ]; then
  log "Configuring Media Management..."
  curl -s "${arrUrl}/api/${arrApiVersion}/config/mediamanagement" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "autoUnmonitorPreviouslyDownloadedTracks":false,
  "recycleBin":"",
  "recycleBinCleanupDays":7,
  "downloadPropersAndRepacks":"preferAndUpgrade",
  "createEmptyArtistFolders":true,
  "deleteEmptyFolders":true,
  "fileDate":"albumReleaseDate",
  "watchLibraryForChanges":false,
  "rescanAfterRefresh":"always",
  "allowFingerprinting":"newFiles",
  "setPermissionsLinux":false,
  "chmodFolder":"777",
  "chownGroup":"",
  "skipFreeSpaceCheckWhenImporting":false,
  "minimumFreeSpaceWhenImporting":100,
  "copyUsingHardlinks":true,
  "importExtraFiles":true,
  "extraFileExtensions":"jpg,png,lrc",
  "id":1
}' \
    && log " → Media Management configured" \
    || log " ⚠ Media Management API call failed"
else
  log "Skipping Media Management"
fi

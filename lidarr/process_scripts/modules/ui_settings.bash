# Module: UI Settings
if [ "${CONFIGURE_UI_SETTINGS,,}" = "true" ]; then
  log "Configuring UI Settings..."
  curl -s "${arrUrl}/api/${arrApiVersion}/config/ui" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "firstDayOfWeek":0,
  "calendarWeekColumnHeader":"ddd M/D",
  "shortDateFormat":"MMM D YYYY",
  "longDateFormat":"dddd, MMMM D YYYY",
  "timeFormat":"h(:mm)a",
  "showRelativeDates":true,
  "enableColorImpairedMode":true,
  "uiLanguage":1,
  "expandAlbumByDefault":true,
  "expandSingleByDefault":true,
  "expandEPByDefault":true,
  "expandBroadcastByDefault":true,
  "expandOtherByDefault":true,
  "theme":"auto",
  "id":1
}' \
    && log " → UI Settings configured" \
    || log " ⚠ UI Settings API call failed"
else
  log "Skipping UI Settings"
fi

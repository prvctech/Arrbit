# Version v0.1.2
# Module: UI Settings
if [ "${CONFIGURE_UI_SETTINGS,,}" = "true" ]; then
  log "⚙️ [Arrbit] Configuring UI Settings..."
  if curl -s --fail --retry 3 --retry-delay 2 \
       "${arrUrl}/api/${arrApiVersion}/config/ui" \
       -X PUT "${HEADER[@]}" \
       --data-raw '{
  "firstDayOfWeek": 0,
  "calendarWeekColumnHeader": "ddd M/D",
  "shortDateFormat": "MMM D YYYY",
  "longDateFormat": "dddd, MMMM D YYYY",
  "timeFormat": "h(:mm)a",
  "showRelativeDates": true,
  "enableColorImpairedMode": true,
  "uiLanguage": 1,
  "expandAlbumByDefault": true,
  "expandSingleByDefault": true,
  "expandEPByDefault": true,
  "expandBroadcastByDefault": true,
  "expandOtherByDefault": true,
  "theme": "auto",
  "id": 1
}' ; then
    log "✔️ [Arrbit] UI Settings configured"
  else
    log "❌ [Arrbit] UI Settings API call failed"
  fi
else
  log "ℹ️ [Arrbit] Skipping UI Settings"
fi

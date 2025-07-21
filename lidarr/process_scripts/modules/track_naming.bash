#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit track_naming.bash
# Version: v2.7
# Purpose: Configure Lidarr Track Naming profile via API (standalone, self-connects to bridge).
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="track_naming"
SCRIPT_VERSION="v2.7"
LOG_DIR="/config/logs"
log_file_path="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
CYAN="\033[1;36m"
RESET="\033[0m"
MODULE_YELLOW="\033[1;33m"

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -iname "arrbit-${SCRIPT_NAME}-*.log" -mtime +5 -delete
touch "$log_file_path"
chmod 777 "$log_file_path"

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}track_naming module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (includes wait for API)
# ------------------------------------------------------------------------
if ! source /etc/services.d/arrbit/connectors/arr_bridge.bash; then
  arrbitErrorLog "❌   " \
    "${CYAN}[Arrbit]${RESET} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "track_naming.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Check CONFIGURE_TRACK_NAMING (always use flag helpers)
# ------------------------------------------------------------------------
CFG_FLAG=$(getFlag "CONFIGURE_TRACK_NAMING")
: "${CFG_FLAG:=true}"

if [[ "${CFG_FLAG,,}" == "true" ]]; then
  arrbitLog "📥  ${ARRBIT_TAG} Configuring Track Naming..."

  payload='{
    "renameTracks": true,
    "replaceIllegalCharacters": true,
    "standardTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
    "multiDiscTrackFormat": "{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}/{medium:00}{track:00} - {Track CleanTitle}",
    "artistFolderFormat": "{Artist CleanName} {(Artist Disambiguation)}",
    "includeArtistName": false,
    "includeAlbumTitle": false,
    "includeQuality": false,
    "replaceSpaces": false,
    "id": 1
  }'

  arrbitLog "🔧  ${ARRBIT_TAG} Sending Track Naming config payload (details in log)..."
  echo "[Arrbit] Track Naming payload:" >> "$log_file_path"
  echo "$payload" >> "$log_file_path"

  response=$(curl -s --fail --retry 3 --retry-delay 2 -m 10 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/naming?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  arrbitLog "🔵  ${ARRBIT_TAG} Response received (see log for details)"
  echo "[Arrbit] API Response:" >> "$log_file_path"
  echo "$response" >> "$log_file_path"

  if echo "$response" | jq -e '.renameTracks' >/dev/null 2>&1; then
    arrbitLog "✅  ${ARRBIT_TAG} Track Naming has been configured successfully"
  else
    arrbitErrorLog "⚠️   " \
      "${CYAN}[Arrbit]${RESET} Track Naming API call failed" \
      "Track Naming API failure" \
      "track_naming.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "Track Naming response did not validate" \
      "Check ARR API connectivity and payload"
  fi
else
  arrbitLog "⏩   ${ARRBIT_TAG} Skipping Track Naming module (flag disabled)"
fi

arrbitLog "📄   ${ARRBIT_TAG} Log saved to $log_file_path"
arrbitLog "✅   ${ARRBIT_TAG} Done with track_naming module!"

exit 0

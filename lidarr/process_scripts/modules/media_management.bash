#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit media_management.bash
# Version: v2.1
# Purpose: Configure Lidarr Media Management settings via API (Golden Standard).
# -------------------------------------------------------------------------------------------------------------

# === ARRBIT "TRINITY" HELPERS ===
source /etc/services.d/arrbit/helpers/helpers.bash
source /etc/services.d/arrbit/helpers/logging_utils.bash
source /etc/services.d/arrbit/helpers/error_utils.bash

SCRIPT_NAME="media_management"
SCRIPT_VERSION="v2.1"
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

arrbitLog "🚀  ${ARRBIT_TAG} Starting ${MODULE_YELLOW}media_management module${RESET} ${SCRIPT_VERSION}..."

# ------------------------------------------------------------------------
# Connect to arr_bridge.bash (waits for API)
# ------------------------------------------------------------------------
if ! source /etc/services.d/arrbit/connectors/arr_bridge.bash; then
  arrbitErrorLog "❌  " \
    "${CYAN}[Arrbit]${RESET} Could not source arr_bridge.bash" \
    "arr_bridge.bash missing" \
    "${SCRIPT_NAME}.bash" \
    "${SCRIPT_NAME}:${LINENO}" \
    "Required for API access" \
    "Check Arrbit setup"
  exit 1
fi

# ------------------------------------------------------------------------
# Check CONFIGURE_MEDIA_MANAGEMENT (always use flag helpers)
# ------------------------------------------------------------------------
CFG_FLAG=$(getFlag "CONFIGURE_MEDIA_MANAGEMENT")
: "${CFG_FLAG:=true}"

if [[ "${CFG_FLAG,,}" == "true" ]]; then
  arrbitLog "📥  ${ARRBIT_TAG} Configuring Media Management..."

  payload='{
    "autoUnmonitorPreviouslyDownloadedTracks": false,
    "recycleBin": "",
    "recycleBinCleanupDays": 7,
    "downloadPropersAndRepacks": "doNotPrefer",
    "createEmptyArtistFolders": true,
    "deleteEmptyFolders": true,
    "fileDate": "albumReleaseDate",
    "watchLibraryForChanges": false,
    "rescanAfterRefresh": "always",
    "allowFingerprinting": "newFiles",
    "setPermissionsLinux": false,
    "chmodFolder": "777",
    "chownGroup": "",
    "skipFreeSpaceCheckWhenImporting": false,
    "minimumFreeSpaceWhenImporting": 100,
    "copyUsingHardlinks": true,
    "importExtraFiles": true,
    "extraFileExtensions": "jpg,png,lrc",
    "id": 1
  }'

  # Log payload and response to file ONLY
  echo "[Arrbit] Media Management payload:" >> "$log_file_path"
  echo "$payload" >> "$log_file_path"

  response=$(curl -s --fail --retry 3 --retry-delay 2 \
    -X PUT "${arrUrl}/api/${arrApiVersion}/config/mediamanagement?apikey=${arrApiKey}" \
    -H "Content-Type: application/json" \
    --data-raw "$payload")

  echo "[Arrbit] API Response:" >> "$log_file_path"
  echo "$response" >> "$log_file_path"

  if echo "$response" | jq -e '.downloadPropersAndRepacks' >/dev/null 2>&1; then
    arrbitLog "✅  ${ARRBIT_TAG} Media Management settings have been applied successfully"
  else
    arrbitErrorLog "⚠️  " \
      "${CYAN}[Arrbit]${RESET} Media Management API call failed" \
      "Media Management API failure" \
      "${SCRIPT_NAME}.bash" \
      "${SCRIPT_NAME}:${LINENO}" \
      "Media Management response did not validate" \
      "Check ARR API connectivity and payload"
  fi

else
  arrbitLog "⏩  ${ARRBIT_TAG} Skipping media_management module (flag disabled)"
fi

arrbitLog "✅  ${ARRBIT_TAG} Done with media_management module!"
exit 0

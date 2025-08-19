#!/usr/bin/env bash
set -euo pipefail

# Temp test runner that mirrors the directory-creation logic from tdarr/setup/setup.bash
# Runs under WSL using a safe test root to avoid requiring root and to avoid touching /app

TEST_BASE="/mnt/c/Users/prv-cn/OneDrive/Documents/Arrbit/test-setup-run"
ARRBIT_BASE="${TEST_BASE}"
WORK_TMP_BASE="${ARRBIT_BASE}/data/temp"
TMP_ROOT="${WORK_TMP_BASE}/fetch"
HELPERS_DEST="${ARRBIT_BASE}/universal/helpers"
SETUP_DEST="${ARRBIT_BASE}/setup"

LOG_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/arrbit-setup-info-$(date +%Y_%m_%d-%H_%M).log"
touch "${LOG_FILE}" 2>/dev/null || true

echo "Test ARRBIT_BASE=${ARRBIT_BASE}"

dirs=(
	"${ARRBIT_BASE}"
	"${ARRBIT_BASE}/data"
	"${WORK_TMP_BASE}"
	"${ARRBIT_BASE}/environments"
	"${ARRBIT_BASE}/plugins"
	"${ARRBIT_BASE}/plugins/transcription"
	"${ARRBIT_BASE}/plugins/audio_enhancement"
	"${ARRBIT_BASE}/plugins/custom"
	"${ARRBIT_BASE}/data/models"
	"${ARRBIT_BASE}/data/models/whisper"
	"${ARRBIT_BASE}/data/cache"
	"${ARRBIT_BASE}/data/temp"
	"${ARRBIT_BASE}/data/logs"
	"${ARRBIT_BASE}/scripts"
	"${ARRBIT_BASE}/config"
	"${HELPERS_DEST}"
	"${SETUP_DEST}"
)

for d in "${dirs[@]}"; do
	if mkdir -p "$d" 2>/dev/null; then
		chmod 755 "$d" 2>/dev/null || true
		echo "CREATED: $d"
	else
		echo "FAILED: $d"
	fi
done

echo
echo "Directory tree (top 4 levels):"
find "${ARRBIT_BASE}" -maxdepth 4 -type d | sort

echo
echo "Done. Log file: ${LOG_FILE}"
exit 0

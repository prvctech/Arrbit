#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX Dependencies (Minimal)
# Version: v1.0.1-gs3.1.2
# Purpose: Install / verify minimal system + Python deps and WhisperX (CPU-only) in isolated env.
# Notes: Assumes setup has already placed helpers; uses standard logging utilities.
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

# shellcheck disable=SC2034 # SCRIPT_NAME & SCRIPT_VERSION may be read by external orchestrators/log collectors
export SCRIPT_NAME="dependencies"  # exported for downstream scripts referencing current op
export SCRIPT_VERSION="v1.0.1-gs3.1.2"
ARRBIT_BASE="/app/arrbit"
ARRBIT_ENVIRONMENTS_DIR="${ARRBIT_BASE}/environments"
WHISPERX_ENV_PATH="${ARRBIT_ENVIRONMENTS_DIR}/whisperx-env"
FORCE_REINSTALL="${ARRBIT_FORCE_DEPS:-0}"

# Source helpers (guaranteed after setup)
source "${ARRBIT_BASE}/universal/helpers/logging_utils.bash"
source "${ARRBIT_BASE}/universal/helpers/helpers.bash"
arrbitPurgeOldLogs

# Initialize log file (log_level exported by helpers)
LOG_FILE="${ARRBIT_BASE}/data/logs/arrbit-${SCRIPT_NAME}-${log_level}-$(date +%Y_%m_%d-%H_%M).log"
arrbitInitLog "${LOG_FILE}"
arrbitBanner "${SCRIPT_NAME}" "${SCRIPT_VERSION}"

# Root check
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
	log_error "Script must run as root"
	exit 1
fi

log_info "Starting installer"

# Idempotency skip
if [[ "${FORCE_REINSTALL}" != "1" && -d "${WHISPERX_ENV_PATH}" ]] && \
	"${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx' >/dev/null 2>&1; then
	log_info "WhisperX already present (ARRBIT_FORCE_DEPS=1 to reinstall)"
	log_info "Done."
	exit 0
fi

export DEBIAN_FRONTEND=noninteractive
log_info "Installing system packages"
if ! apt-get update -y >/dev/null 2>&1; then
	log_error "apt-get update failed"
	exit 1
fi
if ! apt-get install -y --no-install-recommends python3 python3-venv curl >/dev/null 2>&1; then
	log_error "apt-get install failed"
	exit 1
fi
apt-get clean >/dev/null 2>&1 || true

if [[ "${FORCE_REINSTALL}" = "1" && -d "${WHISPERX_ENV_PATH}" ]]; then
	log_info "Force reinstall: removing existing env"
	rm -rf -- "${WHISPERX_ENV_PATH}" || {
		log_error "env removal failed"
		exit 1
	}
fi

if [[ ! -d "${WHISPERX_ENV_PATH}" ]]; then
	log_info "Creating virtualenv"
	python3 -m venv "${WHISPERX_ENV_PATH}" || {
		log_error "venv creation failed"
		exit 1
	}
fi

PIP="${WHISPERX_ENV_PATH}/bin/pip"
PY="${WHISPERX_ENV_PATH}/bin/python"
log_info "Upgrading packaging tools"
"${PIP}" install --no-cache-dir --upgrade pip setuptools wheel >/dev/null 2>&1 || {
	log_error "pip bootstrap failed"
	exit 1
}
log_info "Installing torch CPU"
"${PIP}" install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu >/dev/null 2>&1 || {
	log_error "torch install failed"
	exit 1
}
log_info "Installing whisperx"
"${PIP}" install --no-cache-dir whisperx >/dev/null 2>&1 || {
	log_error "whisperx install failed"
	exit 1
}
log_info "Verifying import"
if ! "${PY}" -c 'import whisperx' >/dev/null 2>&1; then
	log_error "verification failed"
	exit 1
fi

log_info "Installation successful"
log_info "Done."
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX Dependencies (Minimal)
# Version: v1.1.0-gs3.1.2
# Purpose: Install / verify minimal system + Python deps and WhisperX (CPU-only) in isolated env.
# Notes: Assumes setup has already placed helpers; uses standard logging utilities.
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

# shellcheck disable=SC2034 # SCRIPT_NAME & SCRIPT_VERSION may be read by external orchestrators/log collectors
export SCRIPT_NAME="dependencies" # exported for downstream scripts referencing current op
export SCRIPT_VERSION="v1.1.0-gs3.1.2"
ARRBIT_BASE="/app/arrbit"
ARRBIT_ENVIRONMENTS_DIR="${ARRBIT_BASE}/environments"
WHISPERX_ENV_PATH="${ARRBIT_ENVIRONMENTS_DIR}/whisperx-env"
FORCE_REINSTALL="${ARRBIT_FORCE_DEPS:-0}"
# Minimal install mode: set ARRBIT_MINIMAL_WHISPERX=1 to install only the bare
# runtime packages required for basic whisperx operation. Optionally override
# package list via ARRBIT_WHISPERX_MINIMAL_PKGS (space-separated pip spec).
ARRBIT_MINIMAL_WHISPERX="${ARRBIT_MINIMAL_WHISPERX:-0}"
# Default minimal package set (keeps size small but functional)
ARRBIT_WHISPERX_MINIMAL_PKGS="whisperx onnxruntime ctranslate2 faster-whisper"

# Source helpers (guaranteed after setup)
source "${ARRBIT_BASE}/universal/helpers/logging_utils.bash"
source "${ARRBIT_BASE}/universal/helpers/helpers.bash"
arrbitPurgeOldLogs

# Initialize log file (log_level exported by helpers)
LOG_FILE="${ARRBIT_LOGS_DIR}/arrbit-${SCRIPT_NAME}-${log_level}-$(date +%Y_%m_%d-%H_%M).log"
arrbitInitLog "${LOG_FILE}"
arrbitBanner "${SCRIPT_NAME}" "${SCRIPT_VERSION}"

# Root check
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	log_error "Script must run as root"
	exit 1
fi

log_info "Starting installer"

# Idempotency skip
if [[ ${FORCE_REINSTALL} != "1" && -d ${WHISPERX_ENV_PATH} ]] &&
	"${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx' >/dev/null 2>&1; then
	log_info "WhisperX already present (ARRBIT_FORCE_DEPS=1 to reinstall)"
	log_info "Done."
	exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# Run a step with adaptive verbosity
# Args: <description> <command...>
run_step() {
	local desc="$1"; shift || true
	local -a cmd=("$@")
	log_info "$desc"
	# INFO level: suppress command output for cleanliness
	if [[ "$log_level" == "info" ]]; then
		if ! "${cmd[@]}" >/dev/null 2>&1; then
			log_error "${desc} failed"
			exit 1
		fi
		return 0
	fi

	# For VERBOSE/TRACE we capture to a temp file so we can both stream as trace
	# and also dump the full raw output into the centralized log for post-mortem.
			# Use a persistent .log file in the primary logs folder so artifacts remain
			local step_log
			step_log="${ARRBIT_LOGS_DIR}/arrbit-${SCRIPT_NAME}-step-$(date +%Y_%m_%d-%H_%M_%S)-$$.log"
		log_trace "Running: ${cmd[*]} (output -> ${step_log})"
		if ! "${cmd[@]}" >"${step_log}" 2>&1; then
			# On failure, stream the captured output as trace for context
			while IFS= read -r line; do [[ -z "$line" ]] && continue; log_trace "$line"; done <"${step_log}" || true
			log_error "${desc} failed"
			# Append raw output to main LOG_FILE for artifact preservation
			cat "${step_log}" | arrbitLogClean >>"${LOG_FILE}" || true
			exit 1
		fi

		# On success, stream captured output as trace and append raw to LOG_FILE
		while IFS= read -r line; do [[ -z "$line" ]] && continue; log_trace "$line"; done <"${step_log}" || true
		cat "${step_log}" | arrbitLogClean >>"${LOG_FILE}" || true
		# keep the per-step log as an artifact; do not remove it
}

run_step "apt-get update" apt-get update -y
run_step "apt-get install python3 python3-venv curl" apt-get install -y --no-install-recommends python3 python3-venv curl
run_step "apt-get clean" apt-get clean

if [[ ${FORCE_REINSTALL} == "1" && -d ${WHISPERX_ENV_PATH} ]]; then
	log_info "Force reinstall: removing existing env"
	if [[ "$log_level" == "info" ]]; then
		rm -rf -- "${WHISPERX_ENV_PATH}" || { log_error "env removal failed"; exit 1; }
	else
		# Trace removal details
		if ! rm -rvf -- "${WHISPERX_ENV_PATH}" 2>&1 | while IFS= read -r line; do log_trace "$line"; done; then
			log_error "env removal failed"
			exit 1
		fi
	fi
fi

if [[ ! -d ${WHISPERX_ENV_PATH} ]]; then
	log_info "Creating virtualenv"
	if [[ "$log_level" == "info" ]]; then
		python3 -m venv "${WHISPERX_ENV_PATH}" || { log_error "venv creation failed"; exit 1; }
	else
		if ! python3 -m venv "${WHISPERX_ENV_PATH}" 2>&1 | while IFS= read -r line; do log_trace "$line"; done; then
			log_error "venv creation failed"
			exit 1
		fi
	fi
fi

PIP="${WHISPERX_ENV_PATH}/bin/pip"
PY="${WHISPERX_ENV_PATH}/bin/python"
run_step "Upgrade pip/setuptools/wheel" "${PIP}" install --no-cache-dir --upgrade pip setuptools wheel
run_step "Install torch (CPU)" "${PIP}" install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
# Decide which packages to install for whisperx
if [[ "${ARRBIT_MINIMAL_WHISPERX}" == "1" ]]; then
	log_info "Minimal WhisperX install enabled"
	# Allow override from environment
	if [[ -n "${ARRBIT_WHISPERX_MINIMAL_PKGS:-}" ]]; then
		minimal_pkgs="${ARRBIT_WHISPERX_MINIMAL_PKGS}"
	else
		minimal_pkgs="${ARRBIT_WHISPERX_MINIMAL_PKGS}"
	fi
	# Install only the minimal package set
	run_step "Install whisperx (minimal)" "${PIP}" install --no-cache-dir ${minimal_pkgs}
else
	run_step "Install whisperx" "${PIP}" install --no-cache-dir whisperx
fi
run_step "Verify whisperx import" "${PY}" -c 'import whisperx'

log_info "Installation successful"
log_info "Done."
exit 0

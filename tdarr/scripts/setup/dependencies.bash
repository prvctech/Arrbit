#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX Dependencies (Minimal)
# Version: v1.2.0-gs3.1.2
# Purpose: Install / verify minimal system + Python deps and WhisperX (CPU-only) in isolated env.
# Notes: Assumes setup has already placed helpers; uses standard logging utilities.
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

# shellcheck disable=SC2034 # SCRIPT_NAME & SCRIPT_VERSION may be read by external orchestrators/log collectors
export SCRIPT_NAME="dependencies" # exported for downstream scripts referencing current op
export SCRIPT_VERSION="v1.2.0-gs3.1.2"
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

# Ensure environments root exists and set permissive permissions early to avoid permission conflicts
ENV_ROOT="${ARRBIT_ENVIRONMENTS_DIR}"
run_step "Ensure environments root exists" mkdir -p "${ENV_ROOT}"
run_step "Set permissive permissions on environments root" bash -lc "chmod 0777 \"${ENV_ROOT}\" || true"

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
run_step "apt-get install python3 python3-venv curl mkvtoolnix ffmpeg" apt-get install -y --no-install-recommends python3 python3-venv curl mkvtoolnix ffmpeg
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
	# After creating a venv, ensure its subfolders inherit permissive permissions
	run_step "Ensure environments permissions after venv creation" bash -lc 'if [ -d "${ARRBIT_ENVIRONMENTS_DIR}" ]; then find "${ARRBIT_ENVIRONMENTS_DIR}" -type d -exec chmod 0777 {} + || true; fi'
fi

PIP="${WHISPERX_ENV_PATH}/bin/pip"
PY="${WHISPERX_ENV_PATH}/bin/python"
run_step "Upgrade pip/setuptools/wheel" "${PIP}" install --no-cache-dir --upgrade pip setuptools wheel
run_step "Install latest torch (CPU) stack" "${PIP}" install --no-cache-dir --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Optional extra requirement specs (space separated), e.g.
#   ARRBIT_WHISPERX_PIP_EXTRAS="ctranslate2==4.5.0 faster-whisper==1.0.0"
EXTRA_PKGS="${ARRBIT_WHISPERX_PIP_EXTRAS:-}"

if [[ "${ARRBIT_MINIMAL_WHISPERX}" == "1" ]]; then
	log_info "Minimal WhisperX install enabled"
	if [[ -n "${ARRBIT_WHISPERX_MINIMAL_PKGS:-}" ]]; then
		minimal_pkgs="${ARRBIT_WHISPERX_MINIMAL_PKGS}"
	else
		minimal_pkgs="${ARRBIT_WHISPERX_MINIMAL_PKGS}"
	fi
	run_step "Install whisperx (minimal latest)" "${PIP}" install --no-cache-dir --upgrade ${minimal_pkgs} ${EXTRA_PKGS}
else
	run_step "Install whisperx (latest)" "${PIP}" install --no-cache-dir --upgrade whisperx ctranslate2 onnxruntime "faster-whisper" ${EXTRA_PKGS}
fi

# Verify core imports
run_step "Verify whisperx import" "${PY}" -c 'import whisperx, faster_whisper, ctranslate2, onnxruntime'
# silero_vad removed: rely on WhisperX built-in VAD (no additional VAD import verification)
# Ensure whisperx model directory exists and download the base model (CPU, int8) into Arrbit model cache
run_step "Create whisper model directory" mkdir -p "${ARRBIT_BASE}/data/models/whisper"
run_step "Download WhisperX base model (CPU, int8)" "${PY}" -c "import whisperx; whisperx.load_model('base', device='cpu', compute_type='int8')"
# Post-install verification: ensure accelerator packages are installed and importable
run_step "Verify accelerator packages (pip show)" "${PIP}" show ctranslate2 onnxruntime "faster-whisper"
run_step "Verify accelerator imports" "${PY}" -c 'import faster_whisper, ctranslate2, onnxruntime'

log_info "Installation successful"
# Expose mkvpropedit in isolated tools dir (symlink) for consistency
TOOLS_DIR="${ARRBIT_ENVIRONMENTS_DIR}/tools-bin"
mkdir -p "${TOOLS_DIR}" || true
if command -v mkvpropedit >/dev/null 2>&1; then
	ln -sf "$(command -v mkvpropedit)" "${TOOLS_DIR}/mkvpropedit" || true
fi

# Symlink the venv python into tools-bin for easy discovery by plugins
if [[ -x "${WHISPERX_ENV_PATH}/bin/python" ]]; then
	ln -sf "${WHISPERX_ENV_PATH}/bin/python" "${TOOLS_DIR}/whisperx_python" || true
	log_info "Created tools-bin/whisperx_python -> ${WHISPERX_ENV_PATH}/bin/python"
else
	log_warning "WhisperX venv python not found at ${WHISPERX_ENV_PATH}/bin/python"
fi

# final safety step: make every directory and file under environments world RWX
run_step "Ensure permissive permissions for /app/arrbit/environments" bash -lc 'if [ -d /app/arrbit/environments ]; then find /app/arrbit/environments -type d -exec chmod 0777 {} +; find /app/arrbit/environments -type f -exec chmod 0777 {} +; fi' || true

log_info "Done."
exit 0

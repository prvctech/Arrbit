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

# Source canonical helpers; fail loudly if missing (no fallbacks).
if [ -f "${ARRBIT_BASE}/universal/helpers/logging_utils.bash" ] && [ -f "${ARRBIT_BASE}/universal/helpers/helpers.bash" ]; then
	source "${ARRBIT_BASE}/universal/helpers/logging_utils.bash"
	source "${ARRBIT_BASE}/universal/helpers/helpers.bash"
	# Ensure log retention is enforced per Golden Standard before creating new log file
	arrbitPurgeOldLogs
else
	printf '[ERROR] Required helpers not found at %s/universal/helpers\n' "${ARRBIT_BASE}" >&2
	exit 2
fi

# Initialize log file (log_level exported by helpers)
LOG_FILE="${ARRBIT_LOGS_DIR}/arrbit-${SCRIPT_NAME}-${log_level}-$(date +%Y_%m_%d-%H_%M).log"
arrbitInitLog "${LOG_FILE}"
arrbitBanner "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
# exec_step: run a step using canonical logging utilities (NOT named exec_step)
exec_step() {
  local desc="$1"; shift || true
  local -a cmd=("$@")
  log_info "$desc"
  if [[ "${log_level:-info}" == "info" ]]; then
    if ! "${cmd[@]}" >/dev/null 2>&1; then
      log_error "${desc} failed"
      exit 1
    fi
    return 0
  fi
  local step_log="${ARRBIT_LOGS_DIR}/arrbit-${SCRIPT_NAME}-step-$(date +%Y_%m_%d-%H_%M_%S)-$$.log"
  log_trace "Running: ${cmd[*]} (output -> ${step_log})"
  if ! "${cmd[@]}" >"${step_log}" 2>&1; then
    while IFS= read -r line; do [[ -z "$line" ]] && continue; log_trace "$line"; done <"${step_log}" || true
    log_error "${desc} failed"
    cat "${step_log}" | arrbitLogClean >>"${LOG_FILE}" || true
    exit 1
  fi
  while IFS= read -r line; do [[ -z "$line" ]] && continue; log_trace "$line"; done <"${step_log}" || true
  cat "${step_log}" | arrbitLogClean >>"${LOG_FILE}" || true
}

# Ensure environments root exists and set permissive permissions early to avoid permission conflicts
ENV_ROOT="${ARRBIT_ENVIRONMENTS_DIR}"
exec_step "Ensure environments root exists" mkdir -p "${ENV_ROOT}"
exec_step "Set permissive permissions on environments root" bash -lc "chmod 0777 \"${ENV_ROOT}\" || true"

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

# exec_step must be provided by the canonical helpers (universal/helpers/logging_utils.bash
# and universal/helpers/helpers.bash). No fallback implementation is present here to enforce
# usage of the canonical helpers.

exec_step "apt-get update" apt-get update -y
exec_step "apt-get install python3 python3-venv curl mkvtoolnix ffmpeg" apt-get install -y --no-install-recommends python3 python3-venv curl mkvtoolnix ffmpeg
exec_step "apt-get clean" apt-get clean

# Install and manage mkvtoolnix under /app/arrbit/dependencies/mkvtoolnix (idempotent)
install_mkvtoolnix() {
  TARGET_DIR="${ARRBIT_BASE}/dependencies/mkvtoolnix"
  mkdir -p "$TARGET_DIR"
  # Ensure permissive permissions to avoid container permission issues
  chmod 0777 "$TARGET_DIR" || true

  # If mkvmerge already present and executable in target, skip
  if [ -x "$TARGET_DIR/mkvmerge" ]; then
    log_info "mkvtoolnix already installed at $TARGET_DIR"
    export MKVTOOLNIX_BIN="$TARGET_DIR/mkvmerge"
    export PATH="$PATH:$TARGET_DIR"
    return 0
  fi

  # Prefer copying an existing system mkvmerge into the target dir (non-destructive)
  if command -v mkvmerge >/dev/null 2>&1; then
    SYS_MKV="$(command -v mkvmerge)"
    exec_step "Copy system mkvmerge into $TARGET_DIR" cp -a "$(dirname "$SYS_MKV")/." "$TARGET_DIR/" || true
    chmod +x "$TARGET_DIR/"* || true
  else
    # Fallback: download a portable binary archive and extract mkvmerge into the target dir
    MKVTOOLNIX_URL="https://mkvtoolnix.download/downloads/mkvtoolnix-64-bit.tar.xz"
    TMPDIR="$(mktemp -d)"
    if ! curl -fsSL "$MKVTOOLNIX_URL" -o "$TMPDIR/mkvtoolnix.tar.xz"; then
      log_error "mkvtoolnix download failed"
      rm -rf "$TMPDIR" || true
      return 1
    fi
    if ! tar -xJf "$TMPDIR/mkvtoolnix.tar.xz" -C "$TMPDIR"; then
      log_error "mkvtoolnix extract failed"
      rm -rf "$TMPDIR" || true
      return 1
    fi
    EXTRACTED_BIN="$(find "$TMPDIR" -type f -name mkvmerge -print -quit || true)"
    if [ -n "$EXTRACTED_BIN" ]; then
      cp -a "$(dirname "$EXTRACTED_BIN")/." "$TARGET_DIR/" || { log_error "mkvtoolnix copy failed"; rm -rf "$TMPDIR"; return 1; }
      chmod +x "$TARGET_DIR/"* || true
      rm -rf "$TMPDIR"
    else
      log_error "mkvtoolnix installation failed: no mkvmerge found in archive"
      rm -rf "$TMPDIR"
      return 1
    fi
  fi

  # Make mkvmerge discoverable to plugins and system tooling
  export MKVTOOLNIX_BIN="$TARGET_DIR/mkvmerge"
  export PATH="$PATH:$TARGET_DIR"
  ln -sf "$TARGET_DIR/mkvmerge" /usr/local/bin/mkvmerge 2>/dev/null || true

  # Verify installed binary is executable
  if [ ! -x "${MKVTOOLNIX_BIN}" ]; then
    log_error "mkvtoolnix installation succeeded but ${MKVTOOLNIX_BIN} is not executable"
    return 1
  fi

  log_info "mkvtoolnix installed to $TARGET_DIR"
  return 0
}

# Run installer and fail fast if it cannot be provisioned
exec_step "Install mkvtoolnix into arrbit dependencies" install_mkvtoolnix

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
	exec_step "Ensure environments permissions after venv creation" bash -lc 'if [ -d "${ARRBIT_ENVIRONMENTS_DIR}" ]; then find "${ARRBIT_ENVIRONMENTS_DIR}" -type d -exec chmod 0777 {} + || true; fi'
fi

PIP="${WHISPERX_ENV_PATH}/bin/pip"
PY="${WHISPERX_ENV_PATH}/bin/python"
exec_step "Upgrade pip/setuptools/wheel" "${PIP}" install --no-cache-dir --upgrade pip setuptools wheel
exec_step "Install latest torch (CPU) stack" "${PIP}" install --no-cache-dir --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

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
	exec_step "Install whisperx (minimal latest)" "${PIP}" install --no-cache-dir --upgrade ${minimal_pkgs} ${EXTRA_PKGS}
else
	exec_step "Install whisperx (latest)" "${PIP}" install --no-cache-dir --upgrade whisperx ctranslate2 onnxruntime "faster-whisper" ${EXTRA_PKGS}
fi

# Verify core imports
exec_step "Verify whisperx import" "${PY}" -c 'import whisperx, faster_whisper, ctranslate2, onnxruntime'

exec_step "Create whisper model directory" mkdir -p "${ARRBIT_BASE}/data/models/whisper"
exec_step "Download WhisperX base model (CPU, int8)" "${PY}" -c "import whisperx; whisperx.load_model('base', device='cpu', compute_type='int8')"
# Post-install verification: ensure accelerator packages are installed and importable
exec_step "Verify accelerator packages (pip show)" "${PIP}" show ctranslate2 onnxruntime "faster-whisper"
exec_step "Verify accelerator imports" "${PY}" -c 'import faster_whisper, ctranslate2, onnxruntime'

log_info "Installation successful"
# Expose mkvpropedit and mkvmerge in isolated tools dir (symlink) for consistency
TOOLS_DIR="${ARRBIT_ENVIRONMENTS_DIR}/tools-bin"
mkdir -p "${TOOLS_DIR}" || true
if command -v mkvpropedit >/dev/null 2>&1; then
	ln -sf "$(command -v mkvpropedit)" "${TOOLS_DIR}/mkvpropedit" || true
fi
# Prefer arrbit-managed mkvmerge if present; fall back to system mkvmerge
if [[ -n "${MKVTOOLNIX_BIN:-}" && -x "${MKVTOOLNIX_BIN}" ]]; then
	ln -sf "${MKVTOOLNIX_BIN}" "${TOOLS_DIR}/mkvmerge" || true
elif command -v mkvmerge >/dev/null 2>&1; then
	ln -sf "$(command -v mkvmerge)" "${TOOLS_DIR}/mkvmerge" || true
fi

# Symlink the venv python into tools-bin for easy discovery by plugins
if [[ -x "${WHISPERX_ENV_PATH}/bin/python" ]]; then
	ln -sf "${WHISPERX_ENV_PATH}/bin/python" "${TOOLS_DIR}/whisperx_python" || true
	log_info "Created tools-bin/whisperx_python -> ${WHISPERX_ENV_PATH}/bin/python"
else
	log_warning "WhisperX venv python not found at ${WHISPERX_ENV_PATH}/bin/python"
fi

# final safety step: make every directory and file under environments world RWX
exec_step "Ensure permissive permissions for /app/arrbit/environments" bash -lc 'if [ -d /app/arrbit/environments ]; then find /app/arrbit/environments -type d -exec chmod 0777 {} +; find /app/arrbit/environments -type f -exec chmod 0777 {} +; fi' || true

log_info "Done."
exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX dependencies (fully isolated)
# Version: v2.1.1-gs2.8.3
# Purpose: Install system deps + WhisperX in isolated env at /app/arrbit/environments/whisperx-env (flattened structure)
# Silent to terminal; verbose logging to /app/arrbit/data/logs
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v2.1.1-gs2.8.3"
ARRBIT_BASE="/app/arrbit"
ENV_DIR="${ARRBIT_BASE}/environments"
WHISPERX_ENV_PATH="${ENV_DIR}/whisperx-env"
ALWAYS_UPGRADE="${ARRBIT_FORCE_DEPS:-0}"

LOG_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
chmod 777 "${LOG_DIR}" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/dependencies-$(date '+%Y_%m_%d-%H_%M_%S').log"
touch "${LOG_FILE}" 2>/dev/null || true
chmod 666 "${LOG_FILE}" 2>/dev/null || true

log_info(){ printf '[INFO] %s\n' "$*" >>"${LOG_FILE}"; }
log_warn(){ printf '[WARN] %s\n' "$*" >>"${LOG_FILE}"; }
log_error(){ printf '[ERROR] %s\n' "$*" >>"${LOG_FILE}"; }
log_info "Starting dependencies installer version ${DEP_SCRIPT_VERSION}" 

command_exists(){ command -v "$1" >/dev/null 2>&1; }
apt_install(){ DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1; }

if [ "${EUID:-$(id -u)}" -ne 0 ]; then log_error "Run as root"; exit 1; fi

# Basic setup validation: expect setup to have created scripts + config dirs
if [ ! -d "${ARRBIT_BASE}/scripts" ] || [ ! -d "${ARRBIT_BASE}/config" ]; then
  log_error "Required base directories missing (/app/arrbit/scripts or /app/arrbit/config). Run setup first."; exit 1
fi

all_present() {
  command_exists ffmpeg && command_exists jq && command_exists yq && command_exists python3 \
    && [ -d "${WHISPERX_ENV_PATH}" ] \
    && [ -f "${WHISPERX_ENV_PATH}/bin/python" ] \
    && "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx' 2>/dev/null
}

if [ "${ALWAYS_UPGRADE}" != "1" ] && all_present; then
  log_info "Dependencies already satisfied. Exiting."
  exit 0
fi

if command_exists apt-get; then
  log_info "Updating apt indexes"
  apt-get update >/dev/null 2>&1 || { log_error "apt update failed"; exit 1; }
fi

install_sys() {
  log_info "Installing system packages if missing"
  for pkg in ffmpeg jq yq python3 python3-pip python3-venv; do
    if ! command_exists "${pkg%%[0-9]*}"; then
      log_info "Installing $pkg"
      apt_install "$pkg" || log_warn "Failed installing $pkg"
    fi
  done
}
install_sys

mkdir -p "${ENV_DIR}" || true

if [ "${ALWAYS_UPGRADE}" = "1" ] && [ -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Force upgrade requested: removing existing environment"
  rm -rf "${WHISPERX_ENV_PATH}" || { log_error "Failed to remove existing env"; exit 1; }
fi
if [ ! -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Creating virtual environment at ${WHISPERX_ENV_PATH}"
  python3 -m venv "${WHISPERX_ENV_PATH}" || { log_error "venv creation failed"; exit 1; }
fi

log_info "Upgrading pip"
"${WHISPERX_ENV_PATH}/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || log_warn "pip upgrade failed"

log_info "Installing whisperx"
"${WHISPERX_ENV_PATH}/bin/python" -m pip install whisperx >/dev/null 2>&1 || { log_error "whisperx install failed"; exit 1; }

log_info "Verifying whisperx"
if ! "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx, sys; print("WhisperX OK:", whisperx.__version__)' >>"${LOG_FILE}" 2>&1; then
  log_error "WhisperX verification failed"; exit 1;
fi

# Wrapper script (only if scripts directory exists)
if [ -d "${ARRBIT_BASE}/scripts" ]; then
  cat > "${ARRBIT_BASE}/scripts/whisperx" <<EOF
#!/usr/bin/env bash
exec "${WHISPERX_ENV_PATH}/bin/python" -m whisperx "\$@"
EOF
  chmod +x "${ARRBIT_BASE}/scripts/whisperx" 2>/dev/null || true
  log_info "Wrapper created: ${ARRBIT_BASE}/scripts/whisperx"
fi

log_info "Dependencies installation complete. Log: ${LOG_FILE}"
exit 0

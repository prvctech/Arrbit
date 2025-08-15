#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr WhisperX dependencies (fully isolated)
# Version: v2.1.0-gs2.8.3
# Purpose: Install system deps + WhisperX in isolated env at /app/arrbit/tdarr/environments/whisperx-env
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v2.1.0-gs2.8.3"
ARRBIT_BASE="/app/arrbit"
TDARR_BASE="${ARRBIT_BASE}/tdarr"
WHISPERX_ENV_PATH="${TDARR_BASE}/environments/whisperx-env"
ALWAYS_UPGRADE="${ARRBIT_FORCE_DEPS:-0}"

log_info(){ echo "[INFO] $*"; }
log_warning(){ echo "[WARN] $*" >&2; }
log_error(){ echo "[ERROR] $*" >&2; }

command_exists(){ command -v "$1" >/dev/null 2>&1; }
apt_install(){ DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1; }

create_structure() {
  mkdir -p "${TDARR_BASE}/environments" \
           "${TDARR_BASE}/plugins"/{transcription,audio_enhancement,custom} \
           "${TDARR_BASE}/data"/{models/whisper,cache,temp,logs} \
           "${TDARR_BASE}/scripts" \
           "${TDARR_BASE}/config" \
           "${TDARR_BASE}/setup_scripts"
}

all_present() {
  command_exists ffmpeg && command_exists jq && command_exists yq && command_exists python3 \
    && [ -d "${WHISPERX_ENV_PATH}" ] \
    && [ -f "${WHISPERX_ENV_PATH}/bin/python" ] \
    && "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx' 2>/dev/null
}

if [ "$EUID" -ne 0 ]; then log_error "Run as root"; exit 1; fi
create_structure

if [ "${ALWAYS_UPGRADE}" != "1" ] && all_present; then
  log_info "Dependencies already satisfied."
  exit 0
fi

if command_exists apt-get; then
  log_info "Updating apt indexes"
  apt-get update >/dev/null 2>&1 || { log_error "apt update failed"; exit 1; }
fi

install_sys() {
  for pkg in ffmpeg jq yq python3 python3-pip python3-venv; do
    if ! command_exists "${pkg%%[0-9]*}"; then
      apt_install "$pkg" || log_warning "Failed installing $pkg"
    fi
  done
}
install_sys

# (Re)create venv if forcing or missing
if [ "${ALWAYS_UPGRADE}" = "1" ] && [ -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Removing existing env (upgrade requested)"
  rm -rf "${WHISPERX_ENV_PATH}"
fi
if [ ! -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Creating virtual environment"
  python3 -m venv "${WHISPERX_ENV_PATH}" || { log_error "venv creation failed"; exit 1; }
fi

log_info "Upgrading pip"
"${WHISPERX_ENV_PATH}/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || log_warning "pip upgrade failed"

log_info "Installing whisperx"
"${WHISPERX_ENV_PATH}/bin/python" -m pip install whisperx >/dev/null 2>&1 || { log_error "whisperx install failed"; exit 1; }

log_info "Verifying whisperx import"
if ! "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx, sys; print("WhisperX OK:", whisperx.__version__)'; then
  log_error "WhisperX verification failed"; exit 1
fi

# Wrapper script
cat > "${TDARR_BASE}/scripts/whisperx" <<EOF
#!/usr/bin/env bash
exec "${WHISPERX_ENV_PATH}/bin/python" -m whisperx "\$@"
EOF
chmod +x "${TDARR_BASE}/scripts/whisperx"

log_info "Done. Use: ${TDARR_BASE}/scripts/whisperx <audiofile>"
exit 0

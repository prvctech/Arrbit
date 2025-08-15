#!/usr/bin/env bash
# shellcheck shell=bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX dependencies (simple)
# Version: v2.2.0-gs2.8.3
# Purpose: Install system deps + WhisperX in isolated env at /app/arrbit/environments/whisperx-env
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v2.2.0-gs2.8.3"
ARRBIT_BASE="/app/arrbit"
HELPERS_DIR="${ARRBIT_BASE}/helpers"
WHISPERX_ENV_PATH="${ARRBIT_BASE}/environments/whisperx-env"
FORCE_REINSTALL="${ARRBIT_FORCE_DEPS:-0}"

LOG_DIR="${ARRBIT_BASE}/data/logs"
LOG_FILE="${LOG_DIR}/dependencies-$(date '+%Y_%m_%d-%H_%M_%S').log"

# Source shared helpers & logging
if [ -f "${HELPERS_DIR}/logging_utils.bash" ]; then
  . "${HELPERS_DIR}/logging_utils.bash"
elif [ -f "${HELPERS_DIR}/helpers.bash" ]; then
  . "${HELPERS_DIR}/helpers.bash"
fi

trap 'command -v arrbitPurgeOldLogs >/dev/null 2>&1 && arrbitPurgeOldLogs || true' EXIT

log_info "Starting dependencies installer version ${DEP_SCRIPT_VERSION}"

# Root check
if [ "${EUID:-$(id -u)}" -ne 0 ]; then 
  log_error "Must run as root"
  exit 1
fi

# Skip if already installed (unless force)
if [ "${FORCE_REINSTALL}" != "1" ] && [ -d "${WHISPERX_ENV_PATH}" ] && "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx' 2>/dev/null; then
  log_info "WhisperX already installed. Use ARRBIT_FORCE_DEPS=1 to reinstall."
  exit 0
fi

# Install system packages
log_info "Installing system packages"
apt-get update >>"${LOG_FILE}" 2>&1
apt-get install -y python3 python3-pip python3-venv ffmpeg jq curl ca-certificates >>"${LOG_FILE}" 2>&1

# Install yq if missing
if ! command -v yq >/dev/null 2>&1; then
  log_info "Installing yq"
  curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
  chmod +x /usr/local/bin/yq
fi

# Remove existing env if force reinstall
if [ "${FORCE_REINSTALL}" = "1" ] && [ -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Force reinstall: removing existing environment"
  rm -rf "${WHISPERX_ENV_PATH}"
fi

# Create virtual environment
if [ ! -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Creating virtual environment"
  python3 -m venv "${WHISPERX_ENV_PATH}"
fi

# Install WhisperX
log_info "Installing WhisperX"
"${WHISPERX_ENV_PATH}/bin/pip" install --upgrade pip
"${WHISPERX_ENV_PATH}/bin/pip" install whisperx

# Verify installation
log_info "Verifying WhisperX installation"
if ! "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx; print("WhisperX installed successfully")' >>"${LOG_FILE}" 2>&1; then
  log_error "WhisperX installation verification failed"
  exit 1
fi

log_info "Dependencies installation complete"
exit 0

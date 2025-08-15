#!/usr/bin/env bash
# shellcheck shell=bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX dependencies (minimal)
# Version: v2.3.0-gs2.8.3
# Purpose: Install minimal deps + WhisperX for CPU-only tiny model
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v2.3.0-gs2.8.3"
ARRBIT_BASE="/app/arrbit"
HELPERS_DIR="${ARRBIT_BASE}/helpers"
WHISPERX_ENV_PATH="${ARRBIT_BASE}/environments/whisperx-env"
FORCE_REINSTALL="${ARRBIT_FORCE_DEPS:-0}"

LOG_FILE="${ARRBIT_BASE}/data/logs/dependencies-$(date '+%Y_%m_%d-%H_%M_%S').log"

# Source helpers
if [ -f "${HELPERS_DIR}/logging_utils.bash" ]; then
  . "${HELPERS_DIR}/logging_utils.bash"
elif [ -f "${HELPERS_DIR}/helpers.bash" ]; then
  . "${HELPERS_DIR}/helpers.bash"
fi

trap 'command -v arrbitPurgeOldLogs >/dev/null 2>&1 && arrbitPurgeOldLogs || true' EXIT

log_info "Starting minimal dependencies installer version ${DEP_SCRIPT_VERSION}"

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

# Install only essential system packages
log_info "Installing minimal system packages"
apt-get update >>"${LOG_FILE}" 2>&1
apt-get install -y --no-install-recommends python3 python3-venv curl >>"${LOG_FILE}" 2>&1

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

# Install WhisperX with CPU-only minimal deps
log_info "Installing WhisperX (CPU-only, minimal)"
"${WHISPERX_ENV_PATH}/bin/pip" install --no-cache-dir pip setuptools wheel
"${WHISPERX_ENV_PATH}/bin/pip" install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
"${WHISPERX_ENV_PATH}/bin/pip" install --no-cache-dir whisperx

# Verify installation
log_info "Verifying WhisperX installation"
if ! "${WHISPERX_ENV_PATH}/bin/python" -c 'import whisperx; print("WhisperX installed successfully")' >>"${LOG_FILE}" 2>&1; then
  log_error "WhisperX installation verification failed"
  exit 1
fi

log_info "Minimal dependencies installation complete"
exit 0
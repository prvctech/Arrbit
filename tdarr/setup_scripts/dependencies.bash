#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr WhisperX dependencies (simplified)
# Version: v2.0.0-gs2.8.3
# Purpose: Install system deps + WhisperX in dedicated Python environment
# Environment: /app/services/whisper-x with CPU-only support
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v2.0.0-gs2.8.3"
WHISPERX_ENV_PATH="/app/services/whisper-x"
ALWAYS_UPGRADE="${ARRBIT_FORCE_DEPS:-0}"

# Logging setup (Golden Standard compatible)
if [[ -f "/app/arrbit/helpers/logging_utils.bash" ]]; then
  source "/app/arrbit/helpers/logging_utils.bash"
elif [[ -f "$(dirname "$0")/../helpers/logging_utils.bash" ]]; then
  source "$(dirname "$0")/../helpers/logging_utils.bash"
elif [[ -f "/app/arrbit/universal/helpers/logging_utils.bash" ]]; then
  source "/app/arrbit/universal/helpers/logging_utils.bash"
else
  # Fallback logging
  log_info() { echo "[INFO] $*"; }
  log_warning() { echo "[WARN] $*" >&2; }
  log_error() { echo "[ERROR] $*" >&2; }
fi

# Utility functions
command_exists() { command -v "$1" >/dev/null 2>&1; }

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1
}

# Check if everything is already installed
all_present() {
  command_exists ffmpeg && \
  command_exists jq && \
  command_exists yq && \
  command_exists python3 && \
  [[ -d "$WHISPERX_ENV_PATH" ]] && \
  [[ -f "$WHISPERX_ENV_PATH/bin/python" ]] && \
  "$WHISPERX_ENV_PATH/bin/python" -c "import whisperx" 2>/dev/null
}

# Early exit if already installed and not forcing
if [[ "$ALWAYS_UPGRADE" != "1" ]] && all_present; then
  log_info "All dependencies already present (WhisperX environment exists)"
  exit 0
fi

# Root check
if [[ $EUID -ne 0 ]]; then
  log_error "Must run as root for package installation"
  exit 1
fi

log_info "START WhisperX dependencies ${DEP_SCRIPT_VERSION}"

# Update package manager
if command_exists apt-get; then
  log_info "Updating package manager..."
  apt-get update >/dev/null 2>&1 || { log_error "Failed to update package manager"; exit 1; }
fi

# Install system dependencies
log_info "Installing system dependencies..."

# FFmpeg (audio/video processing)
if ! command_exists ffmpeg; then
  log_info "Installing ffmpeg..."
  if command_exists apt-get; then
    apt_install ffmpeg || { log_error "Failed to install ffmpeg"; exit 1; }
  else
    log_error "No supported package manager found for ffmpeg"
    exit 1
  fi
else
  log_info "ffmpeg already installed"
fi

# jq (JSON processing)
if ! command_exists jq; then
  log_info "Installing jq..."
  if command_exists apt-get; then
    apt_install jq || { log_error "Failed to install jq"; exit 1; }
  else
    log_error "No supported package manager found for jq"
    exit 1
  fi
else
  log_info "jq already installed"
fi

# yq (YAML processing)
if ! command_exists yq; then
  log_info "Installing yq..."
  if command_exists apt-get; then
    apt_install yq || { log_error "Failed to install yq"; exit 1; }
  else
    log_error "No supported package manager found for yq"
    exit 1
  fi
else
  log_info "yq already installed"
fi

# Python3 and venv
if ! command_exists python3; then
  log_info "Installing python3..."
  if command_exists apt-get; then
    apt_install python3 python3-pip python3-venv || { log_error "Failed to install python3"; exit 1; }
  else
    log_error "No supported package manager found for python3"
    exit 1
  fi
else
  log_info "python3 already installed"
  # Ensure pip and venv are available
  if command_exists apt-get; then
    apt_install python3-pip python3-venv 2>/dev/null || true
  fi
fi

# Create WhisperX Python environment
log_info "Setting up WhisperX Python environment at ${WHISPERX_ENV_PATH}..."

# Create parent directory
mkdir -p "$(dirname "$WHISPERX_ENV_PATH")"

# Remove existing environment if forcing upgrade
if [[ "$ALWAYS_UPGRADE" == "1" ]] && [[ -d "$WHISPERX_ENV_PATH" ]]; then
  log_info "Removing existing WhisperX environment for upgrade..."
  rm -rf "$WHISPERX_ENV_PATH"
fi

# Create virtual environment
if [[ ! -d "$WHISPERX_ENV_PATH" ]]; then
  log_info "Creating Python virtual environment..."
  python3 -m venv "$WHISPERX_ENV_PATH" || { log_error "Failed to create virtual environment"; exit 1; }
fi

# Upgrade pip in the environment
log_info "Upgrading pip in WhisperX environment..."
"$WHISPERX_ENV_PATH/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || { log_error "Failed to upgrade pip"; exit 1; }

# Install WhisperX
log_info "Installing WhisperX (CPU support)..."
"$WHISPERX_ENV_PATH/bin/python" -m pip install whisperx >/dev/null 2>&1 || { log_error "Failed to install WhisperX"; exit 1; }

# Verify installation
log_info "Verifying WhisperX installation..."
if "$WHISPERX_ENV_PATH/bin/python" -c "import whisperx; print('WhisperX version:', whisperx.__version__)" 2>/dev/null; then
  log_info "SUCCESS: WhisperX installed and verified"
else
  log_error "WhisperX installation verification failed"
  exit 1
fi

# Create convenience wrapper script
log_info "Creating WhisperX wrapper script..."
cat > "/usr/local/bin/whisperx" << 'EOF'
#!/bin/bash
exec /app/services/whisper-x/bin/python -m whisperx "$@"
EOF
chmod +x "/usr/local/bin/whisperx"

log_info "SUCCESS: All dependencies installed"
log_info "WhisperX environment: ${WHISPERX_ENV_PATH}"
log_info "WhisperX command: /usr/local/bin/whisperx or ${WHISPERX_ENV_PATH}/bin/python -m whisperx"

exit 0

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr dependencies (audio language detector)
# Purpose: Idempotent installation of required system + python deps (ffmpeg, jq, yq, whisper stack)
# Behavior: Skips anything already present; installs only missing pieces. Uses Arrbit logging if available.
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

# --- Bootstrap logging (silent info unless helpers available) ---
LOG_DIR="/app/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/arrbit-dependencies-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" || true

log_info()    { :; }
log_warning() { echo "[Arrbit] WARNING: $*" | tee -a "$LOG_FILE" >&2; }
log_error()   { echo "[Arrbit] ERROR: $*"   | tee -a "$LOG_FILE" >&2; }

ARRBIT_ROOT="/app/arrbit"
HELPERS_DIR="$ARRBIT_ROOT/helpers"
if [[ -f "$HELPERS_DIR/logging_utils.bash" ]]; then
  # shellcheck disable=SC1091
  source "$HELPERS_DIR/logging_utils.bash"
  if [[ -f "$HELPERS_DIR/helpers.bash" ]]; then
    # shellcheck disable=SC1091
    source "$HELPERS_DIR/helpers.bash"
  fi
  # Define silent info wrapper
  _orig_log_info() { log_info "$@"; }
  log_info() { :; }
fi

# --- Root check (we need package manager access) ---
if [[ $EUID -ne 0 ]]; then
  log_error "Must run as root (container should allow). Aborting."
  exit 1
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get update -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

ensure_ffmpeg() {
  if command_exists ffmpeg; then
    log_info "ffmpeg already present"
  else
    if command_exists apt-get; then
      apt_install ffmpeg >/dev/null 2>&1 || { log_error "Failed installing ffmpeg"; exit 1; }
    else
      log_error "No supported package manager to install ffmpeg"; exit 1
    fi
  fi
}

ensure_jq() {
  if command_exists jq; then
    log_info "jq present"
  else
    if command_exists apt-get; then
      apt_install jq >/dev/null 2>&1 || { log_error "Failed installing jq"; exit 1; }
    else
      # fallback binary download
      curl -fsSL -o /bin/jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" && chmod +x /bin/jq || {
        log_error "Failed to install jq"; exit 1; }
    fi
  fi
}

ensure_yq() {
  if command_exists yq; then
    log_info "yq present"
  else
    # Install mikefarah yq static binary
    local ver="v4.44.3"
    curl -fsSL -o /bin/yq "https://github.com/mikefarah/yq/releases/download/${ver}/yq_linux_amd64" && chmod +x /bin/yq || {
      log_error "Failed to install yq"; exit 1; }
  fi
}

ensure_python() {
  if command_exists python3; then
    PYTHON_CMD=python3
  elif command_exists python; then
    PYTHON_CMD=python
  else
    if command_exists apt-get; then
      apt_install python3 python3-pip >/dev/null 2>&1 || { log_error "Failed installing python3"; exit 1; }
      PYTHON_CMD=python3
    else
      log_error "No supported package manager to install Python"; exit 1
    fi
  fi
  if ! command_exists pip3 && ! command_exists pip; then
    if command_exists apt-get; then
      apt_install python3-pip >/dev/null 2>&1 || { log_error "Failed installing pip"; exit 1; }
    fi
  fi
  if command_exists pip3; then PIP_CMD=pip3; else PIP_CMD=pip; fi
  export PYTHON_CMD PIP_CMD
}

ensure_python_pkg() {
  local pkg="$1"; shift || true
  local import_name="${1:-$pkg}"
  if "$PYTHON_CMD" - <<EOF 2>/dev/null
import importlib, sys
sys.exit(0 if importlib.util.find_spec("${import_name}") else 1)
EOF
  then
    log_info "python pkg ${pkg} present"
  else
    "$PIP_CMD" install --no-cache-dir "$pkg" >/dev/null 2>&1 || { log_error "Failed installing python package ${pkg}"; exit 1; }
  fi
}

ensure_whisper_stack() {
  # torch first (CPU)
  if ! "$PYTHON_CMD" - <<'EOF' 2>/dev/null; then
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('torch') else 1)
EOF
  then
    # generic pip torch (CPU)
    "$PIP_CMD" install --no-cache-dir torch >/dev/null 2>&1 || log_warning "Torch generic install failed (continuing if already available)"
  fi
  ensure_python_pkg "numpy" "numpy"
  ensure_python_pkg "ffmpeg-python" "ffmpeg"
  ensure_python_pkg "openai-whisper" "whisper"
}

summary() {
  echo "[Arrbit] Dependencies setup complete." | tee -a "$LOG_FILE"
}

ensure_ffmpeg
ensure_jq
ensure_yq
ensure_python
ensure_whisper_stack
summary

exit 0
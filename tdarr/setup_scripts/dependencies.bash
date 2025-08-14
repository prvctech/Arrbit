#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr dependencies (audio language detector)
# Version: v1.1.0-gs2.8.3
# Purpose: Idempotent installation of required system + python deps (ffmpeg, jq, yq, whisper stack)
# Behavior: Skips anything already present; installs only missing pieces. Uses Arrbit logging if available.
# Added: version gating, verification, per-step file logging, optional venv (ARRBIT_DEPS_VENV=1), force override with ARRBIT_FORCE_DEPS=1
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v1.1.0-gs2.8.3"
VERSION_FILE="/app/arrbit/setup/.dependencies_version"
USE_VENV="${ARRBIT_DEPS_VENV:-0}"
FORCE="${ARRBIT_FORCE_DEPS:-0}"

# --- Bootstrap logging (silent info unless helpers available) ---
LOG_DIR="/app/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/arrbit-dependencies-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" || true

log_info()    { :; }
log_warning() { echo "[Arrbit] WARNING: $*" | tee -a "$LOG_FILE" >&2; }
log_error()   { echo "[Arrbit] ERROR: $*"   | tee -a "$LOG_FILE" >&2; }

# Always-write step logger (file only, silent to terminal)
log_step()   { echo "[Arrbit] STEP: $*" >> "$LOG_FILE"; }
log_start()  { echo "[Arrbit] START dependencies ${DEP_SCRIPT_VERSION}" >> "$LOG_FILE"; }
log_skip()   { echo "[Arrbit] SKIP: $*" >> "$LOG_FILE"; }
log_done()   { echo "[Arrbit] DONE: $*" >> "$LOG_FILE"; }

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

log_start

command_exists() { command -v "$1" >/dev/null 2>&1; }

apt_install() {
  log_step "apt installing: $*"
  DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1
}

# --- Early version gating (skip if already satisfied) ---
all_present_minimal() {
  command_exists ffmpeg && \
  command_exists jq && \
  command_exists yq && \
  { command_exists python3 || command_exists python; } && \
  python_module_present torch && \
  python_module_present numpy && \
  python_module_present whisper && \
  python_module_present ffmpeg
}

python_module_present() {
  local m="$1"
  if ! command_exists "${PYTHON_CMD:-python3}" && ! command_exists python3 && ! command_exists python; then
    return 1
  fi
  local py="${PYTHON_CMD:-$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)}"
  "$py" - <<EOF 2>/dev/null
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('${m}') else 1)
EOF
}

if [[ -f "$VERSION_FILE" && $FORCE -ne 1 ]]; then
  CURRENT_VER=$(<"$VERSION_FILE") || CURRENT_VER=""
  if [[ "$CURRENT_VER" == "$DEP_SCRIPT_VERSION" ]] && all_present_minimal; then
    log_skip "Dependencies already at ${CURRENT_VER}; use ARRBIT_FORCE_DEPS=1 to force reinstall."
    echo "[Arrbit] dependencies already satisfied" >> "$LOG_FILE"
    exit 0
  fi
fi

ensure_ffmpeg() {
  if command_exists ffmpeg; then
    log_step "ffmpeg present"
  else
    if command_exists apt-get; then
      apt_install ffmpeg || { log_error "Failed installing ffmpeg"; exit 1; }
    else
      log_error "No supported package manager to install ffmpeg"; exit 1
    fi
    log_step "ffmpeg installed"
  fi
}

ensure_jq() {
  if command_exists jq; then
    log_step "jq present"
  else
    if command_exists apt-get; then
      apt_install jq || { log_error "Failed installing jq"; exit 1; }
    else
      curl -fsSL -o /bin/jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" && chmod +x /bin/jq || {
        log_error "Failed to install jq"; exit 1; }
    fi
    log_step "jq installed"
  fi
}

ensure_yq() {
  if command_exists yq; then
    log_step "yq present"
  else
    local ver="v4.44.3"
    curl -fsSL -o /bin/yq "https://github.com/mikefarah/yq/releases/download/${ver}/yq_linux_amd64" && chmod +x /bin/yq || {
      log_error "Failed to install yq"; exit 1; }
    log_step "yq installed (${ver})"
  fi
}

ensure_python() {
  if command_exists python3; then
    PYTHON_CMD=python3
  elif command_exists python; then
    PYTHON_CMD=python
  else
    if command_exists apt-get; then
      apt_install python3 python3-pip || { log_error "Failed installing python3"; exit 1; }
      PYTHON_CMD=python3
    else
      log_error "No supported package manager to install Python"; exit 1
    fi
  fi
  if ! command_exists pip3 && ! command_exists pip; then
    if command_exists apt-get; then
      apt_install python3-pip || { log_error "Failed installing pip"; exit 1; }
    fi
  fi
  if command_exists pip3; then PIP_CMD=pip3; else PIP_CMD=pip; fi

  # Optional venv
  if [[ "$USE_VENV" == "1" ]]; then
    if ! python3 -c 'import venv' 2>/dev/null; then
      if command_exists apt-get; then apt_install python3-venv || log_warning "python3-venv install failed"; fi
    fi
    VENV_DIR="/app/arrbit/venv"
    if [[ ! -d "$VENV_DIR" ]]; then
      log_step "creating venv $VENV_DIR"
      "$PYTHON_CMD" -m venv "$VENV_DIR" || log_warning "venv creation failed; falling back to system"
    fi
    if [[ -d "$VENV_DIR" ]]; then
      # shellcheck disable=SC1091
      source "$VENV_DIR/bin/activate"
      PYTHON_CMD="$VENV_DIR/bin/python"
      PIP_CMD="$VENV_DIR/bin/pip"
      log_step "using venv python: $PYTHON_CMD"
    fi
  fi

  export PYTHON_CMD PIP_CMD
  log_step "python cmd: $PYTHON_CMD; pip cmd: $PIP_CMD"
}

ensure_python_pkg() {
  local pkg="$1"; shift || true
  local import_name="${1:-$pkg}"
  if "$PYTHON_CMD" - <<EOF 2>/dev/null
import importlib, sys
sys.exit(0 if importlib.util.find_spec("${import_name}") else 1)
EOF
  then
    log_step "python pkg ${pkg} present"
  else
    log_step "installing python pkg ${pkg}"
    "$PIP_CMD" install --no-cache-dir "$pkg" >/dev/null 2>&1 || { log_error "Failed installing python package ${pkg}"; exit 1; }
  fi
}

ensure_whisper_stack() {
  if ! "$PYTHON_CMD" - <<'EOF' 2>/dev/null; then
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('torch') else 1)
EOF
  then
    log_step "installing torch (cpu)"
    "$PIP_CMD" install --no-cache-dir torch >/dev/null 2>&1 || log_warning "Torch generic install failed (continuing if already available)"
  else
    log_step "torch present"
  fi
  ensure_python_pkg "numpy" "numpy"
  ensure_python_pkg "ffmpeg-python" "ffmpeg"
  ensure_python_pkg "openai-whisper" "whisper"
}

verify() {
  log_step "verifying installation"
  local missing=0
  for c in ffmpeg jq yq; do
    if ! command_exists "$c"; then log_error "Missing command after install: $c"; missing=1; fi
  done
  for m in torch numpy whisper ffmpeg; do
    if ! python_module_present "$m"; then log_error "Missing python module after install: $m"; missing=1; fi
  done
  if [[ $missing -ne 0 ]]; then
    log_error "One or more dependencies missing after attempted installation. Consider ARRBIT_FORCE_DEPS=1 to retry."
    exit 1
  fi
  log_step "verification passed"
}

summary() {
  echo "[Arrbit] Dependencies setup complete (${DEP_SCRIPT_VERSION})." | tee -a "$LOG_FILE"
  echo "$DEP_SCRIPT_VERSION" > "$VERSION_FILE" || true
}

ensure_ffmpeg
ensure_jq
ensure_yq
ensure_python
ensure_whisper_stack
verify
summary

exit 0
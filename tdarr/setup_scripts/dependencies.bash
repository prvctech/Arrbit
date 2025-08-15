#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr dependencies (audio language detector)
# Version: v1.5.1-gs2.8.3
# Purpose: Idempotent installation of required system + python deps (ffmpeg, jq, yq, whisper stack)
# Behavior: Skips anything already present; installs only missing pieces. Uses Arrbit logging if available.
# Added: version gating, verification, per-step file logging, optional venv (ARRBIT_DEPS_VENV=1), force override with ARRBIT_FORCE_DEPS=1
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

DEP_SCRIPT_VERSION="v1.5.1-gs2.8.3"
VERSION_FILE="/app/arrbit/setup/.dependencies_version"
USE_VENV="${ARRBIT_DEPS_VENV:-0}"
FORCE="${ARRBIT_FORCE_DEPS:-0}"
ALWAYS_UPGRADE="${ARRBIT_ALWAYS_UPGRADE:-1}"  # when 1, ignore version gating and force upgrade of python deps
PREFER_TDARR_GPU="${ARRBIT_PREFER_TDARR_GPU:-1}"
WHISPER_MODEL_RETRY="${ARRBIT_WHISPER_MODEL_RETRY:-1}"  # retry model download with pip re-install if apt build failed

# --- Bootstrap logging (Golden Standard) ---
LOG_DIR="/app/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/arrbit-dependencies-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" || true

ARRBIT_ROOT="/app/arrbit"
HELPERS_DIR="$ARRBIT_ROOT/helpers"
# Source golden standard logging + helpers (should exist due to setup)
if [[ -f "$HELPERS_DIR/logging_utils.bash" ]]; then
  # shellcheck disable=SC1091
  source "$HELPERS_DIR/logging_utils.bash"
fi
if [[ -f "$HELPERS_DIR/helpers.bash" ]]; then
  # shellcheck disable=SC1091
  source "$HELPERS_DIR/helpers.bash"
fi
arrbitPurgeOldLogs

# Silent mode: suppress info to terminal only (keep full log output)
if declare -f log_info >/dev/null 2>&1; then
  _orig_log_info() {
    # Log: Plain, no color
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '[Arrbit] %s\n' "$*" >> "$LOG_FILE"
    fi
  }
  log_info() { _orig_log_info "$@"; }
fi

# --- Root check (we need package manager access) ---
if [[ $EUID -ne 0 ]]; then
  log_error "Must run as root (container should allow). Aborting."
  exit 1
fi

log_info "START dependencies ${DEP_SCRIPT_VERSION}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

APT_UPDATED=0
APT_CLEAN_FLAG="${ARRBIT_APT_CLEAN:-0}"
APT_SKIP="${ARRBIT_SKIP_APT:-0}"

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-unknown}"
  else
    OS_ID="unknown"
  fi
}

detect_os

apt_install() {
  [[ $APT_SKIP -eq 1 ]] && { log_warning "APT skipped by ARRBIT_SKIP_APT=1 (requested pkgs: $*)"; return 0; }
  if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
    log_warning "Non-Debian/Ubuntu OS detected ($OS_ID). Skipping apt install for: $*"
    return 0
  fi
  if [[ $APT_UPDATED -eq 0 ]]; then
    log_info "apt updating package index (first call)"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || { log_error "apt-get update failed"; exit 1; }
    APT_UPDATED=1
  fi
  log_info "apt installing: $*"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1 || { log_error "apt-get install failed for: $*"; exit 1; }
}

apt_maybe_clean() {
  if [[ $APT_CLEAN_FLAG -eq 1 && $APT_UPDATED -eq 1 ]]; then
    log_info "apt cleaning artifact lists"
    apt-get clean >/dev/null 2>&1 || true
    rm -rf /var/lib/apt/lists/* || true
  fi
}

# Detect if stdlib importlib is being shadowed by a local file (causes AttributeError: no attribute 'util')
debug_importlib_shadow() {
  local py_cmd="${PYTHON_CMD:-python3}"
  if ! command_exists "$py_cmd"; then return 0; fi
  local meta
  meta=$("$py_cmd" - <<'EOF' 2>/dev/null || true
import sys, os
import importlib
path = getattr(importlib, '__file__', 'UNKNOWN')
std = 'OK' if '/lib/python3' in path else 'SUSPECT'
try:
    import importlib.util as _util
    has_util = True
except Exception:
    has_util = False
print(f"IMPORTLIB_FILE={path}")
print(f"IMPORTLIB_STD={std}")
print(f"IMPORTLIB_HAS_UTIL={has_util}")
if std == 'SUSPECT':
    print('SYSPATH_HEAD=' + ';'.join(sys.path[:5]))
EOF
  )
  if [[ -n "$meta" ]]; then
    while IFS= read -r line; do log_info "debug ${line}"; done <<<"$meta"
    if echo "$meta" | grep -q 'IMPORTLIB_STD=SUSPECT'; then
      log_warning "Non-standard importlib detected. Potential stdlib shadowing."
    fi
    # Only fatal if util truly cannot be imported; current test already tries to import
    if echo "$meta" | grep -q 'IMPORTLIB_HAS_UTIL=False'; then
      log_error "importlib.util failed to import; investigate shadowing (search for importlib.py)."
    fi
  fi
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

if [[ "$ALWAYS_UPGRADE" != "1" ]]; then
  if [[ -f "$VERSION_FILE" && $FORCE -ne 1 ]]; then
    CURRENT_VER=$(<"$VERSION_FILE") || CURRENT_VER=""
    if [[ "$CURRENT_VER" == "$DEP_SCRIPT_VERSION" ]] && all_present_minimal; then
      log_info "Dependencies already at ${CURRENT_VER}; use ARRBIT_FORCE_DEPS=1 to force reinstall (ALWAYS_UPGRADE=0)."
      log_info "dependencies already satisfied"
      exit 0
    fi
  fi
else
  log_info "ALWAYS_UPGRADE=1 -> skipping version gating and forcing upgrade of python packages"
fi

ensure_ffmpeg() {
  if command_exists ffmpeg; then
    log_info "ffmpeg present"
  else
    if command_exists apt-get; then
      apt_install ffmpeg || { log_error "Failed installing ffmpeg"; exit 1; }
    else
      log_error "No supported package manager to install ffmpeg"; exit 1
    fi
    log_info "ffmpeg installed"
  fi
}

ensure_jq() {
  if command_exists jq; then
    log_info "jq present"
  else
    if command_exists apt-get; then
      apt_install jq || { log_error "Failed installing jq"; exit 1; }
    else
      curl -fsSL -o /bin/jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" && chmod +x /bin/jq || {
        log_error "Failed to install jq"; exit 1; }
    fi
    log_info "jq installed"
  fi
}

ensure_yq() {
  if command_exists yq; then
    log_info "yq present"
  else
    local ver="v4.44.3"
    if ! curl -fsSL -o /bin/yq "https://github.com/mikefarah/yq/releases/download/${ver}/yq_linux_amd64" 2>/dev/null; then
      log_warning "primary yq download failed; retrying with --retry"
      if ! curl --retry 3 --retry-delay 2 -fsSL -o /bin/yq "https://github.com/mikefarah/yq/releases/download/${ver}/yq_linux_amd64" 2>/dev/null; then
        log_error "Failed to download yq binary"
        exit 1
      fi
    fi
    chmod +x /bin/yq || { log_error "Failed chmod yq"; exit 1; }
    if ! command_exists yq; then
      log_error "yq still not in PATH after install"; exit 1; fi
    log_info "yq installed (${ver})"
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
  if command_exists pip3; then PIP_CMD=pip3; elif command_exists pip; then PIP_CMD=pip; else PIP_CMD=""; fi

  # Optional venv
  if [[ "$USE_VENV" == "1" ]]; then
    if ! python3 -c 'import venv' 2>/dev/null; then
      if command_exists apt-get; then apt_install python3-venv || log_warning "python3-venv install failed"; fi
    fi
    VENV_DIR="/app/arrbit/venv"
    if [[ ! -d "$VENV_DIR" ]]; then
      log_info "creating venv $VENV_DIR"
      "$PYTHON_CMD" -m venv "$VENV_DIR" || log_warning "venv creation failed; falling back to system"
    fi
    if [[ -d "$VENV_DIR" ]]; then
      # shellcheck disable=SC1091
      source "$VENV_DIR/bin/activate"
      PYTHON_CMD="$VENV_DIR/bin/python"
      PIP_CMD="$VENV_DIR/bin/pip"
      log_info "using venv python: $PYTHON_CMD"
    fi
  fi

  export PYTHON_CMD PIP_CMD
  log_info "python cmd: $PYTHON_CMD; pip cmd: $PIP_CMD"
}

ensure_pip() {
  if [[ -n "${PIP_CMD:-}" ]] && command_exists "$PIP_CMD"; then
    log_info "pip present ($PIP_CMD)"
    return 0
  fi
  log_info "pip missing; attempting install"
  if command_exists apt-get; then
    apt_install python3-pip || log_warning "apt python3-pip install failed; trying get-pip.py"
  fi
  if ! command_exists pip3 && ! command_exists pip; then
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py || { log_error "Failed to download get-pip.py"; exit 1; }
    "$PYTHON_CMD" /tmp/get-pip.py >/dev/null 2>&1 || { log_error "get-pip.py execution failed"; exit 1; }
  fi
  if command_exists pip3; then PIP_CMD=pip3; elif command_exists pip; then PIP_CMD=pip; else
    log_error "pip still not found after installation attempts"; exit 1
  fi
  export PIP_CMD
  log_info "pip ready: $PIP_CMD"
}

ensure_python_pkg() {
  local pkg="$1"; shift || true
  local import_name="${1:-$pkg}"
  local present=1
  if "$PYTHON_CMD" - 2>/dev/null <<EOF
import importlib, sys
sys.exit(0 if importlib.util.find_spec("${import_name}") else 1)
EOF
  then present=0; fi
  if [[ $present -eq 0 && "$ALWAYS_UPGRADE" != "1" ]]; then
    log_info "python pkg ${pkg} present"
    return 0
  fi
  if [[ $present -eq 0 && "$ALWAYS_UPGRADE" == "1" ]]; then
    log_info "upgrading python pkg ${pkg} (present)"
  else
    log_info "installing python pkg ${pkg}"
  fi
  "$PIP_CMD" install --no-cache-dir --upgrade "$pkg" >/dev/null 2>&1 || { log_error "Failed installing/upgrading python package ${pkg}"; exit 1; }
}

ensure_whisper_stack() {
  ensure_torch_gpu_aware
  ensure_python_pkg "numpy" "numpy"
  ensure_python_pkg "ffmpeg-python" "ffmpeg"
  ensure_whisper_module
}

# Decide and install appropriate torch build based on GPU flags + detection
ensure_torch_gpu_aware() {
  # Fast path if torch already importable
  if "$PYTHON_CMD" - 2>/dev/null <<'EOF'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('torch') else 1)
EOF
  then
    if [[ "$ALWAYS_UPGRADE" == "1" ]]; then
      log_info "torch present but ALWAYS_UPGRADE=1 -> re-evaluating install for upgrade"
    else
      log_info "torch present"
      return 0
    fi
  fi

  local gpu_flag="off" gpu_type="" cfg_gpu cfg_type env_gpu env_type tdarr_pair tdarr_flag tdarr_type
  local decision_log=""
  # Tdarr-derived pair (if preferred)
  tdarr_pair="$(detect_gpu_from_tdarr)"
  tdarr_flag="${tdarr_pair%%|*}"; tdarr_type="${tdarr_pair##*|}"

  # Gather from config via helpers if available
  if declare -f getFlag >/dev/null 2>&1; then
    local prev_cfg="${CONFIG_DIR:-}"
    export CONFIG_DIR="/app/arrbit/config"
    cfg_gpu="$(getFlag "GPU" 2>/dev/null || true)" || true
    cfg_type="$(getFlag "GPU_TYPE" 2>/dev/null || true)" || true
    [[ -n "$prev_cfg" ]] && export CONFIG_DIR="$prev_cfg" || unset CONFIG_DIR
  else
    if [[ -f /app/arrbit/config/arrbit-config.conf ]]; then
      cfg_gpu="$(awk -F '=' 'toupper($1)=="GPU"{gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/"/,"",$2); print tolower($2); exit}' /app/arrbit/config/arrbit-config.conf 2>/dev/null || true)"
      cfg_type="$(awk -F '=' 'toupper($1)=="GPU_TYPE"{gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/"/,"",$2); print tolower($2); exit}' /app/arrbit/config/arrbit-config.conf 2>/dev/null || true)"
    fi
  fi
  # Env overrides
  env_gpu="${ARRBIT_GPU:-}"; env_type="${ARRBIT_GPU_TYPE:-}"

  # Precedence: Explicit env > explicit config > Tdarr auto > default off
  if [[ -n "$env_gpu" ]]; then
    gpu_flag="${env_gpu,,}"
    decision_log+="env_gpu=${env_gpu,,};"
  elif [[ -n "$cfg_gpu" ]]; then
    gpu_flag="${cfg_gpu,,}"
    decision_log+="cfg_gpu=${cfg_gpu,,};"
  elif [[ "$tdarr_flag" == "on" ]]; then
    gpu_flag="on"
    decision_log+="tdarr_gpu=on;"
  fi

  if [[ -n "$env_type" ]]; then
    gpu_type="${env_type,,}"; decision_log+="env_type=${gpu_type};"
  elif [[ -n "$cfg_type" ]]; then
    gpu_type="${cfg_type,,}"; decision_log+="cfg_type=${gpu_type};"
  elif [[ -n "$tdarr_type" ]]; then
    gpu_type="${tdarr_type,,}"; decision_log+="tdarr_type=${gpu_type};"
  fi

  # If config explicitly sets GPU_TYPE=intel suppress any accidental nvidia detection to avoid false positives
  if [[ -n "$cfg_type" && "${cfg_type,,}" == "intel" ]]; then
    if [[ "$gpu_flag" == "on" ]]; then
      decision_log+="suppress_nvidia_for_intel=1;"
      log_info "config GPU_TYPE=intel -> ignoring any incidental NVIDIA device exposure (Intel path is CPU fallback)"
    fi
  fi

  # If config GPU_TYPE is explicit (intel/nvidia/amd) trust it over Tdarr auto
  if [[ -n "$cfg_type" ]]; then
    gpu_type="${cfg_type,,}"; decision_log+="trust_cfg_type=1;"
  fi

  [[ -z "$gpu_flag" ]] && gpu_flag="off"

  if [[ "$gpu_flag" != "on" ]]; then
    log_info "GPU disabled -> installing torch (CPU) [$decision_log]"
    install_torch_cpu
    return 0
  fi

  # Auto-detect type if still blank
  if [[ -z "$gpu_type" ]]; then
    gpu_type="$(auto_detect_gpu_type)"; decision_log+="auto_type=${gpu_type};"
    log_info "auto-detected GPU type: ${gpu_type:-none} [$decision_log]" || true
  else
    log_info "resolved GPU type: ${gpu_type} [$decision_log]"
  fi

  case "$gpu_type" in
    nvidia)
      install_torch_nvidia || { log_warning "NVIDIA torch install failed; falling back to CPU"; install_torch_cpu; }
      ;;
    amd)
      install_torch_amd || { log_warning "AMD torch install failed; falling back to CPU"; install_torch_cpu; }
      ;;
    intel)
      log_info "Intel selected -> using CPU torch (no native Intel GPU wheel configured)"
      install_torch_intel || { log_warning "Intel torch install wrapper failed; falling back to CPU"; install_torch_cpu; }
      ;;
    ""|none)
      log_info "No GPU type resolved -> CPU"
      install_torch_cpu
      ;;
    *)
      log_warning "Unknown GPU type '${gpu_type}' -> CPU"
      install_torch_cpu
      ;;
  esac

  # Post-install validation: if CUDA/ROCm wheel present but backend unusable, fallback to CPU torch (one retry)
  "$PYTHON_CMD" - <<'EOF' >/tmp/.arrbit_cuda_check 2>&1 || true
import torch, sys
usable = torch.cuda.is_available()
print('CUDA_USABLE=', '1' if usable else '0')
EOF
  if grep -q 'CUDA_USABLE=0' /tmp/.arrbit_cuda_check 2>/dev/null; then
    if python3 -c 'import torch,sys;import re;ver=torch.__version__;sys.exit(0 if "+cu" in ver else 1)' 2>/dev/null; then
      log_warning "GPU wheel installed but CUDA not usable -> reinstalling CPU torch"
      install_torch_cpu
    fi
  fi
}

auto_detect_gpu_type() {
  # nvidia-smi available
  if command_exists nvidia-smi || lspci 2>/dev/null | grep -qi 'nvidia'; then echo nvidia; return 0; fi
  # AMD detection via rocm-smi or lspci
  if command_exists rocm-smi || lspci 2>/dev/null | grep -Eqi 'amd|advanced micro devices'; then echo amd; return 0; fi
  # Intel detection (i915 driver / lspci)
  if lsmod 2>/dev/null | grep -q i915 || lspci 2>/dev/null | grep -qi 'intel'; then echo intel; return 0; fi
  echo ""
}

# Tdarr-assisted GPU detection. Output format: "<flag>|<type>" (flag on/off, type nvidia/amd/intel/blank)
detect_gpu_from_tdarr() {
  local flag="off" type=""
  [[ "$PREFER_TDARR_GPU" != "1" ]] && { echo "${flag}|${type}"; return 0; }

  # Explicit Tdarr envs (if user exported them when launching container)
  if [[ -n "${TDARR_GPU:-}" ]]; then
    case "${TDARR_GPU,,}" in
      1|true|on) flag="on" ;;
    esac
  fi
  if [[ -n "${TDARR_GPU_TYPE:-}" ]]; then
    type="${TDARR_GPU_TYPE,,}"
  fi

  # Generic device hints if not explicitly set
  if [[ "$flag" == "off" ]]; then
    if [[ -n "${NVIDIA_VISIBLE_DEVICES:-}" || -e /dev/nvidia0 || -e /dev/nvidiactl ]]; then
      flag="on"; [[ -z "$type" ]] && type="nvidia"
    fi
    if [[ -e /dev/kfd || $(command -v rocm-smi 2>/dev/null) ]]; then
      flag="on"; [[ -z "$type" ]] && type="amd"
    fi
    if compgen -G "/dev/dri/renderD*" >/dev/null 2>&1; then
      flag="on"; [[ -z "$type" ]] && type="intel"
    fi
  fi
  echo "${flag}|${type}"
}

install_torch_cpu() {
  if [[ "$ALWAYS_UPGRADE" == "1" ]]; then
    log_info "install/upgrade torch (CPU)"
    "$PIP_CMD" install --no-cache-dir --upgrade torch >/dev/null 2>&1 || log_warning "torch CPU install/upgrade failed"
  else
    log_info "installing torch (CPU)"
    "$PIP_CMD" install --no-cache-dir torch >/dev/null 2>&1 || log_warning "torch CPU install failed"
  fi
}

install_torch_nvidia() {
  log_info "install/upgrade torch (CUDA)"
  local extra="--index-url https://download.pytorch.org/whl/cu121"
  if [[ "$ALWAYS_UPGRADE" == "1" ]]; then
    "$PIP_CMD" install --no-cache-dir --upgrade torch ${extra} >/dev/null 2>&1 || return 1
  else
    "$PIP_CMD" install --no-cache-dir torch ${extra} >/dev/null 2>&1 || return 1
  fi
  return 0
}

install_torch_amd() {
  log_info "install/upgrade torch (ROCm)"
  local extra="--index-url https://download.pytorch.org/whl/rocm6.0"
  if [[ "$ALWAYS_UPGRADE" == "1" ]]; then
    "$PIP_CMD" install --no-cache-dir --upgrade torch ${extra} >/dev/null 2>&1 || return 1
  else
    "$PIP_CMD" install --no-cache-dir torch ${extra} >/dev/null 2>&1 || return 1
  fi
  return 0
}

install_torch_intel() {
  log_info "install/upgrade torch (Intel fallback -> CPU)"
  install_torch_cpu
}

# Log runtime detected GPU (torch) capabilities for visibility
log_gpu_capabilities() {
  if ! "$PYTHON_CMD" - <<'EOF' 2>/dev/null
import sys
try:
    import torch
except Exception as e:
    print('[Arrbit] torch not importable for GPU capability logging', e)
    sys.exit(0)
backend = 'cuda' if torch.cuda.is_available() else ('mps' if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available() else 'cpu')
print('[Arrbit] torch backend primary:', backend)
if torch.cuda.is_available():
    print('[Arrbit] cuda device count:', torch.cuda.device_count())
    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        print(f'[Arrbit] cuda device {i}: {props.name} CC {props.major}.{props.minor} VRAM {props.total_memory//(1024**2)}MB')
try:
    import subprocess, re
    if subprocess.run(['nvidia-smi'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        print('[Arrbit] nvidia-smi present')
except Exception:
    pass
EOF
  then
    log_warning "GPU capability logging encountered an error"
  fi
}

# Attempt to provide whisper via apt first (if desired) then fallback to pip
ensure_whisper_module() {
  local prefer_apt="${WHISPER_PREFER_APT:-1}"
  # Quick presence check
  if "$PYTHON_CMD" - 2>/dev/null <<'EOF'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('whisper') else 1)
EOF
  then
    if [[ "$ALWAYS_UPGRADE" == "1" ]]; then
      log_info "openai-whisper present but ALWAYS_UPGRADE=1 -> upgrading"
    else
      log_info "python pkg openai-whisper present"
      return 0
    fi
  fi
  if [[ $prefer_apt -eq 1 ]] && command_exists apt-get; then
    log_info "attempting apt install python3-whisper"
    if apt_install python3-whisper; then
      if "$PYTHON_CMD" - 2>/dev/null <<'EOF'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('whisper') else 1)
EOF
      then
        log_info "whisper installed via apt"
        return 0
      else
        log_warning "apt python3-whisper succeeded but module not importable; falling back to pip"
      fi
    else
      log_warning "apt python3-whisper install failed; will fallback to pip"
    fi
  fi
  log_info "install/upgrade python pkg openai-whisper via pip (fallback)"
  if [[ "$ALWAYS_UPGRADE" == "1" ]]; then
    "$PIP_CMD" install --no-cache-dir --upgrade openai-whisper >/dev/null 2>&1 || { log_error "Failed upgrading openai-whisper"; exit 1; }
  else
    "$PIP_CMD" install --no-cache-dir openai-whisper >/dev/null 2>&1 || { log_error "Failed installing openai-whisper"; exit 1; }
  fi
  if ! "$PYTHON_CMD" - 2>/dev/null <<'EOF'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('whisper') else 1)
EOF
  then
    log_error "whisper module still missing after pip install"; exit 1
  fi
  log_info "whisper installed via pip"
}

# Resolve whisper model choice from config or env and optionally pre-download
prepare_whisper_model() {
  local skip="${ARRBIT_SKIP_WHISPER_MODEL:-0}"
  [[ $skip -eq 1 ]] && { log_info "skipping whisper model download (ARRBIT_SKIP_WHISPER_MODEL=1)"; return 0; }

  local model_env="${ARRBIT_WHISPER_MODEL:-}" \
        config_model="" chosen="" allowed="tiny base small turbo" default_model="tiny"

  # Try helpers getFlag if available, adjusting CONFIG_DIR to Arrbit path if needed
  if declare -f getFlag >/dev/null 2>&1; then
    local prev_cfg="${CONFIG_DIR:-}"
    export CONFIG_DIR="/app/arrbit/config"
    config_model="$(getFlag "WHISPER_MODEL" 2>/dev/null || true)"
    [[ -n "$prev_cfg" ]] && export CONFIG_DIR="$prev_cfg" || unset CONFIG_DIR
  else
    # Fallback manual parse
    if [[ -f /app/arrbit/config/arrbit-config.conf ]]; then
      config_model="$(awk -F '=' 'toupper($1)=="WHISPER_MODEL"{gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/"/,"",$2); print tolower($2); exit}' /app/arrbit/config/arrbit-config.conf 2>/dev/null || true)"
    fi
  fi

  if [[ -n "$model_env" ]]; then
    chosen="${model_env,,}"
  elif [[ -n "$config_model" ]]; then
    chosen="${config_model,,}"
  else
    chosen="$default_model"
  fi

  if ! grep -qw "$chosen" <(echo "$allowed"); then
    log_warning "Unsupported WHISPER_MODEL '$chosen'; falling back to '$default_model' (allowed: $allowed)"
    chosen="$default_model"
  fi

  log_info "whisper model selected: $chosen"

  # Force download (cache) using python so later usage is fast; capture error reason
  if ! "$PYTHON_CMD" - 2>/tmp/.arrbit_whisper_download 1>&2 <<EOF; then
import whisper, sys, traceback
model = "${chosen}"
print("[Arrbit] pre-downloading whisper model:", model)
try:
    whisper.load_model(model)
    print("[Arrbit] whisper model ready:", model)
except Exception as e:
    print("[Arrbit] ERROR downloading model", model, e)
    traceback.print_exc(limit=1)
    sys.exit(1)
EOF
    log_warning "whisper model '${chosen}' pre-download failed; see /tmp/.arrbit_whisper_download"
    if [[ "$WHISPER_MODEL_RETRY" == "1" ]]; then
      if [[ "${prefer_apt:-}" == "1" ]]; then
        log_info "retrying model by upgrading openai-whisper via pip"
        "$PIP_CMD" install --no-cache-dir --upgrade openai-whisper >/dev/null 2>&1 || log_warning "pip upgrade openai-whisper failed during retry"
        if "$PYTHON_CMD" - 2>/dev/null <<EOF
import whisper, sys
import sys
try:
    whisper.load_model("${chosen}")
    print('[Arrbit] whisper retry model ready: ${chosen}')
except Exception as e:
    print('[Arrbit] whisper retry still failing:', e)
    sys.exit(1)
EOF
        then
          log_info "whisper model '${chosen}' downloaded after pip retry"
        else
          log_warning "whisper model '${chosen}' still failing after retry (lazy load will attempt later)"
        fi
      fi
    fi
  fi
}

# Ensure whisper CLI wrapper in /bin for consistent path usage
ensure_whisper_wrapper() {
  if command -v whisper >/dev/null 2>&1; then
    log_info "whisper CLI present ($(command -v whisper))"
    return 0
  fi
  if ! "$PYTHON_CMD" - 2>/dev/null <<'EOF'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('whisper') else 1)
EOF
  then
    log_warning "cannot create whisper CLI wrapper; module not present"
    return 0
  fi
  cat >/bin/whisper <<'WRAP'
#!/usr/bin/env bash
exec python3 -m whisper "$@"
WRAP
  chmod +x /bin/whisper || { log_warning "failed to chmod /bin/whisper"; return 0; }
  log_info "created whisper CLI wrapper /bin/whisper"
}

verify() {
  log_info "verifying installation"
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
  log_info "verification passed"
}

summary() {
  echo "[Arrbit] Dependencies setup complete (${DEP_SCRIPT_VERSION})." | tee -a "$LOG_FILE"
  echo "$DEP_SCRIPT_VERSION" > "$VERSION_FILE" || true
  apt_maybe_clean
}

ensure_ffmpeg
ensure_jq
ensure_yq
ensure_python
ensure_pip
debug_importlib_shadow
ensure_whisper_stack
prepare_whisper_model
ensure_whisper_wrapper
log_gpu_capabilities
verify
summary

exit 0
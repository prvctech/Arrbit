﻿#!/usr/bin/env bash
# shellcheck shell=bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - WhisperX dependencies (fully isolated)
# Version: v2.1.3-gs2.8.3
# Purpose: Install system deps + WhisperX in isolated env at /app/arrbit/environments/whisperx-env (flattened structure)
# Silent to terminal; verbose logging to /app/arrbit/data/logs
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

DEP_SCRIPT_VERSION="v2.1.3-gs2.8.3"
ARRBIT_BASE="/app/arrbit"
HELPERS_DIR="${ARRBIT_BASE}/helpers"
ENV_DIR="${ARRBIT_BASE}/environments"
WHISPERX_ENV_PATH="${ENV_DIR}/whisperx-env"
ALWAYS_UPGRADE="${ARRBIT_FORCE_DEPS:-0}"

LOG_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
chmod 777 "${LOG_DIR}" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/dependencies-$(date '+%Y_%m_%d-%H_%M_%S').log"
touch "${LOG_FILE}" 2>/dev/null || true
chmod 666 "${LOG_FILE}" 2>/dev/null || true
RETENTION_DEFAULT="${ARRBIT_LOG_RETENTION:-5}"

# Source shared helpers & logging if present
if [ -f "${HELPERS_DIR}/logging_utils.bash" ]; then
  # shellcheck disable=SC1091
  . "${HELPERS_DIR}/logging_utils.bash"
elif [ -f "${HELPERS_DIR}/helpers.bash" ]; then
  # shellcheck disable=SC1091
  . "${HELPERS_DIR}/helpers.bash"
fi

# Create compatibility symlink so arrbitPurgeOldLogs (expects /config/logs) can manage our logs
if [ ! -d /config/logs ]; then
  mkdir -p /config 2>/dev/null || true
  # Prefer symlink; if fails, copy
  ln -s "${LOG_DIR}" /config/logs 2>/dev/null || cp -r "${LOG_DIR}" /config/logs 2>/dev/null || true
fi

# Silent wrappers: write only to LOG_FILE; if arrbitLogClean exists use it
_arrbit_write(){
  local level="$1"; shift
  local line="[Arrbit]${level:+ ${level}:} $*"
  if command -v arrbitLogClean >/dev/null 2>&1; then
    printf '%s\n' "${line}" | arrbitLogClean >>"${LOG_FILE}" 2>/dev/null || printf '%s\n' "${line}" >>"${LOG_FILE}"
  else
    printf '%s\n' "${line}" >>"${LOG_FILE}"
  fi
}
log_info(){ _arrbit_write "" "$*"; }
log_warning(){ _arrbit_write "WARNING" "$*"; }
log_error(){ _arrbit_write "ERROR" "$*"; }

# Finalize / retention prune on any exit
_arrbit_finalize(){
  if command -v arrbitPurgeOldLogs >/dev/null 2>&1; then
    arrbitPurgeOldLogs "${RETENTION_DEFAULT}" || true
  fi
}
trap _arrbit_finalize EXIT

SCRIPT_PATH="${BASH_SOURCE[0]}"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  cat <<USAGE
Arrbit Dependencies Installer ${DEP_SCRIPT_VERSION}
Installs/validates system packages and WhisperX environment.
Environment variables:
  ARRBIT_FORCE_DEPS=1     Force rebuild of environment
  ARRBIT_LOG_RETENTION=N  Keep last N log files (default 5)
Usage: ${SCRIPT_PATH##*/} [--help]
USAGE
  exit 0
fi

log_info "Starting dependencies installer version ${DEP_SCRIPT_VERSION}" 

command_exists(){ command -v "$1" >/dev/null 2>&1; }
apt_install(){ DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >>"${LOG_FILE}" 2>&1; }

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
  apt-get update >>"${LOG_FILE}" 2>&1 || { log_error "apt update failed"; exit 1; }
fi

install_sys() {
  command_exists apt-get || { log_warning "apt-get missing; skipping system package installation"; return 0; }
  local packages=(ffmpeg jq yq python3 python3-pip python3-venv curl ca-certificates)
  local missing=()
  for pkg in "${packages[@]}"; do
    case "$pkg" in
      python3-pip) chk="pip3" ;;
      python3-venv) chk="python3" ;;
      *) chk="$pkg" ;;
    esac
    command_exists "$chk" || missing+=("$pkg")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    log_info "Installing missing packages: ${missing[*]}"
    apt_install "${missing[@]}" || log_warning "One or more packages failed: ${missing[*]}"
  else
    log_info "All required system packages present"
  fi
}
install_sys

# Fallback install for yq if still missing (e.g., repository lacks package)
if ! command_exists yq; then
  log_warning "yq not found after system install; attempting fallback binary install"
  yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
  if command_exists curl; then
    if curl -fsSL "${yq_url}" -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq && command_exists yq; then
      log_info "Installed yq via fallback binary"
    else
      log_warning "Fallback yq binary install failed"
    fi
  else
    log_warning "curl unavailable; cannot fetch yq fallback"
  fi
fi

mkdir -p "${ENV_DIR}" || true

# Ensure python3-venv capability (some minimal images split it)
ensure_venv_support(){
  python3 -m venv --help >/dev/null 2>&1 && return 0
  log_warning "python3 -m venv not functional; attempting to (re)install python3-venv"
  if command_exists apt-get; then
    apt_install python3-venv || true
  fi
  python3 -m venv --help >/dev/null 2>&1 && return 0
  log_warning "Second attempt to enable venv failed; trying ensurepip bootstrap"
  python3 -m ensurepip --upgrade >>"${LOG_FILE}" 2>&1 || true
  python3 -m venv --help >/dev/null 2>&1 && return 0
  return 1
}

if ! ensure_venv_support; then
  log_error "python3 venv support unavailable after remediation attempts. Install python3-venv manually and re-run."
  exit 1
fi

if [ "${ALWAYS_UPGRADE}" = "1" ] && [ -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Force upgrade requested: removing existing environment"
  rm -rf "${WHISPERX_ENV_PATH}" || { log_error "Failed to remove existing env"; exit 1; }
fi
if [ ! -d "${WHISPERX_ENV_PATH}" ]; then
  log_info "Creating virtual environment at ${WHISPERX_ENV_PATH}"
  if ! python3 -m venv "${WHISPERX_ENV_PATH}" >>"${LOG_FILE}" 2>&1; then
    log_warning "Primary venv creation failed; retrying after clearing any partial directory"
    rm -rf "${WHISPERX_ENV_PATH}" 2>/dev/null || true
    if ! python3 -m venv "${WHISPERX_ENV_PATH}" >>"${LOG_FILE}" 2>&1; then
      log_error "venv creation failed"; exit 1;
    fi
  fi
fi

log_info "Upgrading pip"
"${WHISPERX_ENV_PATH}/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || log_warning "pip upgrade failed"

log_info "Installing / updating whisperx"
"${WHISPERX_ENV_PATH}/bin/python" -m pip install --upgrade whisperx >/dev/null 2>&1 || { log_error "whisperx install failed"; exit 1; }

log_info "Verifying whisperx"
"${WHISPERX_ENV_PATH}/bin/python" - <<'PY' >>"${LOG_FILE}" 2>&1
import sys
try:
  import importlib.metadata as md  # Py3.8+
except Exception:
  try:
    import importlib_metadata as md  # backport
  except Exception:
    md = None
try:
  import whisperx
except Exception as e:
  print("IMPORT_FAIL", e)
  sys.exit(1)
ver = None
if md:
  try:
    ver = md.version("whisperx")
  except Exception:
    pass
print("WhisperX OK version:", ver or "unknown", "file:", getattr(whisperx, "__file__", "?"))
PY
if [ $? -ne 0 ]; then
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

# Optional model prefetch based on configuration file
if [ "${ARRBIT_PREFETCH_MODELS:-1}" = "1" ]; then
  CONF_FILE="${ARRBIT_BASE}/config/whisperx.conf"
  if [ -f "${CONF_FILE}" ]; then
    log_info "Loading configuration for prefetch: ${CONF_FILE}"
    while IFS='=' read -r k v; do
      [ -z "${k}" ] && continue
      case "${k}" in \#* ) continue ;; esac
      k_trim="$(echo "${k}" | tr -d ' ')"
      v_trim="$(echo "${v}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -n "${k_trim}" ] && export "${k_trim}"="${v_trim}"
    done < "${CONF_FILE}"
    if [ -n "${WHISPERX_MODEL:-}" ]; then
      log_info "Prefetching model: ${WHISPERX_MODEL}"
      PREFETCH_ENV=( )
      if [ -n "${WHISPERX_MODELS_DIR:-}" ]; then
        mkdir -p "${WHISPERX_MODELS_DIR}" 2>/dev/null || true
        PREFETCH_ENV+=( "WHISPER_CACHE_DIR=${WHISPERX_MODELS_DIR}" )
        # Attempt to set XDG cache to parent of models dir to keep structure tidy
        PARENT_DIR="$(dirname "${WHISPERX_MODELS_DIR}")"
        PREFETCH_ENV+=( "XDG_CACHE_HOME=${PARENT_DIR}" )
      fi
      if [ -n "${WHISPERX_CACHE_DIR:-}" ]; then
        mkdir -p "${WHISPERX_CACHE_DIR}" 2>/dev/null || true
        PREFETCH_ENV+=( "TRANSFORMERS_CACHE=${WHISPERX_CACHE_DIR}" "HF_HOME=${WHISPERX_CACHE_DIR}" )
      fi
      # Execute prefetch silently (output still logged)
      if env "${PREFETCH_ENV[@]}" "${WHISPERX_ENV_PATH}/bin/python" - "$WHISPERX_MODEL" >>"${LOG_FILE}" 2>&1 <<'PY'; then
import sys, whisperx
model_name = sys.argv[1]
try:
    whisperx.load_model(model_name, device="cpu")
    print("Prefetch OK", model_name)
except Exception as e:
    print("Prefetch FAIL", model_name, e)
    raise SystemExit(1)
PY
        log_info "Prefetch complete: ${WHISPERX_MODEL}"
      else
        log_warning "Prefetch failed for model: ${WHISPERX_MODEL}"
      fi
    else
      log_warning "WHISPERX_MODEL not set in config; skipping prefetch"
    fi
  else
    log_warning "Config file missing for prefetch: ${CONF_FILE}"
  fi
else
  log_info "Model prefetch disabled (ARRBIT_PREFETCH_MODELS=${ARRBIT_PREFETCH_MODELS:-0})"
fi

log_info "Dependencies installation complete. Log: ${LOG_FILE}"

if command_exists sha256sum; then
  sha256sum "${SCRIPT_PATH}" | awk '{print $1}' | xargs -I{} log_info "Script SHA256 {}"
fi

exit 0

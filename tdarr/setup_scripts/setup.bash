#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr Setup Script
# Version: v2.2.1-gs2.8.3
# Purpose: Fetch (if needed) Arrbit repo and deploy Tdarr + shared assets to /app/arrbit
#           - Copies helpers (universal/helpers) to /app/arrbit/helpers
#           - Copies tdarr config, plugins, scripts, data files
#           - Moves setup scripts to unified /app/arrbit/setup
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

SETUP_SCRIPT_VERSION="v2.2.1-gs2.8.3"

ARRBIT_BASE="/app/arrbit"
TDARR_BASE="${ARRBIT_BASE}/tdarr"
SETUP_DEST="${ARRBIT_BASE}/setup"
HELPERS_DEST="${ARRBIT_BASE}/helpers"

REPO_URL="${ARRBIT_REPO_URL:-https://github.com/prvctech/Arrbit.git}"
REPO_BRANCH="${ARRBIT_BRANCH:-main}"
TMP_ROOT="/tmp/arrbit-fetch"
FETCH_DIR=""

log_info(){ echo "[INFO] $*"; }
log_warn(){ echo "[WARN] $*" >&2; }
log_error(){ echo "[ERROR] $*" >&2; }

if [ "${EUID:-$(id -u)}" -ne 0 ]; then log_error "Run as root"; exit 1; fi

command_exists(){ command -v "$1" >/dev/null 2>&1; }

prepare_tmp(){ mkdir -p "${TMP_ROOT}"; }

fetch_repo(){
  prepare_tmp
  local ts="$(date +%s)"
  FETCH_DIR="${TMP_ROOT}/repo-${ts}"
  log_info "Fetching repository ${REPO_URL} (branch ${REPO_BRANCH})"
  if command_exists git; then
    git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${FETCH_DIR}" >/dev/null 2>&1 || { log_error "git clone failed"; exit 1; }
  else
    mkdir -p "${FETCH_DIR}"
    local tar_url="https://codeload.github.com/prvctech/Arrbit/tar.gz/${REPO_BRANCH}"
    if ! curl -fsSL "${tar_url}" | tar -xz -C "${FETCH_DIR}"; then
      log_error "tarball download failed"; exit 1;
    fi
    FETCH_DIR="$(find "${FETCH_DIR}" -maxdepth 1 -type d -name 'Arrbit-*' | head -n1)"
    [ -z "${FETCH_DIR}" ] && { log_error "extracted repo dir not found"; exit 1; }
  fi
}

ensure_dirs(){
  log_info "Ensuring target directory structure"
  mkdir -p \
    "${TDARR_BASE}/environments" \
    "${TDARR_BASE}/plugins"/{transcription,audio_enhancement,custom} \
    "${TDARR_BASE}/data"/{models/whisper,cache,temp,logs} \
    "${TDARR_BASE}/scripts" \
    "${TDARR_BASE}/config" \
    "${HELPERS_DEST}" \
    "${SETUP_DEST}"
}

copy_dir(){ # src dest
  local src="$1" dest="$2"
  [ ! -d "${src}" ] && return 0
  mkdir -p "${dest}"
  if command_exists rsync; then
    rsync -a --delete "${src}/" "${dest}/" >/dev/null 2>&1 || rsync -a "${src}/" "${dest}/"
  else
    cp -r "${src}/." "${dest}/" 2>/dev/null || true
  fi
}

deploy(){
  local tdarr_src="${FETCH_DIR}/tdarr"
  local helpers_src_a="${FETCH_DIR}/universal/helpers"
  local helpers_src_b="${FETCH_DIR}/helpers" # fallback if structure changes

  if [ ! -d "${tdarr_src}" ]; then log_error "tdarr directory missing in fetched repo"; exit 1; fi

  log_info "Deploying Tdarr components"
  copy_dir "${tdarr_src}/config"        "${TDARR_BASE}/config"
  copy_dir "${tdarr_src}/plugins"       "${TDARR_BASE}/plugins"
  copy_dir "${tdarr_src}/scripts"       "${TDARR_BASE}/scripts"
  copy_dir "${tdarr_src}/data"          "${TDARR_BASE}/data"

  # Setup scripts -> unified /app/arrbit/setup
  copy_dir "${tdarr_src}/setup_scripts" "${SETUP_DEST}"

  # Helpers (prefer universal/helpers)
  if [ -d "${helpers_src_a}" ]; then
    log_info "Deploying helpers (universal)"
    copy_dir "${helpers_src_a}" "${HELPERS_DEST}"
  elif [ -d "${helpers_src_b}" ]; then
    log_info "Deploying helpers (root helpers)"
    copy_dir "${helpers_src_b}" "${HELPERS_DEST}"
  else
    log_warn "helpers directory not found in repo"
  fi
}

permissions(){
  log_info "Setting permissions"
  find "${ARRBIT_BASE}" -type d -exec chmod 755 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.bash" -exec chmod +x {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.js" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.conf" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.yaml" -exec chmod 644 {} \; 2>/dev/null || true
}

post_checks(){
  local missing=0
  for p in "${HELPERS_DEST}" "${SETUP_DEST}/dependencies.bash" "${TDARR_BASE}/config/whisperx.conf"; do
    if [ ! -e "$p" ]; then
      log_warn "Missing expected artifact: $p"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    log_warn "Some expected files are missing (see warnings above)."
  else
    log_info "All expected key artifacts present."
  fi
}

cleanup_tmp(){
  # Remove only the fetched repo directory to keep TMP_ROOT reusable
  if [ -n "${FETCH_DIR}" ] && [ -d "${FETCH_DIR}" ]; then
    case "${FETCH_DIR}" in
      /tmp/arrbit-fetch/*)
        log_info "Cleaning up temporary fetch directory ${FETCH_DIR}"
        rm -rf "${FETCH_DIR}" || log_warn "Failed to remove ${FETCH_DIR}" ;;
      *)
        log_warn "Refusing to delete unexpected temp path: ${FETCH_DIR}" ;;
    esac
  fi
}

trap cleanup_tmp EXIT

main(){
  fetch_repo
  ensure_dirs
  deploy
  permissions
  post_checks
  log_info "Setup complete (version ${SETUP_SCRIPT_VERSION})."
  log_info "Setup scripts located at: ${SETUP_DEST}"
  log_info "Next: run dependencies (dependencies.bash) from ${SETUP_DEST} if not already executed."
}

main "$@"
exit 0
#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr Setup Script
# Version: v2.2.5-gs2.8.3
# Purpose: Fetch (if needed) Arrbit repo and deploy Tdarr + shared assets to /app/arrbit
#           - Copies helpers (universal/helpers) to /app/arrbit/helpers
#           - Copies tdarr config, plugins, scripts, data files
#           - Moves setup scripts to unified /app/arrbit/setup
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

SETUP_SCRIPT_VERSION="v2.2.5-gs2.8.3"

ARRBIT_BASE="/app/arrbit"
SETUP_DEST="${ARRBIT_BASE}/setup"
HELPERS_DEST="${ARRBIT_BASE}/helpers"

REPO_URL="${ARRBIT_REPO_URL:-https://github.com/prvctech/Arrbit.git}"
REPO_BRANCH="${ARRBIT_BRANCH:-main}"
# Use persistent in-app tmp workspace instead of system /tmp
WORK_TMP_BASE="${ARRBIT_BASE}/data/tmp"
TMP_ROOT="${WORK_TMP_BASE}/fetch"
FETCH_DIR=""

LOG_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
chmod 777 "${LOG_DIR}" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/setup-$(date '+%Y_%m_%d-%H_%M_%S').log"
touch "${LOG_FILE}" 2>/dev/null || true
chmod 666 "${LOG_FILE}" 2>/dev/null || true

# Silent terminal logging (all verbosity only goes to log file)
log_info(){ printf '[INFO] %s\n' "$*" >>"${LOG_FILE}"; }
log_warn(){ printf '[WARN] %s\n' "$*" >>"${LOG_FILE}"; }
log_error(){ printf '[ERROR] %s\n' "$*" >>"${LOG_FILE}"; }
log_info "Starting Tdarr setup script version ${SETUP_SCRIPT_VERSION}" 

if [ "${EUID:-$(id -u)}" -ne 0 ]; then log_error "Run as root"; exit 1; fi

command_exists(){ command -v "$1" >/dev/null 2>&1; }

prepare_tmp(){ mkdir -p "${TMP_ROOT}"; chmod 777 "${WORK_TMP_BASE}" "${TMP_ROOT}" 2>/dev/null || true; }

# Pre-create all required directories BEFORE fetching so that permissions are correct
precreate_dirs(){
  local dirs=(
    "${ARRBIT_BASE}"
    "${ARRBIT_BASE}/data"
    "${WORK_TMP_BASE}"
  "${ARRBIT_BASE}/environments"
  "${ARRBIT_BASE}/plugins"
  "${ARRBIT_BASE}/plugins/transcription"
  "${ARRBIT_BASE}/plugins/audio_enhancement"
  "${ARRBIT_BASE}/plugins/custom"
  "${ARRBIT_BASE}/data"
  "${ARRBIT_BASE}/data/models"
  "${ARRBIT_BASE}/data/models/whisper"
  "${ARRBIT_BASE}/data/cache"
  "${ARRBIT_BASE}/data/temp"
  "${ARRBIT_BASE}/data/logs"
  "${ARRBIT_BASE}/scripts"
  "${ARRBIT_BASE}/config"
    "${HELPERS_DEST}"
    "${SETUP_DEST}"
  )
  for d in "${dirs[@]}"; do
    mkdir -p "$d"
    chmod 777 "$d" 2>/dev/null || true
  done
}

fetch_repo(){
  prepare_tmp
  local ts="$(date +%s)"
  FETCH_DIR="${TMP_ROOT}/repo-${ts}"
  log_info "Fetching repository ${REPO_URL} (branch ${REPO_BRANCH}) into ${FETCH_DIR}"
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
  chmod -R 755 "${FETCH_DIR}" 2>/dev/null || true
}

ensure_dirs(){
  log_info "Ensuring target directory structure"
  mkdir -p \
  "${ARRBIT_BASE}/environments" \
  "${ARRBIT_BASE}/plugins"/{transcription,audio_enhancement,custom} \
  "${ARRBIT_BASE}/data"/{models/whisper,cache,temp,logs} \
  "${ARRBIT_BASE}/scripts" \
  "${ARRBIT_BASE}/config" \
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
  copy_dir "${tdarr_src}/config"        "${ARRBIT_BASE}/config"
  copy_dir "${tdarr_src}/plugins"       "${ARRBIT_BASE}/plugins"
  copy_dir "${tdarr_src}/scripts"       "${ARRBIT_BASE}/scripts"
  copy_dir "${tdarr_src}/data"          "${ARRBIT_BASE}/data"

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
  log_info "Normalizing permissions (directories -> 777 as per requirement)"
  find "${ARRBIT_BASE}" -type d -exec chmod 777 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.bash" -exec chmod +x {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  # Leave files more restrictive unless they need execute
  find "${ARRBIT_BASE}" -type f -name "*.js" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -type f -name "*.conf" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -type f -name "*.yaml" -exec chmod 644 {} \; 2>/dev/null || true
}

post_checks(){
  local missing=0
  for p in "${HELPERS_DEST}" "${SETUP_DEST}/dependencies.bash" "${ARRBIT_BASE}/config/whisperx.conf"; do
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
  # Remove only the fetched repo directory first
  if [ -n "${FETCH_DIR}" ] && [ -d "${FETCH_DIR}" ]; then
    case "${FETCH_DIR}" in
      ${TMP_ROOT}/*)
        log_info "Cleaning up temporary fetch directory ${FETCH_DIR}"
        rm -rf "${FETCH_DIR}" || log_warn "Failed to remove ${FETCH_DIR}" ;;
      *)
        log_warn "Refusing to delete unexpected temp path: ${FETCH_DIR}" ;;
    esac
  fi
  # Purge any residual artifacts inside /app/arrbit/data/tmp/* (leave the base dir itself)
  if [ -n "${WORK_TMP_BASE}" ] && [ -d "${WORK_TMP_BASE}" ]; then
    # Safety guard: ensure path starts with /app/arrbit/data/tmp
    case "${WORK_TMP_BASE}" in
      /app/arrbit/data/tmp*)
        # Delete all children (files/dirs) under WORK_TMP_BASE
        if ls -A "${WORK_TMP_BASE}" >/dev/null 2>&1; then
          log_info "Purging residual temp contents under ${WORK_TMP_BASE}/*"
          find "${WORK_TMP_BASE}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
        fi
        ;;
      *)
        log_warn "Refusing to purge unexpected WORK_TMP_BASE: ${WORK_TMP_BASE}" ;;
    esac
  fi
}

trap cleanup_tmp EXIT

main(){
  precreate_dirs
  fetch_repo
  ensure_dirs
  deploy
  permissions
  post_checks
  log_info "Setup complete (version ${SETUP_SCRIPT_VERSION})."
  log_info "Setup scripts located at: ${SETUP_DEST}"
  log_info "Temporary fetch root: ${TMP_ROOT} (current fetch cleaned on exit)"
  log_info "Next: run dependencies (dependencies.bash) from ${SETUP_DEST} if not already executed."
  log_info "Log file: ${LOG_FILE}"
}

main "$@"
exit 0
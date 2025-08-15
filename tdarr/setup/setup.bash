#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr Setup Script
# Version: v1.0.0-gs3.0.0
# Purpose: Fetch (if needed) Arrbit repo and deploy Tdarr + shared assets to auto-detected Arrbit base
#           - Copies helpers (universal/helpers) to universal/helpers structure
#           - Copies tdarr config, plugins, scripts, data files
#           - Moves setup scripts to unified setup directory
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

SETUP_SCRIPT_VERSION="v1.0.0-gs3.0.0"
TRACE_ID="setup-$(date +%s)-$$"

# Auto-detect or use environment override for Arrbit base
ARRBIT_BASE="${ARRBIT_BASE:-}"
if [[ -z "$ARRBIT_BASE" ]]; then
  # Try common container mount points
  for path in "/app/arrbit" "/config/arrbit" "/data/arrbit" "/opt/arrbit"; do
    if [[ -d "$path" ]] || mkdir -p "$path" 2>/dev/null; then
      ARRBIT_BASE="$path"
      break
    fi
  done
  [[ -z "$ARRBIT_BASE" ]] && ARRBIT_BASE="/app/arrbit"  # fallback
fi
SETUP_DEST="${ARRBIT_BASE}/setup"
HELPERS_DEST="${ARRBIT_BASE}/universal/helpers"

REPO_URL="${ARRBIT_REPO_URL:-https://github.com/prvctech/Arrbit.git}"
REPO_BRANCH="${ARRBIT_BRANCH:-main}"
WORK_TMP_BASE="${ARRBIT_BASE}/data/temp"
TMP_ROOT="${WORK_TMP_BASE}/fetch"
FETCH_DIR=""

LOG_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
chmod 755 "${LOG_DIR}" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/arrbit-setup-$(date +%Y_%m_%d-%H_%M).log"
touch "${LOG_FILE}" 2>/dev/null || true
chmod 644 "${LOG_FILE}" 2>/dev/null || true

# Minimal logging functions for bootstrap phase (before helpers are available)
log_info(){ printf '[%s] [INFO] [setup:%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${BASH_LINENO[0]}" "$*" >>"${LOG_FILE}"; }
log_warning(){ printf '[%s] [WARN] [setup:%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${BASH_LINENO[0]}" "$*" >>"${LOG_FILE}"; }
log_error(){ printf '[%s] [ERROR] [setup:%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${BASH_LINENO[0]}" "$*" >>"${LOG_FILE}"; }
 # Ensure base exists with correct perms
if [ ! -d "${ARRBIT_BASE}" ]; then
  mkdir -p "${ARRBIT_BASE}" 2>/dev/null || true
fi
chmod 755 "${ARRBIT_BASE}" 2>/dev/null || true

log_info "Starting Tdarr setup script version ${SETUP_SCRIPT_VERSION} (trace_id: ${TRACE_ID})"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then 
  log_error "Setup script must run as root"
  cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Setup script must run as root
CAUSE: Current user ID ${EUID:-$(id -u)} is not root (0)
RESOLUTION: Run this script with sudo or as root user
CONTEXT: script=setup, trace_id=${TRACE_ID}, user_id=${EUID:-$(id -u)}
EOF
  exit 1
fi

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
    if ! mkdir -p "$d" 2>/dev/null; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Failed to create directory structure
CAUSE: Cannot create directory: $d
RESOLUTION: Check filesystem permissions and available disk space
CONTEXT: script=setup, function=precreate_dirs, trace_id=${TRACE_ID}, dir=$d
EOF
      return 1
    fi
    chmod 755 "$d" 2>/dev/null || true
  done
  
  log_info "Created directory structure successfully"
}

fetch_repo(){
  prepare_tmp
  local ts="$(date +%s)"
  FETCH_DIR="${TMP_ROOT}/repo-${ts}"
  
  log_info "Fetching repository ${REPO_URL} (branch ${REPO_BRANCH}) into ${FETCH_DIR}"
  
  if command_exists git; then
    if ! git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${FETCH_DIR}" >/dev/null 2>&1; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Git clone operation failed
CAUSE: Cannot clone repository ${REPO_URL} branch ${REPO_BRANCH}
RESOLUTION: Check network connectivity and repository access permissions
CONTEXT: script=setup, function=fetch_repo, trace_id=${TRACE_ID}, repo=${REPO_URL}
EOF
      exit 1
    fi
  else
    mkdir -p "${FETCH_DIR}"
    local tar_url="https://codeload.github.com/prvctech/Arrbit/tar.gz/${REPO_BRANCH}"
    if ! curl -fsSL "${tar_url}" | tar -xz -C "${FETCH_DIR}"; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Tarball download failed
CAUSE: Cannot download or extract ${tar_url}
RESOLUTION: Check network connectivity and ensure curl/tar are available
CONTEXT: script=setup, function=fetch_repo, trace_id=${TRACE_ID}, url=${tar_url}
EOF
      exit 1
    fi
    FETCH_DIR="$(find "${FETCH_DIR}" -maxdepth 1 -type d -name 'Arrbit-*' | head -n1)"
    if [ -z "${FETCH_DIR}" ]; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Extracted repository directory not found
CAUSE: Cannot locate Arrbit-* directory after extraction
RESOLUTION: Verify tarball extraction and directory structure
CONTEXT: script=setup, function=fetch_repo, trace_id=${TRACE_ID}
EOF
      exit 1
    fi
  fi
  
  chmod -R 755 "${FETCH_DIR}" 2>/dev/null || true
  log_info "Repository fetch completed successfully"
}

ensure_dirs(){
  log_info "Ensuring target directory structure"
  
  local dirs=(
    "${ARRBIT_BASE}/environments"
    "${ARRBIT_BASE}/plugins/transcription"
    "${ARRBIT_BASE}/plugins/audio_enhancement"
    "${ARRBIT_BASE}/plugins/custom"
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
    if ! mkdir -p "$d" 2>/dev/null; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Failed to ensure directory structure
CAUSE: Cannot create directory: $d
RESOLUTION: Check filesystem permissions and available disk space
CONTEXT: script=setup, function=ensure_dirs, trace_id=${TRACE_ID}, dir=$d
EOF
      return 1
    fi
    chmod 755 "$d" 2>/dev/null || true
  done
  
  log_info "Directory structure verified successfully"
}

copy_dir(){ # src dest
  local src="$1" dest="$2"
  [ ! -d "${src}" ] && return 0
  
  if ! mkdir -p "${dest}"; then
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Failed to create destination directory
CAUSE: Cannot create directory: ${dest}
RESOLUTION: Check filesystem permissions and available disk space
CONTEXT: script=setup, function=copy_dir, trace_id=${TRACE_ID}, dest=${dest}
EOF
    return 1
  fi
  
  if command_exists rsync; then
    if ! rsync -a --delete "${src}/" "${dest}/" >/dev/null 2>&1; then
      rsync -a "${src}/" "${dest}/" 2>/dev/null || {
        cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Rsync copy operation failed
CAUSE: Cannot copy from ${src} to ${dest}
RESOLUTION: Check source directory exists and destination is writable
CONTEXT: script=setup, function=copy_dir, trace_id=${TRACE_ID}, src=${src}, dest=${dest}
EOF
        return 1
      }
    fi
  else
    if ! cp -r "${src}/." "${dest}/" 2>/dev/null; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Copy operation failed
CAUSE: Cannot copy from ${src} to ${dest}
RESOLUTION: Check source directory exists and destination is writable
CONTEXT: script=setup, function=copy_dir, trace_id=${TRACE_ID}, src=${src}, dest=${dest}
EOF
      return 1
    fi
  fi
}

deploy(){
  local tdarr_src="${FETCH_DIR}/tdarr"
  local helpers_src_a="${FETCH_DIR}/universal/helpers"
  local helpers_src_b="${FETCH_DIR}/helpers" # fallback if structure changes

  if [ ! -d "${tdarr_src}" ]; then
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Tdarr directory missing in fetched repository
CAUSE: Directory ${tdarr_src} does not exist in cloned repository
RESOLUTION: Verify repository structure and ensure Tdarr components are present
CONTEXT: script=setup, function=deploy, trace_id=${TRACE_ID}, expected_dir=${tdarr_src}
EOF
    exit 1
  fi

  log_info "Deploying Tdarr components"
  
  # Deploy core components
  copy_dir "${tdarr_src}/config"        "${ARRBIT_BASE}/config" || return 1
  copy_dir "${tdarr_src}/plugins"       "${ARRBIT_BASE}/plugins" || return 1
  copy_dir "${tdarr_src}/scripts"       "${ARRBIT_BASE}/scripts" || return 1
  copy_dir "${tdarr_src}/data"          "${ARRBIT_BASE}/data" || return 1

  # Setup scripts -> unified /app/arrbit/setup
  copy_dir "${tdarr_src}/setup_scripts" "${SETUP_DEST}" || return 1

  # Helpers (prefer universal/helpers)
  if [ -d "${helpers_src_a}" ]; then
    log_info "Deploying helpers (universal/helpers structure)"
    copy_dir "${helpers_src_a}" "${HELPERS_DEST}" || return 1
  elif [ -d "${helpers_src_b}" ]; then
    log_info "Deploying helpers (fallback root helpers structure)"
    copy_dir "${helpers_src_b}" "${HELPERS_DEST}" || return 1
  else
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] WARNING: Helpers directory not found in repository
CAUSE: Neither ${helpers_src_a} nor ${helpers_src_b} exists
RESOLUTION: Verify repository structure contains helper functions
CONTEXT: script=setup, function=deploy, trace_id=${TRACE_ID}
EOF
    log_warning "Helpers directory not found in repository - continuing without helpers"
  fi
  
  log_info "Tdarr deployment completed successfully"
}

permissions(){
  log_info "Normalizing permissions for security compliance"
  
  # Directories -> 755 (Golden Standard security requirement)
  find "${ARRBIT_BASE}" -type d -exec chmod 755 {} \; 2>/dev/null || true
  
  # Script files -> executable
  find "${ARRBIT_BASE}" -name "*.bash" -exec chmod 755 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true
  
  # Configuration and data files -> read/write
  find "${ARRBIT_BASE}" -type f -name "*.js" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -type f -name "*.conf" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -type f -name "*.yaml" -exec chmod 644 {} \; 2>/dev/null || true
  find "${ARRBIT_BASE}" -type f -name "*.json" -exec chmod 644 {} \; 2>/dev/null || true
  
  log_info "Permission normalization completed"
}

post_checks(){
  local missing=0
  local expected_files=(
    "${HELPERS_DEST}"
    "${SETUP_DEST}/dependencies.bash"
    "${ARRBIT_BASE}/config/whisperx.conf"
  )
  
  log_info "Performing post-deployment validation"
  
  for p in "${expected_files[@]}"; do
    if [ ! -e "$p" ]; then
      cat <<EOF >>"${LOG_FILE}"

[Arrbit] WARNING: Expected artifact missing after deployment
CAUSE: File or directory not found: $p
RESOLUTION: Verify deployment completed successfully and repository structure
CONTEXT: script=setup, function=post_checks, trace_id=${TRACE_ID}, missing_file=$p
EOF
      log_warning "Missing expected artifact: $p"
      missing=1
    fi
  done
  
  if [ "$missing" -eq 1 ]; then
    log_warning "Some expected files are missing - deployment may be incomplete"
  else
    log_info "All expected key artifacts present - deployment validated successfully"
  fi
}

cleanup_tmp(){
  log_info "Starting cleanup of temporary files"
  
  # Remove only the fetched repo directory first (with safety checks)
  if [ -n "${FETCH_DIR}" ] && [ -d "${FETCH_DIR}" ]; then
    case "${FETCH_DIR}" in
      "${TMP_ROOT}"/*)
        log_info "Cleaning up temporary fetch directory ${FETCH_DIR}"
        if ! rm -rf "${FETCH_DIR}" 2>/dev/null; then
          log_warning "Failed to remove temporary directory ${FETCH_DIR}"
        fi
        ;;
      *)
        cat <<EOF >>"${LOG_FILE}"

[Arrbit] WARNING: Refusing to delete unexpected temp path
CAUSE: FETCH_DIR path ${FETCH_DIR} is outside expected TMP_ROOT
RESOLUTION: Manual cleanup may be required for this directory
CONTEXT: script=setup, function=cleanup_tmp, trace_id=${TRACE_ID}, fetch_dir=${FETCH_DIR}
EOF
        log_warning "Refusing to delete unexpected temp path: ${FETCH_DIR}"
        ;;
    esac
  fi
  
  # Purge any residual artifacts inside /app/arrbit/data/temp/* (leave the base dir itself)
  if [ -n "${WORK_TMP_BASE}" ] && [ -d "${WORK_TMP_BASE}" ]; then
    # Safety guard: ensure path starts with expected temporary location
    case "${WORK_TMP_BASE}" in
      "${ARRBIT_BASE}/data/temp"*)
        # Delete all children (files/dirs) under WORK_TMP_BASE
        if ls -A "${WORK_TMP_BASE}" >/dev/null 2>&1; then
          log_info "Cleaning up work temp directory contents"
          if ! rm -rf "${WORK_TMP_BASE}"/* 2>/dev/null; then
            log_warning "Failed to clean some work temp directory contents"
          fi
        fi
        ;;
      *)
        cat <<EOF >>"${LOG_FILE}"

[Arrbit] WARNING: Unexpected work temp path detected
CAUSE: WORK_TMP_BASE path ${WORK_TMP_BASE} is outside expected location
RESOLUTION: Manual cleanup may be required for this directory
CONTEXT: script=setup, function=cleanup_tmp, trace_id=${TRACE_ID}, work_tmp_base=${WORK_TMP_BASE}
EOF
        log_warning "Unexpected work temp path: ${WORK_TMP_BASE}"
        ;;
    esac
  fi
  
  log_info "Temporary cleanup completed"
}

# Install cleanup handler
trap cleanup_tmp EXIT

main(){
  log_info "Starting Tdarr setup process (trace_id: ${TRACE_ID})"
  
  precreate_dirs || {
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Failed to create initial directory structure
CAUSE: precreate_dirs function returned non-zero exit code
RESOLUTION: Check filesystem permissions and available disk space
CONTEXT: script=setup, function=main, trace_id=${TRACE_ID}
EOF
    exit 1
  }
  
  fetch_repo || {
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Repository fetch operation failed
CAUSE: fetch_repo function returned non-zero exit code
RESOLUTION: Check network connectivity and repository accessibility
CONTEXT: script=setup, function=main, trace_id=${TRACE_ID}
EOF
    exit 1
  }
  
  ensure_dirs || {
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Directory structure validation failed
CAUSE: ensure_dirs function returned non-zero exit code
RESOLUTION: Check filesystem permissions and available disk space
CONTEXT: script=setup, function=main, trace_id=${TRACE_ID}
EOF
    exit 1
  }
  
  deploy || {
    cat <<EOF >>"${LOG_FILE}"

[Arrbit] ERROR: Component deployment failed
CAUSE: deploy function returned non-zero exit code
RESOLUTION: Verify repository structure and deployment permissions
CONTEXT: script=setup, function=main, trace_id=${TRACE_ID}
EOF
    exit 1
  }
  
  permissions
  post_checks
  
  log_info "Setup completed successfully (version ${SETUP_SCRIPT_VERSION}, trace_id: ${TRACE_ID})"
  log_info "Setup scripts located at: ${SETUP_DEST}"
  log_info "Temporary fetch root: ${TMP_ROOT} (current fetch cleaned on exit)"
  log_info "Next: run dependencies (dependencies.bash) from ${SETUP_DEST} if not already executed"
  log_info "Log file: ${LOG_FILE}"
  
  # Integrate helper logging utilities if available
  if [ -f "${HELPERS_DEST}/universal/helpers/logging_utils.bash" ]; then
    log_info "Helper logging utilities available for future scripts"
  fi
}

# Execute main function with all provided arguments
main "$@"
exit 0
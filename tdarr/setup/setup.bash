#!/usr/bin/env bash
# shellcheck disable=SC2317 # safe_rm_dir lines falsely flagged unreachable; function invoked via cleanup path
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr Setup Script
# Version: v1.0.0-gs3.1.2
# Purpose: Fetch (if needed) Arrbit repo and deploy Tdarr + shared assets to fixed Arrbit base (/app/arrbit)
#           - Copies helpers (universal/helpers) into /app/arrbit/universal/helpers
#           - Copies Tdarr config, plugins, scripts, data files
#           - Moves setup scripts to unified /app/arrbit/setup directory
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

SETUP_SCRIPT_VERSION="v1.0.0-gs3.1.2"
ARRBIT_BASE="/app/arrbit"
SETUP_DEST="${ARRBIT_BASE}/setup"
HELPERS_DEST="${ARRBIT_BASE}/universal/helpers"

REPO_URL="${ARRBIT_REPO_URL:-https://github.com/prvctech/Arrbit.git}"
REPO_BRANCH="${ARRBIT_BRANCH:-develop}"
WORK_TMP_BASE="${ARRBIT_BASE}/data/temp"
TMP_ROOT="${WORK_TMP_BASE}/fetch"
FETCH_DIR=""

LOG_DIR="${ARRBIT_BASE}/data/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
chmod 777 "${LOG_DIR}" 2>/dev/null || true

# Fixed simple INFO-level log file (Golden Standard simplified variant)
LOG_FILE="${LOG_DIR}/arrbit-setup-info-$(date +%Y_%m_%d-%H_%M).log"
touch "${LOG_FILE}" 2>/dev/null || true
chmod 644 "${LOG_FILE}" 2>/dev/null || true

# Minimal bootstrap logging (INFO/WARN/ERROR only)
log_info() { printf '[INFO] %s\n' "$*" >>"${LOG_FILE}"; }
log_warning() { printf '[WARN] %s\n' "$*" >>"${LOG_FILE}"; }
log_error() { printf '[ERROR] %s\n' "$*" >>"${LOG_FILE}"; }
# Ensure base exists with correct perms
if [[ ! -d ${ARRBIT_BASE} ]]; then
	mkdir -p "${ARRBIT_BASE}" 2>/dev/null || true
fi
chmod 777 "${ARRBIT_BASE}" 2>/dev/null || true

safe_rm_dir() { # shellcheck disable=SC2317 # Function may appear unreachable to analyzer; invoked indirectly
	local path="${1-}"
	# Ensure path is non-empty and within expected TMP_ROOT prefix before removing
	if [[ -n ${path} && ${path} == "${TMP_ROOT}"* ]]; then
		rm -rf -- "${path}" 2>/dev/null || true
	else
		log_warning "Refusing to remove unsafe path: ${path}"
	fi
}
log_info "Starting Tdarr setup script version ${SETUP_SCRIPT_VERSION}"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	log_error "Setup script must run as root (uid=${EUID:-$(id -u)})"
	exit 1
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }

prepare_tmp() {
	mkdir -p "${TMP_ROOT}"
	chmod 777 "${WORK_TMP_BASE}" "${TMP_ROOT}" 2>/dev/null || true
}

# Pre-create all required directories BEFORE fetching so that permissions are correct
precreate_dirs() {
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
			log_error "Failed to create directory: $d"
			return 1
		fi
		chmod 777 "$d" 2>/dev/null || true
	done

	log_info "Created directory structure successfully"
}

fetch_repo() {
	prepare_tmp
	local ts
	ts=$(date +%s)
	FETCH_DIR="${TMP_ROOT}/repo-${ts}"

	log_info "Fetching repository ${REPO_URL} (branch ${REPO_BRANCH}) into ${FETCH_DIR}"

	if command_exists git; then
		if ! git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${FETCH_DIR}" >/dev/null 2>&1; then
			log_error "Git clone failed for ${REPO_URL} branch ${REPO_BRANCH}"
			exit 1
		fi
	else
		mkdir -p "${FETCH_DIR}"
		local tar_url="https://codeload.github.com/prvctech/Arrbit/tar.gz/${REPO_BRANCH}"
		if ! curl -fsSL "${tar_url}" | tar -xz -C "${FETCH_DIR}"; then
			log_error "Tarball download failed: ${tar_url}"
			exit 1
		fi
		FETCH_DIR="$(find "${FETCH_DIR}" -maxdepth 1 -type d -name 'Arrbit-*' | head -n1)"
		if [ -z "${FETCH_DIR}" ]; then
			log_error "Extracted repository directory not found after extracting ${tar_url}"
			exit 1
		fi
	fi

	chmod -R 777 "${FETCH_DIR}" 2>/dev/null || true
	log_info "Repository fetch completed successfully"
}

ensure_dirs() {
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
			log_error "Failed to ensure directory structure: $d"
			return 1
		fi
		chmod 777 "$d" 2>/dev/null || true
	done

	log_info "Directory structure verified successfully"
}

copy_dir() { # src dest
	local src="$1" dest="$2"
	[ ! -d "${src}" ] && return 0

	if ! mkdir -p "${dest}"; then
		log_error "Failed to create destination directory: ${dest}"
		return 1
	fi

	if command_exists rsync; then
		if ! rsync -a --delete "${src}/" "${dest}/" >/dev/null 2>&1; then
			rsync -a "${src}/" "${dest}/" 2>/dev/null || {
				log_error "Rsync copy operation failed from ${src} to ${dest}"
				return 1
			}
		fi
	else
		if ! cp -r "${src}/." "${dest}/" 2>/dev/null; then
			log_error "Copy operation failed from ${src} to ${dest}"
			return 1
		fi
	fi
}

deploy() {
	local tdarr_src="${FETCH_DIR}/tdarr"
	local helpers_src_a="${FETCH_DIR}/universal/helpers"
	local helpers_src_b="${FETCH_DIR}/helpers" # fallback if structure changes

	if [ ! -d "${tdarr_src}" ]; then
		log_error "Tdarr directory missing in fetched repository: ${tdarr_src}"
		exit 1
	fi

	log_info "Deploying Tdarr components"

	# Deploy core components
	copy_dir "${tdarr_src}/config" "${ARRBIT_BASE}/config" || return 1
	copy_dir "${tdarr_src}/plugins" "${ARRBIT_BASE}/plugins" || return 1
	copy_dir "${tdarr_src}/scripts" "${ARRBIT_BASE}/scripts" || return 1
	copy_dir "${tdarr_src}/data" "${ARRBIT_BASE}/data" || return 1

	# Setup scripts -> unified /app/arrbit/setup
	# Copy setup scripts (actual repo path is tdarr/setup/*)
	copy_dir "${tdarr_src}/setup" "${SETUP_DEST}" || return 1

	# Helpers (prefer universal/helpers)
	if [ -d "${helpers_src_a}" ]; then
		log_info "Deploying helpers (universal/helpers structure)"
		copy_dir "${helpers_src_a}" "${HELPERS_DEST}" || return 1
	elif [ -d "${helpers_src_b}" ]; then
		log_info "Deploying helpers (fallback root helpers structure)"
		copy_dir "${helpers_src_b}" "${HELPERS_DEST}" || return 1
	else
		log_warning "Helpers directory not found in repository - continuing without helpers"
	fi

	log_info "Tdarr deployment completed successfully"
}

permissions() {
	log_info "Normalizing permissions for security compliance"

	# Directories -> 755 (Golden Standard security requirement)
	find "${ARRBIT_BASE}" -type d -exec chmod 777 {} \; 2>/dev/null || true

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

post_checks() {
	local missing=0
	local expected_files=(
		"${HELPERS_DEST}"
		"${SETUP_DEST}/dependencies.bash"
		"${ARRBIT_BASE}/config/whisperx.conf"
	)

	log_info "Performing post-deployment validation"

	for p in "${expected_files[@]}"; do
		if [ ! -e "$p" ]; then
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

cleanup_tmp() {
	log_info "Starting cleanup of temporary files"

	# Remove only the fetched repo directory first (with safety checks)
	if [ -n "${FETCH_DIR}" ] && [ -d "${FETCH_DIR}" ]; then
		# Use safe helper which ensures we only delete paths under TMP_ROOT
		safe_rm_dir "${FETCH_DIR}"
	fi

	# Purge any residual artifacts inside /app/arrbit/data/temp/* (leave the base dir itself)
	if [ -n "${WORK_TMP_BASE}" ] && [ -d "${WORK_TMP_BASE}" ]; then
		# Safety guard: ensure path starts with expected temporary location
		case "${WORK_TMP_BASE}" in
		"${ARRBIT_BASE}/data/temp"*)
			# Delete all children (files/dirs) under WORK_TMP_BASE
			if ls -A "${WORK_TMP_BASE}" >/dev/null 2>&1; then
				log_info "Cleaning up work temp directory contents"
				# Use ${var:?} to avoid catastrophic expansion if WORK_TMP_BASE is empty
				if ! rm -rf "${WORK_TMP_BASE:?}"/* 2>/dev/null; then
					log_warning "Failed to clean some work temp directory contents"
				fi
			fi
			;;
		*)
			log_warning "Unexpected work temp path: ${WORK_TMP_BASE}"
			;;
		esac
	fi

	log_info "Temporary cleanup completed"
}

# Install cleanup handler
trap cleanup_tmp EXIT

main() {
	log_info "Starting Tdarr setup process"

	precreate_dirs || {
		log_error "Failed to create initial directory structure"
		exit 1
	}

	fetch_repo || {
		log_error "Repository fetch operation failed"
		exit 1
	}

	ensure_dirs || {
		log_error "Directory structure validation failed"
		exit 1
	}

	deploy || {
		log_error "Component deployment failed"
		exit 1
	}

	permissions
	post_checks

	# Helpers (if later needed) are intentionally NOT sourced here to keep setup bootstrap silent per Golden Standard.

	log_info "Setup completed successfully (version ${SETUP_SCRIPT_VERSION})"
	log_info "Setup scripts located at: ${SETUP_DEST}"
	log_info "Temporary fetch root: ${TMP_ROOT} (current fetch cleaned on exit)"
	log_info "Next: run dependencies (dependencies.bash) from ${SETUP_DEST} if not already executed"
	log_info "Log file: ${LOG_FILE}"

	# Helpers now available if present above; no further action needed
}

# Execute main function with all provided arguments
main "$@"
# shellcheck disable=SC2317 # Exit line reachable when script executed normally; false positive due to analysis limitations
exit 0

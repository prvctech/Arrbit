#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - Tdarr Setup Script
# Version: v2.1.0-gs2.8.3
# Purpose: Deploy Tdarr structure, configs, and plugins from repo to /app/arrbit/tdarr
# -------------------------------------------------------------------------------------------------------------
set -euo pipefail

SETUP_SCRIPT_VERSION="v2.1.0-gs2.8.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_TDARR_BASE="$(dirname "${SCRIPT_DIR}")"
ARRBIT_BASE="/app/arrbit"
TDARR_BASE="${ARRBIT_BASE}/tdarr"

log_info(){ echo "[INFO] $*"; }
log_warning(){ echo "[WARN] $*" >&2; }
log_error(){ echo "[ERROR] $*" >&2; }

if [ "$EUID" -ne 0 ]; then log_error "Run as root"; exit 1; fi

# Create complete folder structure
create_structure() {
  log_info "Creating Tdarr directory structure"
  mkdir -p "${TDARR_BASE}/environments" \
           "${TDARR_BASE}/plugins"/{transcription,audio_enhancement,custom} \
           "${TDARR_BASE}/data"/{models/whisper,cache,temp,logs} \
           "${TDARR_BASE}/scripts" \
           "${TDARR_BASE}/config" \
           "${TDARR_BASE}/setup_scripts"
}

# Deploy files from repo
deploy_files() {
  log_info "Deploying Tdarr files from repository"
  
  # Copy configs
  if [ -d "${REPO_TDARR_BASE}/config" ]; then
    cp -r "${REPO_TDARR_BASE}/config"/* "${TDARR_BASE}/config/" 2>/dev/null || true
  fi
  
  # Copy plugins
  if [ -d "${REPO_TDARR_BASE}/plugins" ]; then
    cp -r "${REPO_TDARR_BASE}/plugins"/* "${TDARR_BASE}/plugins/" 2>/dev/null || true
  fi
  
  # Copy scripts
  if [ -d "${REPO_TDARR_BASE}/scripts" ]; then
    cp -r "${REPO_TDARR_BASE}/scripts"/* "${TDARR_BASE}/scripts/" 2>/dev/null || true
    chmod +x "${TDARR_BASE}/scripts"/*.bash 2>/dev/null || true
  fi
  
  # Copy data files (README, etc.)
  if [ -f "${REPO_TDARR_BASE}/data/README.md" ]; then
    cp "${REPO_TDARR_BASE}/data/README.md" "${TDARR_BASE}/data/"
  fi
  
  # Copy setup scripts
  cp "${REPO_TDARR_BASE}/setup_scripts"/* "${TDARR_BASE}/setup_scripts/" 2>/dev/null || true
  chmod +x "${TDARR_BASE}/setup_scripts"/*.bash 2>/dev/null || true
}

# Set proper permissions
set_permissions() {
  log_info "Setting permissions"
  find "${TDARR_BASE}" -type d -exec chmod 755 {} \;
  find "${TDARR_BASE}" -name "*.bash" -exec chmod +x {} \;
  find "${TDARR_BASE}" -name "*.js" -exec chmod 644 {} \;
  find "${TDARR_BASE}" -name "*.conf" -exec chmod 644 {} \;
  find "${TDARR_BASE}" -name "*.yaml" -exec chmod 644 {} \;
}

# Main execution
create_structure
deploy_files
set_permissions

log_info "Tdarr setup complete. Structure deployed to: ${TDARR_BASE}"
log_info "Next: Run dependencies.bash to install WhisperX"
exit 0
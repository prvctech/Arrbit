#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup.bash
# Version: v1.0.0-gs2.8.3
# Purpose: Setup script for Tdarr Arrbit integration
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="setup"
SCRIPT_VERSION="v1.0.0-gs2.8.3"
ARRBIT_ROOT="/app/arrbit"
TMP_DIR="/tmp/arrbit-setup"
REPO_URL="https://github.com/harveymannering/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/tdarr"
LOG_FILE="/app/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Create log directory and file
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Source logging utilities after ensuring they exist
if [[ -f "/app/arrbit/helpers/logging_utils.bash" ]]; then
    source /app/arrbit/helpers/logging_utils.bash
else
    # Minimal logging functions for bootstrap (mirror names in logging_utils)
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE"; echo "ERROR: $*" >&2; }
    log_warning() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $*" >> "$LOG_FILE"; }
fi

log_info "Starting Tdarr setup $SCRIPT_VERSION"

# Create necessary directories
log_info "Creating directory structure at $ARRBIT_ROOT"
mkdir -p "$ARRBIT_ROOT"/{logs,data,config,services,helpers,connectors,modules,custom} || {
    log_error "Failed to create directory structure"
    exit 1
}
mkdir -p "$TMP_DIR" || {
    log_error "Failed to create temporary directory"
    exit 1
}

# Download and extract Arrbit repository
log_info "Downloading Arrbit repository from $REPO_URL"
cd "$TMP_DIR" || {
    log_error "Failed to change to temporary directory"
    exit 1
}

if command -v wget >/dev/null 2>&1; then
    wget -q "$REPO_URL" -O arrbit.zip &>>"$LOG_FILE" || {
        log_error "Failed to download repository with wget"
        exit 1
    }
elif command -v curl >/dev/null 2>&1; then
    curl -sL "$REPO_URL" -o arrbit.zip &>>"$LOG_FILE" || {
        log_error "Failed to download repository with curl"
        exit 1
    }
else
    log_error "Neither wget nor curl found"
    exit 1
fi

log_info "Extracting repository"
if command -v unzip >/dev/null 2>&1; then
    unzip -q arrbit.zip &>>"$LOG_FILE" || {
        log_error "Failed to extract repository"
        exit 1
    }
else
    log_error "unzip not found"
    exit 1
fi

# Verify extraction
if [[ ! -d "$REPO_MAIN" ]]; then
    log_error "Tdarr directory not found in extracted repository"
    exit 1
fi

# Copy Tdarr-specific files
log_info "Installing Tdarr components"

# Copy data payloads
mkdir -p "$ARRBIT_ROOT/data"
cp -rf "$REPO_MAIN/data/." "$ARRBIT_ROOT/data/" 2>>"$LOG_FILE" || true

# Copy services
if [[ -d "$REPO_MAIN/setup_scripts/services" ]]; then
    cp -rf "$REPO_MAIN/setup_scripts/services/." "$ARRBIT_ROOT/services/" 2>>"$LOG_FILE" || {
        log_error "Failed to copy services"
        exit 1
    }
fi

# Copy helpers and connectors (shared components)
if [[ -d "$REPO_MAIN/../shared/helpers" ]]; then
    cp -rf "$REPO_MAIN/../shared/helpers/." "$ARRBIT_ROOT/helpers/" 2>>"$LOG_FILE"
    log_info "Copied shared helpers"
elif [[ -d "$TMP_DIR/Arrbit-main/lidarr/helpers" ]]; then
    cp -rf "$TMP_DIR/Arrbit-main/lidarr/helpers/." "$ARRBIT_ROOT/helpers/" 2>>"$LOG_FILE"
    log_info "Copied helpers from lidarr (fallback)"
else
    log_error "No helpers directory found"
    exit 1
fi

if [[ -d "$REPO_MAIN/../shared/connectors" ]]; then
    cp -rf "$REPO_MAIN/../shared/connectors/." "$ARRBIT_ROOT/connectors/" 2>>"$LOG_FILE"
    log_info "Copied shared connectors"
elif [[ -d "$TMP_DIR/Arrbit-main/lidarr/connectors" ]]; then
    cp -rf "$TMP_DIR/Arrbit-main/lidarr/connectors/." "$ARRBIT_ROOT/connectors/" 2>>"$LOG_FILE"
    log_info "Copied connectors from lidarr (fallback)"
else
    log_error "No connectors directory found"
    exit 1
fi

# Copy process scripts
if [[ -d "$REPO_MAIN/process_scripts/modules" ]]; then
    cp -rf "$REPO_MAIN/process_scripts/modules/." "$ARRBIT_ROOT/modules/" 2>>"$LOG_FILE" || {
        log_error "Failed to copy modules"
        exit 1
    }
fi

if [[ -d "$REPO_MAIN/process_scripts/custom" ]]; then
    cp -rf "$REPO_MAIN/process_scripts/custom/." "$ARRBIT_ROOT/custom/" 2>>"$LOG_FILE" || {
        log_error "Failed to copy custom scripts"
        exit 1
    }
fi

# Copy setup scripts (excluding setup.bash itself)
if [[ -d "$REPO_MAIN/setup_scripts" ]]; then
    find "$REPO_MAIN/setup_scripts" -maxdepth 1 -type f ! -name "setup.bash" -exec cp {} "$ARRBIT_ROOT/" \; 2>>"$LOG_FILE"
fi

# Set permissions
log_info "Setting permissions"
chmod -R 755 "$ARRBIT_ROOT" 2>>"$LOG_FILE" || {
    log_error "Failed to set base permissions"
    exit 1
}
chmod -R 777 "$ARRBIT_ROOT/logs" 2>>"$LOG_FILE" || {
    log_error "Failed to set log permissions"
    exit 1
}

# Cleanup
log_info "Cleaning up temporary files"
rm -rf "$TMP_DIR" 2>>"$LOG_FILE" || {
    log_error "Failed to clean up temporary files"
}

log_info "SUCCESS: Setup completed - Arrbit installed to $ARRBIT_ROOT"
log_info "Run 'bash $ARRBIT_ROOT/run' to start configuration"
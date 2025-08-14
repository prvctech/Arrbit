#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup.bash
# Version: v1.0.7-gs2.8.3 (silent mode)
# Purpose: Setup script for Tdarr Arrbit integration
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="setup"
SCRIPT_VERSION="v1.0.7-gs2.8.3"
ARRBIT_ROOT="/app/arrbit"
TMP_DIR="/tmp/arrbit-setup"
REPO_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/tdarr"
REPO_UNIVERSAL="$TMP_DIR/Arrbit-main/universal"
LOG_DIR="/app/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Create log directory and file (bootstrap logging only; helpers sourced later)
mkdir -p "$LOG_DIR"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# Silent mode bootstrap logging: only warnings/errors.
log_info()    { :; }
log_warning() { echo "[Arrbit] WARNING: $*" >> "$LOG_FILE"; }
log_error()   { echo "[Arrbit] ERROR: $*"   >> "$LOG_FILE"; echo "ERROR: $*" >&2; }
_ARRBIT_LOG_UPGRADED=0

# (silent) starting Tdarr setup $SCRIPT_VERSION

# Create necessary directories (no logs directory inside ARRBIT_ROOT)
# (silent) creating directory structure
mkdir -p "$ARRBIT_ROOT"/{data,config,services,helpers,modules,custom,process_scripts,setup_scripts} || {
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

#############################
# Post-extract bootstrap
#############################

# Verify extraction
if [[ ! -d "$REPO_MAIN" ]]; then
    log_error "Tdarr directory not found in extracted repository"
    exit 1
fi

# Stage helpers early (copy only) so we can switch to Golden Standard logging
if [[ -d "$REPO_MAIN/helpers" ]]; then
    cp -rf "$REPO_MAIN/helpers/." "$ARRBIT_ROOT/helpers/" 2>>"$LOG_FILE" || true
elif [[ -d "$REPO_UNIVERSAL/helpers" ]]; then
    cp -rf "$REPO_UNIVERSAL/helpers/." "$ARRBIT_ROOT/helpers/" 2>>"$LOG_FILE" || true
fi

# Upgrade logging if logging_utils now available
if [[ -f "$ARRBIT_ROOT/helpers/logging_utils.bash" ]]; then
    # shellcheck disable=SC1091
    source "$ARRBIT_ROOT/helpers/logging_utils.bash"
    _ARRBIT_LOG_UPGRADED=1
    # enforce silent info after upgrade
    log_info() { :; }
    if [[ -f "$ARRBIT_ROOT/helpers/helpers.bash" ]]; then
        # shellcheck disable=SC1091
        source "$ARRBIT_ROOT/helpers/helpers.bash"
    fi
    # Purge old logs if arrbitPurgeOldLogs exists
    command -v arrbitPurgeOldLogs >/dev/null 2>&1 && arrbitPurgeOldLogs 3 || true
fi

# (silent) installing components

# Helper: copy a directory (overwrite/update)
copy_dir_update() {
    local src="$1"; local dest="$2"; local name="$3"
    if [[ -d "$src" ]]; then
        mkdir -p "$dest" || { log_error "Failed to create $dest"; exit 1; }
        cp -rf "$src/." "$dest/" 2>>"$LOG_FILE" || { log_error "Failed to copy $name"; exit 1; }
    # (silent) updated $name
    else
        log_warning "Source $name directory missing: $src"
    fi
}

# Helper: one-time copy for config files (do not overwrite existing)
copy_config_once() {
    local src="$1"; local dest="$2"
    if [[ ! -d "$src" ]]; then
        log_warning "Config directory missing in repo: $src"
        return
    fi
    mkdir -p "$dest" || { log_error "Failed to create config destination"; exit 1; }
    # Iterate files (regular) recursively
    while IFS= read -r -d '' file; do
        rel_path="${file#$src/}" # relative path
        target="$dest/$rel_path"
        if [[ -e "$target" ]]; then
            # (silent) config exists; skipping
        else
            mkdir -p "$(dirname "$target")" || { log_error "Failed to create directory for $rel_path"; exit 1; }
            cp "$file" "$target" 2>>"$LOG_FILE" || { log_error "Failed to install config $rel_path"; exit 1; }
            # (silent) installed config: $rel_path
        fi
    done < <(find "$src" -type f -print0)
}

# Data (always update)
copy_dir_update "$REPO_MAIN/data" "$ARRBIT_ROOT/data" "data"

# Process scripts (always update)
copy_dir_update "$REPO_MAIN/process_scripts" "$ARRBIT_ROOT/process_scripts" "process_scripts"

# Setup scripts (always update)
copy_dir_update "$REPO_MAIN/setup_scripts" "$ARRBIT_ROOT/setup_scripts" "setup_scripts"

# Helpers already staged; refresh (overwrite) with preferred source order
if [[ -d "$REPO_MAIN/helpers" ]]; then
    copy_dir_update "$REPO_MAIN/helpers" "$ARRBIT_ROOT/helpers" "helpers"
elif [[ -d "$REPO_UNIVERSAL/helpers" ]]; then
    copy_dir_update "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/helpers" "universal helpers"
elif [[ -d "$TMP_DIR/Arrbit-main/lidarr/helpers" ]]; then
    copy_dir_update "$TMP_DIR/Arrbit-main/lidarr/helpers" "$ARRBIT_ROOT/helpers" "lidarr helpers (fallback)"
else
    log_error "No helpers directory found (looked in tdarr, universal, lidarr)"
    exit 1
fi

# Config (one-time)
copy_config_once "$REPO_MAIN/config" "$ARRBIT_ROOT/config"

# Set permissions
# (silent) setting permissions
chmod -R 755 "$ARRBIT_ROOT" 2>>"$LOG_FILE" || {
    log_error "Failed to set base permissions"
    exit 1
}
chmod -R 777 "$LOG_DIR" 2>>"$LOG_FILE" || {
    log_error "Failed to set log directory permissions"
    exit 1
}

# Cleanup
# (silent) cleaning up temporary files
rm -rf "$TMP_DIR" 2>>"$LOG_FILE" || {
    log_error "Failed to clean up temporary files"
}

# (silent) setup completed
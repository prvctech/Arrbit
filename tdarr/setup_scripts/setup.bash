#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - setup.bash
# Version: v1.0.9-gs2.8.3 (silent mode)
# Purpose: Setup script for Tdarr Arrbit integration
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="setup"
SCRIPT_VERSION="v1.0.9-gs2.8.3"
ARRBIT_ROOT="/app/arrbit"
TMP_DIR="/tmp/arrbit-setup"
REPO_URL="https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
REPO_MAIN="$TMP_DIR/Arrbit-main/tdarr"
REPO_UNIVERSAL="$TMP_DIR/Arrbit-main/universal"
LOG_DIR="/app/logs"
LOG_FILE="$LOG_DIR/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# --- Ensure Arrbit root and tmp dir exist ---
mkdir -p "$ARRBIT_ROOT" "$ARRBIT_ROOT/tmp"
chmod 777 "$ARRBIT_ROOT/tmp"
mkdir -p "$TMP_DIR"

cd "$TMP_DIR"

# --- Download and extract repo ---
if ! curl -fsSL "$REPO_URL" -o arrbit.zip; then
    echo "[Arrbit] ERROR: Failed to download repository. Check network and URL."
    exit 1
fi
unzip -qqo arrbit.zip

# --- Copy helpers from universal ---
cp -r "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/"

# --- Switch to Golden Standard logging as soon as helpers are present ---
HELPERS_DIR="$ARRBIT_ROOT/helpers"
LOG_DIR="/app/logs"
mkdir -p "$LOG_DIR"
source "$HELPERS_DIR/logging_utils.bash"

# Enforce silent mode (override logging functions to suppress info output)
log_info() { 
    # Silent to terminal, still log to file if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '[Arrbit] %s\n' "$*" | arrbitLogClean >> "$LOG_FILE"
    fi
}

# Verify extraction
if [[ ! -d "$REPO_MAIN" ]]; then
    log_error "Tdarr directory not found in extracted repository"
    exit 1
fi

# Source helpers if available for additional utilities
if [[ -f "$ARRBIT_ROOT/helpers/helpers.bash" ]]; then
    # shellcheck disable=SC1091
    source "$ARRBIT_ROOT/helpers/helpers.bash"
    
    # Override CONFIG_DIR for Tdarr (helpers.bash expects /config/arrbit/config by default)
    CONFIG_DIR="$ARRBIT_ROOT/config"
fi

# Purge old logs if arrbitPurgeOldLogs exists
command -v arrbitPurgeOldLogs >/dev/null 2>&1 && arrbitPurgeOldLogs 3 || true

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
copy_dir_update "$REPO_MAIN/setup_scripts" "$ARRBIT_ROOT/setup" "setup scripts"

# Helpers already staged; refresh (overwrite) with preferred source order
if [[ -d "$REPO_MAIN/helpers" ]]; then
    copy_dir_update "$REPO_MAIN/helpers" "$ARRBIT_ROOT/helpers" "helpers"
elif [[ -d "$REPO_UNIVERSAL/helpers" ]]; then
    copy_dir_update "$REPO_UNIVERSAL/helpers" "$ARRBIT_ROOT/helpers" "universal helpers"
elif [[ -d "$TMP_DIR/Arrbit-main/lidarr/helpers" ]]; then
    copy_dir_update "$TMP_DIR/Arrbit-main/lidarr/helpers" "$ARRBIT_ROOT/helpers" "lidarr helpers (fallback)"
else
    log_warning "No additional helpers found for refresh (using universal helpers already copied)"
fi

# Config (one-time)
copy_config_once "$REPO_MAIN/config" "$ARRBIT_ROOT/config"

# Set permissions
# (silent) setting permissions - ensure all directories have 777 for full access
chmod 777 "/app" 2>>"$LOG_FILE" || {
    log_error "Failed to set /app directory permissions"
    exit 1
}
chmod -R 777 "$ARRBIT_ROOT" 2>>"$LOG_FILE" || {
    log_error "Failed to set arrbit directory permissions"
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
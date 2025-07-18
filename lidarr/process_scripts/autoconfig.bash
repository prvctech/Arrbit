#!/usr/bin/env bash
# ------------------------------------------------------------
# Arrbit [autoconfig]
# Version: 2.0
# Purpose: Orchestrates Arrbit modules to configure Lidarr, following golden standard.
# ------------------------------------------------------------

set +e  # Allow non-fatal failures for migration

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
MODULES_DIR="modules"
LOG_DIR="/config/logs"
RAW_LOG="$LOG_DIR/arrbit-autoconfig-$(date +%Y_%m_%d-%H_%M).log"

log() { echo -e "$1" | tee -a "$RAW_LOG"; }

log "🚀  $ARRBIT_TAG Starting autoconfig..."

# Always source functions for utility/log helpers
if [ -f "$MODULES_DIR/functions.bash" ]; then
    source "$MODULES_DIR/functions.bash"
else
    log "❌  $ARRBIT_TAG functions.bash missing! Aborting autoconfig."
    exit 1
fi

# List of modules to run (in order) for migration
MODULES_TO_RUN=(
    "media_management.bash"
    "metadata_write.bash"
    "metadata_profiles.bash"
    "track_naming.bash"
    "ui_settings.bash"
    "custom_scripts.bash"
    "custom_formats.bash"
    "delay_profiles.bash"
    "quality_profile.bash"
)

# Run each module, skip if disabled or missing
for module in "${MODULES_TO_RUN[@]}"; do
    module_name="${module%.bash}"  # Remove extension for nice logs
    module_path="$MODULES_DIR/$module"

    # Example flag check: add your own logic to enable/disable as needed
    flag_var="ENABLE_${module_name^^}"
    if [ "${!flag_var:-1}" -eq 0 ]; then
        log "⏭️   $ARRBIT_TAG Skipping $module_name (flag disabled)"
        continue
    fi

    if [ -f "$module_path" ]; then
        if ! bash "$module_path" | tee -a "$RAW_LOG"; then
            log "❌  $ARRBIT_TAG $module_name failed"
        else
            log "✅  $ARRBIT_TAG $module_name complete"
        fi
    else
        log "⚠️   $ARRBIT_TAG $module_name missing, skipping"
    fi
done

log "📄  $ARRBIT_TAG Log saved to $RAW_LOG"
log "✅  $ARRBIT_TAG Done with autoconfig!"
exit 0

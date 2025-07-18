#!/usr/bin/env bash
set -euo pipefail

ARRBIT_TAG="\033[1;36m[Arrbit]\033[0m"
BASE_URL="https://raw.githubusercontent.com/prvctech/Arrbit/main/lidarr"
LOG_DIR="/config/logs"
CONFIG_DIR="/config/arrbit/config"
SERVICES_DIR="/etc/services.d"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$SERVICES_DIR"

log_file="$LOG_DIR/arrbit-setup-$(date +%Y%m%d-%H%M%S).log"
touch "$log_file"

log() { echo -e "$1" | tee -a "$log_file" ; }

log "🚀  ${ARRBIT_TAG} Starting Arrbit setup..."

# -----------------------------------------------------------------------------
# 1) Dependencies (always latest)
# -----------------------------------------------------------------------------
log "📥  ${ARRBIT_TAG} Downloading dependencies.bash..."
curl -sfL "$BASE_URL/setup_scripts/dependencies.bash" -o "$SERVICES_DIR/dependencies.bash" && chmod +x "$SERVICES_DIR/dependencies.bash"
log "🛠️   ${ARRBIT_TAG} Running dependencies.bash..."
bash "$SERVICES_DIR/dependencies.bash" | tee -a "$log_file"

# -----------------------------------------------------------------------------
# 2) Download process_scripts folder (all modules/scripts)
# -----------------------------------------------------------------------------
log "📥  ${ARRBIT_TAG} Downloading all process_scripts..."
TMP_DIR="$(mktemp -d)"
curl -sfL -o "$TMP_DIR/arrbit.zip" "https://github.com/prvctech/Arrbit/archive/refs/heads/main.zip"
unzip -q "$TMP_DIR/arrbit.zip" -d "$TMP_DIR"
# Copy to /etc/services.d (overwrite all to guarantee latest)
cp -rf "$TMP_DIR/Arrbit-main/lidarr/process_scripts/"* "$SERVICES_DIR/"
chmod -R 755 "$SERVICES_DIR"

# -----------------------------------------------------------------------------
# 3) Download config folder to /config/arrbit/config (if missing)
# -----------------------------------------------------------------------------
log "📥  ${ARRBIT_TAG} Syncing config files..."
for cfg in arrbit-config.conf beets-config.yaml; do
  if [ ! -f "$CONFIG_DIR/$cfg" ]; then
    curl -sfL "$BASE_URL/config/$cfg" -o "$CONFIG_DIR/$cfg"
    chmod 644 "$CONFIG_DIR/$cfg"
    log "    • ✅ $cfg saved"
  else
    log "    • ⏭️  $cfg exists; skipping download"
  fi
done

# -----------------------------------------------------------------------------
# 4) Verify required files
# -----------------------------------------------------------------------------
REQUIRED=(run.bash dependencies.bash autoconfig.bash plugins_add.bash functions.bash)
missing=0
for req in "${REQUIRED[@]}"; do
  [ -f "$SERVICES_DIR/$req" ] || { log "❌  Missing $req in $SERVICES_DIR"; missing=1; }
done
[ $missing -eq 0 ] || { log "❌  One or more core files missing. Aborting."; exit 1; }

# -----------------------------------------------------------------------------
# 5) Set permissions everywhere
# -----------------------------------------------------------------------------
chmod -R 755 "$SERVICES_DIR"
chmod -R 755 "$CONFIG_DIR"
chmod -R 755 "$LOG_DIR"

# -----------------------------------------------------------------------------
# 6) Run plugins_add if present
# -----------------------------------------------------------------------------
if [ -f "$SERVICES_DIR/plugins_add.bash" ]; then
  log "🔌  ${ARRBIT_TAG} Running plugins_add.bash..."
  bash "$SERVICES_DIR/plugins_add.bash" | tee -a "$log_file"
else
  log "⏭️   ${ARRBIT_TAG} plugins_add.bash not found, skipping."
fi

# -----------------------------------------------------------------------------
# 7) Run autoconfig if master flag enabled
# -----------------------------------------------------------------------------
source "$CONFIG_DIR/arrbit-config.conf"
if [ "${ENABLE_AUTOCONFIG:-false}" = "true" ] && [ -f "$SERVICES_DIR/autoconfig.bash" ]; then
  log "⚙️   ${ARRBIT_TAG} Running autoconfig.bash..."
  bash "$SERVICES_DIR/autoconfig.bash" | tee -a "$log_file"
else
  log "⏭️   ${ARRBIT_TAG} Skipping autoconfig.bash (flag off or not present)"
fi

# -----------------------------------------------------------------------------
# 8) Cleanup
# -----------------------------------------------------------------------------
rm -rf "$TMP_DIR"
log "✅  ${ARRBIT_TAG} Arrbit setup complete! See $log_file for details."
exit 0

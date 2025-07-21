# -------------------------------------------------------------------------------------------------------------
# Arrbit error_utils.bash
# Version: v1.0
# Purpose: Centralized error and cleanup handling for all Arrbit scripts. Uniform error trapping & temp cleanup.
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_ERROR_INCLUDED}" ]]; then
  ARRBIT_ERROR_INCLUDED=1

  # ---- Error handling function
  errorTrap() {
    # Needs log() and ARRBIT_TAG from logging_utils.bash
    local line="$1"
    log "❌  ${ARRBIT_TAG} Error at line $line"
  }

  # ---- Cleanup function for temp files, always runs at script exit
  _cleanup() {
    # Remove all /tmp/arrbit-* temp dirs/files
    rm -rf /tmp/arrbit-* 2>/dev/null || true
    # (add more cleanup logic here if needed)
  }

  # ---- Register traps (idempotent, runs only once)
  trap 'errorTrap $LINENO' ERR
  trap _cleanup EXIT
fi

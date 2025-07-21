#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit error_utils.bash
# Version: v1.1
# Purpose: Centralized error and cleanup handling for all Arrbit scripts. Uniform error trapping & temp cleanup.
# -------------------------------------------------------------------------------------------------------------

if [[ -z "${ARRBIT_ERROR_INCLUDED}" ]]; then
  ARRBIT_ERROR_INCLUDED=1

  # ---- Error handling function (captures unhandled errors) ----
  _error_trap() {
    local lineno="$1"
    # Log structured error: summary only to terminal, full details to log
    arrbitErrorLog "❌" \
      "[Arrbit] Unhandled error at line ${lineno}" \
      "unhandled error" \
      "${BASH_SOURCE[1]}" \
      "${BASH_SOURCE[1]}:${lineno}" \
      "errorTrap triggered" \
      "Review log for details"
    exit 1
  }

  # ---- Cleanup function for temp files, always runs at script exit ----
  _cleanup() {
    rm -rf /tmp/arrbit-* 2>/dev/null || true
  }

  # ---- Register traps (idempotent, runs only once) ----
  trap '_error_trap $LINENO' ERR
  trap _cleanup EXIT
fi

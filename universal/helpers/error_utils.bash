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
    local cmd="${BASH_COMMAND}"
    local exit_code=$?
    # Log structured error including the failed command and exit code
    arrbitErrorLog "❌" \
      "[Arrbit] Unhandled error in '${cmd}'" \
      "command failed" \
      "${cmd}" \
      "${BASH_SOURCE[1]}:${lineno}" \
      "exit code ${exit_code}" \
      "Review command and log for details"
    exit $exit_code
  }
  # ---- Cleanup function for temp files, always runs at script exit ----
  _cleanup() {
    rm -rf /tmp/arrbit-* 2>/dev/null || true
  }

  # ---- Register traps (idempotent, runs only once) ----
  trap '_error_trap $LINENO' ERR
  trap _cleanup EXIT
fi

#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit error_utils.bash
# Version: v1.2
# Purpose: Centralized cleanup handling for all Arrbit scripts. Removes temp files on exit.
# -------------------------------------------------------------------------------------------------------------

# Prevent multiple inclusion
if [[ -z "${ARRBIT_ERROR_INCLUDED}" ]]; then
  ARRBIT_ERROR_INCLUDED=1

  # ---- Cleanup function for temp files, always runs at script exit ----
  _cleanup() {
    rm -rf /tmp/arrbit-* 2>/dev/null || true
  }

  # ---- Register cleanup trap (runs only once) ----
  trap _cleanup EXIT
fi

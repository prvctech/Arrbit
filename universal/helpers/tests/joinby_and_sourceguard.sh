#!/usr/bin/env bash
set -euo pipefail

# Tests for joinBy and .sourceGuard
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_FILE="${SCRIPT_DIR}/../helpers.bash"

if [[ ! -f "$HELPERS_FILE" ]]; then
  echo "helpers.bash not found at $HELPERS_FILE" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$HELPERS_FILE"

echo "Using helpers file: $HELPERS_FILE"

fail=0

# Test joinBy with spaces and special characters
res=$(joinBy , "alpha" "beta gamma" ",comma" )
expected='alpha,beta gamma,,comma'
if [[ "$res" == "$expected" ]]; then
  echo "joinBy: OK (preserved whitespace and special chars) -> $res"
else
  echo "joinBy: FAILED -> got '$res' expected '$expected'" >&2
  fail=1
fi

# Test joinBy with empty elements
res2=$(joinBy ':' "one" "" "three")
expected2='one::three'
if [[ "$res2" == "$expected2" ]]; then
  echo "joinBy (empty elem): OK -> $res2"
else
  echo "joinBy (empty elem): FAILED -> got '$res2' expected '$expected2'" >&2
  fail=1
fi

# Test .sourceGuard idempotence and sanitized var name
id_raw='test.guard-123'
.sourceGuard "$id_raw"
rc1=$?
.sourceGuard "$id_raw"
rc2=$?

echo ".sourceGuard rc values: rc1=$rc1 rc2=$rc2"
if [[ $rc1 -eq 0 && $rc2 -ne 0 ]]; then
  echo ".sourceGuard: OK (first source succeeded, second returned non-zero)"
else
  echo ".sourceGuard: FAILED (rc1=$rc1 rc2=$rc2)" >&2
  fail=1
fi

# Also check that the guard variable exists in the environment
sanitized="${id_raw//[^a-zA-Z0-9_]/_}"
guard_var="SOURCE_GUARD_${sanitized}"
echo "Checking guard variable name: $guard_var"
if [[ -n "${!guard_var:-}" ]]; then
  echo ".sourceGuard var present: OK -> $guard_var"
else
  echo ".sourceGuard var present: FAILED -> $guard_var not set" >&2
  # Show environment variables matching SOURCE_GUARD*
  echo "Environment SOURCE_GUARD* variables:" >&2
  env | grep '^SOURCE_GUARD' || true
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo "ALL joinBy/.sourceGuard TESTS PASSED"
  exit 0
else
  echo "SOME TESTS FAILED" >&2
  exit 3
fi

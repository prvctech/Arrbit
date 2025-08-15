#!/usr/bin/env bash
set -euo pipefail

# Simple smoke tests for Arrbit helpers
# Run from repository root or directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="${SCRIPT_DIR}/.."
HELPERS_FILE="${HELPERS_DIR}/helpers.bash"

if [[ ! -f "$HELPERS_FILE" ]]; then
  echo "helpers.bash not found at $HELPERS_FILE" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$HELPERS_FILE"

echo "Using helpers file: $HELPERS_FILE"

# Test ensureDir
TMPDIR_TEST=$(mktemp -d 2>/dev/null || mktemp -d -t arrbit_helpers)
SUBDIR="$TMPDIR_TEST/subdir"

if ensureDir "$SUBDIR"; then
  echo "ensureDir: OK -> $SUBDIR"
else
  echo "ensureDir: FAILED" >&2
  exit 3
fi

# Test isReadable on created directory
if isReadable "$SUBDIR"; then
  echo "isReadable (dir): OK"
else
  echo "isReadable (dir): FAILED" >&2
  exit 4
fi

# Test getFileSize
TESTFILE="$TMPDIR_TEST/testfile.txt"
echo "hello" > "$TESTFILE"
size_out=$(getFileSize "$TESTFILE" ) || true

if [[ "$size_out" =~ ^[0-9]+$ && "$size_out" -gt 0 ]]; then
  echo "getFileSize: OK -> $size_out"
else
  echo "getFileSize: FAILED -> $size_out" >&2
  exit 5
fi

# Clean up
rm -rf "$TMPDIR_TEST"

echo "ALL TESTS PASSED"

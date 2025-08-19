#!/usr/bin/env bash
set -uo pipefail

# Unified helper tests for Arrbit
# Runs: ensureDir, isReadable, getFileSize, joinBy, .sourceGuard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_FILE="${SCRIPT_DIR}/../helpers.bash"

if [[ ! -f $HELPERS_FILE ]]; then
	echo "helpers.bash not found at $HELPERS_FILE" >&2
	exit 2
fi

# shellcheck source=/dev/null
source "$HELPERS_FILE"

echo "Using helpers file: $HELPERS_FILE"

fail=0

echo "--- smoke tests: ensureDir / isReadable / getFileSize ---"

# Test ensureDir
TMPDIR_TEST=$(mktemp -d 2>/dev/null || mktemp -d -t arrbit_helpers)
SUBDIR="$TMPDIR_TEST/subdir"

if ensureDir "$SUBDIR"; then
	echo "ensureDir: OK -> $SUBDIR"
else
	echo "ensureDir: FAILED (mkdir rc)" >&2
	fail=1
fi

# Test isReadable on created directory
if isReadable "$SUBDIR"; then
	echo "isReadable (dir): OK"
else
	echo "isReadable (dir): FAILED" >&2
	fail=1
fi

# Test getFileSize
TESTFILE="$TMPDIR_TEST/testfile.txt"
printf 'hello\n' >"$TESTFILE"
size_out=$(getFileSize "$TESTFILE") || true

if [[ $size_out =~ ^[0-9]+$ && $size_out -gt 0 ]]; then
	echo "getFileSize: OK -> $size_out"
else
	echo "getFileSize: FAILED -> $size_out" >&2
	fail=1
fi

echo "--- functional tests: joinBy / .sourceGuard ---"

# Test joinBy with spaces and special characters
res=$(joinBy , "alpha" "beta gamma" ",comma")
expected='alpha,beta gamma,,comma'
if [[ $res == "$expected" ]]; then
	echo "joinBy: OK (preserved whitespace and special chars) -> $res"
else
	echo "joinBy: FAILED -> got '$res' expected '$expected'" >&2
	fail=1
fi

# Test joinBy with empty elements
res2=$(joinBy ':' "one" "" "three")
expected2='one::three'
if [[ $res2 == "$expected2" ]]; then
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
if [[ -n ${!guard_var-} ]]; then
	echo ".sourceGuard var present: OK -> $guard_var"
else
	echo ".sourceGuard var present: FAILED -> $guard_var not set" >&2
	echo "Environment SOURCE_GUARD* variables:" >&2
	env | grep '^SOURCE_GUARD' || true
	fail=1
fi

# Cleanup
rm -rf "$TMPDIR_TEST" || true

if [[ $fail -eq 0 ]]; then
	echo "ALL HELPER TESTS PASSED"
	exit 0
else
	echo "SOME HELPER TESTS FAILED" >&2
	exit 3
fi

#!/bin/bash
# Shared test helpers. Source this from test scripts.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/launchers/lib.sh"
set +e  # allow test failures without killing runner

PASS=0
FAIL=0
CURRENT_TEST=""

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1: $2"; }

assert_file_exists() {
  [[ -f "$1" ]] || { fail "$CURRENT_TEST" "file not found: $1"; return 1; }
}
assert_file_contains() {
  grep -qF -- "$2" "$1" 2>/dev/null || { fail "$CURRENT_TEST" "\"$2\" not found in $1"; return 1; }
}
assert_file_not_contains() {
  ! grep -qF -- "$2" "$1" 2>/dev/null || { fail "$CURRENT_TEST" "\"$2\" should not be in $1"; return 1; }
}

report() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $((PASS + FAIL)) total"
  [[ "$FAIL" -eq 0 ]] || exit 1
}

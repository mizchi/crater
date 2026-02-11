#!/usr/bin/env bash
set -euo pipefail

baseline_file="tests/moon-test-baseline.env"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

set +e
TERM=dumb moon test >"$log_file" 2>&1
moon_exit=$?
set -e

summary="$(rg 'Total tests: [0-9]+, passed: [0-9]+, failed: [0-9]+\.' "$log_file" | tail -n 1 || true)"
if [ -z "$summary" ]; then
  echo "Failed to parse moon test summary."
  tail -n 80 "$log_file" || true
  exit 1
fi

read -r total passed failed < <(echo "$summary" | sed -E 's/.*Total tests: ([0-9]+), passed: ([0-9]+), failed: ([0-9]+).*/\1 \2 \3/')
updated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat >"$baseline_file" <<EOF
BASELINE_TOTAL=$total
BASELINE_PASSED=$passed
BASELINE_FAILED=$failed
BASELINE_UPDATED_AT=$updated_at
EOF

echo "Updated baseline: $baseline_file"
echo "Summary: total=$total passed=$passed failed=$failed"
if [ "$moon_exit" -ne 0 ] && [ "$failed" -gt 0 ]; then
  echo "moon test exited non-zero due to known failures; baseline was recorded."
fi

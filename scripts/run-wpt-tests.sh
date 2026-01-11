#!/bin/bash
# Run all WPT tests and report results
# Run from project root: ./scripts/run-wpt-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# WPT modules to test
MODULES=(
  "css-flexbox"
  "css-grid"
  "css-sizing"
  "css-position"
  "css-tables"
  "css-display"
)

echo "Running WPT tests..."
echo "===================="

total_passed=0
total_failed=0

for module in "${MODULES[@]}"; do
  echo ""
  echo "Testing $module..."

  # Run tests and capture output
  output=$(npm run wpt -- "wpt-tests/$module/*.html" 2>&1 || true)

  # Extract summary line
  summary=$(echo "$output" | grep "^Summary:" | head -1)

  if [[ "$summary" =~ ([0-9]+)\ passed,\ ([0-9]+)\ failed ]]; then
    passed="${BASH_REMATCH[1]}"
    failed="${BASH_REMATCH[2]}"
    total=$((passed + failed))
    rate=$(echo "scale=1; $passed * 100 / $total" | bc)
    echo "$module: $passed/$total ($rate%)"
    total_passed=$((total_passed + passed))
    total_failed=$((total_failed + failed))
  else
    echo "$module: Failed to parse results"
    echo "$summary"
  fi
done

echo ""
echo "===================="
grand_total=$((total_passed + total_failed))
grand_rate=$(echo "scale=1; $total_passed * 100 / $grand_total" | bc)
echo "Total: $total_passed/$grand_total ($grand_rate%)"

# Exit with error if any tests failed (optional - comment out for CI)
# if [ $total_failed -gt 0 ]; then
#   exit 1
# fi

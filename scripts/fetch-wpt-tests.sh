#!/bin/bash
# Fetch all WPT tests for CI reproducibility
# Run from project root: ./scripts/fetch-wpt-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# WPT modules to fetch (all layout-related tests)
MODULES=(
  "css-flexbox"
  "css-grid"
  "css-sizing"
  "css-position"
  "css-tables"
  "css-display"
)

echo "Fetching WPT tests..."
echo "===================="

for module in "${MODULES[@]}"; do
  echo ""
  echo "Fetching $module..."
  npm run wpt:fetch -- "$module"
done

echo ""
echo "===================="
echo "Done fetching all WPT tests."
echo ""

# Count total tests
total=0
for module in "${MODULES[@]}"; do
  count=$(ls -1 wpt-tests/"$module"/*.html 2>/dev/null | wc -l | tr -d ' ')
  echo "$module: $count tests"
  total=$((total + count))
done
echo "Total: $total tests"

#!/usr/bin/env bash
# sync-upstream-tests.sh
#
# Extracts test names from upstream moonbitlang/async packages
# and compares with mizchi/x wrapper tests to find coverage gaps.
#
# Usage:
#   ./scripts/sync-upstream-tests.sh [package]
#   package: http, websocket (default: all)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASYNC_VERSION=$(jq -r '.deps["moonbitlang/async"]' "$ROOT/moon.mod.json")
ZIP="$HOME/.moon/registry/cache/moonbitlang/async/${ASYNC_VERSION}.zip"
EXCLUDE_FILE="$ROOT/scripts/upstream-exclude.conf"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [ ! -f "$ZIP" ]; then
  echo "ERROR: Upstream package not found at $ZIP"
  echo "Run 'moon install' first."
  exit 1
fi

# Map of upstream package -> wrapper package
declare -A PKG_MAP=(
  [http]="src/http"
  [websocket]="src/websocket"
  [pipe]="src/pipe"
  [stdio]="src/stdio"
  [process]="src/process"
)

# Map of upstream package -> source directory in zip
declare -A SRC_MAP=(
  [http]="src/http"
  [websocket]="src/websocket"
  [pipe]="src/pipe"
  [stdio]="src/stdio"
  [process]="src/process"
)

packages=("${!PKG_MAP[@]}")
if [ "${1:-}" != "" ]; then
  packages=("$1")
fi

# Load exclusion list for a package
load_excludes() {
  local pkg="$1"
  if [ ! -f "$EXCLUDE_FILE" ]; then
    return
  fi
  (grep "^${pkg}:" "$EXCLUDE_FILE" 2>/dev/null || true) | sed "s/^${pkg}://" | sed 's/ *#.*//' | sed 's/^ *//' | sort
}

extract_test_names() {
  local dir="$1"
  grep -rh '^\(async \)\?test "' "$dir" 2>/dev/null \
    | sed 's/^async test "\(.*\)".*/\1/' \
    | sed 's/^test "\(.*\)".*/\1/' \
    | sort
}

is_excluded() {
  local name="$1"
  local excludes="$2"
  echo "$excludes" | grep -qxF "$name" 2>/dev/null
}

total_upstream=0
total_wrapper=0
total_missing=0
total_excluded=0

for pkg in "${packages[@]}"; do
  upstream_dir="${SRC_MAP[$pkg]}"
  wrapper_dir="${PKG_MAP[$pkg]}"

  # Extract upstream test files
  unzip -qo "$ZIP" "${upstream_dir}/*_test.mbt" "${upstream_dir}/*_wbtest.mbt" -d "$TMPDIR" 2>/dev/null || true

  upstream_tests="$TMPDIR/$upstream_dir"
  wrapper_tests="$ROOT/$wrapper_dir"

  if [ ! -d "$upstream_tests" ]; then
    echo "=== $pkg: no upstream tests found ==="
    continue
  fi

  excludes=$(load_excludes "$pkg")

  echo "=== $pkg (upstream: moonbitlang/async/$ASYNC_VERSION) ==="
  echo ""

  # Extract and compare test names
  upstream_names=$(extract_test_names "$upstream_tests")
  wrapper_names=$(extract_test_names "$wrapper_tests")

  upstream_count=$(echo "$upstream_names" | grep -c . || true)
  wrapper_count=$(echo "$wrapper_names" | grep -c . || true)

  echo "Upstream tests: $upstream_count"
  echo "Wrapper tests:  $wrapper_count"
  echo ""

  # Categorize upstream tests
  covered=""
  excluded=""
  missing=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    # Skip unimplemented stubs
    case "$name" in
      *"ignore_unused"*) continue ;;
    esac

    if echo "$wrapper_names" | grep -qF "$name" || echo "$wrapper_names" | grep -qF "smoke: $name"; then
      covered="$covered  [COVERED]  $name\n"
    elif is_excluded "$name" "$excludes"; then
      excluded="$excluded  [SKIP]     $name\n"
    else
      missing="$missing  [MISSING]  $name\n"
    fi
  done <<< "$upstream_names"

  if [ -n "$covered" ]; then
    echo -e "$covered"
  fi
  if [ -n "$excluded" ]; then
    echo -e "$excluded"
  fi
  if [ -n "$missing" ]; then
    echo -e "$missing"
  fi

  pkg_excluded=$(echo -e "${excluded:-}" | grep -c '\[SKIP\]' || true)
  pkg_missing=$(echo -e "${missing:-}" | grep -c '\[MISSING\]' || true)

  total_upstream=$((total_upstream + upstream_count))
  total_wrapper=$((total_wrapper + wrapper_count))
  total_excluded=$((total_excluded + pkg_excluded))
  total_missing=$((total_missing + pkg_missing))

  echo "---"
  echo ""
done

echo "Summary:"
echo "  Upstream tests: $total_upstream"
echo "  Wrapper tests:  $total_wrapper"
echo "  Excluded:       $total_excluded (internal/not-applicable)"
echo "  NOT COVERED:    $total_missing"

if [ "$total_missing" -gt 0 ]; then
  echo ""
  echo "FAIL: $total_missing upstream tests are not covered."
  echo "Either add wrapper tests or add to scripts/upstream-exclude.conf."
  exit 1
else
  echo ""
  echo "OK: All applicable upstream tests are covered."
fi

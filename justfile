# Justfile for crater - CSS Layout Engine

# Default target
default: check

# === Testing ===

# Run all tests (ignores test failures for CI)
test:
    moon test

# Run all tests with native target
test-native:
    moon test --target native

# Run tests for specific package
test-pkg pkg:
    moon test -p {{pkg}}

# Run quick tests (block only)
test-quick:
    moon test -p block

# Update test snapshots
test-update:
    moon test --update

# === Code Quality ===

# Check compilation
check:
    moon check

# Format code
fmt:
    moon fmt

# Update interface files (.mbti)
info:
    moon info

# Format and update interface (run before commit)
prepare:
    moon info && moon fmt

# Analyze test coverage
coverage:
    moon coverage analyze > uncovered.log
    @echo "Coverage report written to uncovered.log"

# === Test Generation ===

# Generate flex tests
gen-flex:
    npm run gen-moonbit-tests -- fixtures/flex compute/flex/gen_test.mbt --flex

# Generate block tests
gen-block:
    npm run gen-moonbit-tests -- fixtures/block compute/block/gen_test.mbt --block

# Generate grid tests (all fixtures)
gen-grid:
    npm run gen-moonbit-tests -- fixtures/grid compute/grid/gen_test.mbt --grid
    npm run gen-moonbit-tests -- fixtures/leaf compute/grid/gen_leaf_test.mbt --grid --no-header
    npm run gen-moonbit-tests -- fixtures/gridflex compute/grid/gen_gridflex_test.mbt --grid --no-header
    npm run gen-moonbit-tests -- fixtures/blockgrid compute/grid/gen_blockgrid_test.mbt --grid --no-header
    npm run gen-moonbit-tests -- fixtures/blockflex compute/grid/gen_blockflex_test.mbt --grid --no-header

# Generate all tests from fixtures
gen-all: gen-flex gen-block gen-grid

# Generate JSON fixtures from HTML
gentest pattern:
    npm run gentest -- --batch fixtures/html fixtures/{{pattern}} {{pattern}}

# === WPT (Web Platform Tests) ===

# Fetch WPT tests for a module (e.g., css-flexbox)
wpt-fetch module:
    npm run wpt:fetch -- {{module}}

# Fetch all available WPT tests
wpt-fetch-all:
    npm run wpt:fetch -- --all

# List available WPT modules
wpt-list:
    npm run wpt:fetch -- --list

# Run WPT comparison test
wpt file:
    npm run wpt -- {{file}}

# Run all WPT flexbox tests
wpt-flexbox:
    npm run wpt -- "wpt-tests/css-flexbox/*.html"

# === Utilities ===

# Clean build artifacts
clean:
    moon clean

# Download a website for testing
download url:
    npm run download -- {{url}}

# Show test summary
status:
    @echo "Running tests..."
    @moon test 2>&1 | tail -1

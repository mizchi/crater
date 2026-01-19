# Justfile for crater - CSS Layout Engine

# Default target
default: check

# === Setup ===

# Initialize submodules and dependencies
setup:
    git submodule update --init --recursive
    moon update

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

# Check compilation (main + browser)
check:
    moon check
    moon check --directory browser

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

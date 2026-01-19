# Justfile for crater - CSS Layout Engine

# Default target
default: check

# === Setup ===

# Initialize submodules and dependencies
setup:
    git submodule update --init --recursive
    moon update
    pnpm install

# === Testing ===

# Run all tests
test:
    moon test

# Run all tests with native target
test-native:
    moon test --target native

# Run tests for specific package (e.g., just test-pkg compute/block)
test-pkg pkg:
    moon test -p {{pkg}}

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
    pnpm wpt:fetch -- {{module}}

# Fetch all available WPT tests
wpt-fetch-all:
    pnpm wpt:fetch -- --all

# List available WPT modules
wpt-list:
    pnpm wpt:fetch -- --list

# Run WPT comparison test
wpt file:
    pnpm wpt -- {{file}}

# Run all WPT flexbox tests
wpt-flexbox:
    pnpm wpt -- "wpt-tests/css-flexbox/*.html"

# === WASM ===

# Build WASM component
build-wasm:
    pnpm build:wasm-component

# Transpile WASM with jco
transpile-wasm:
    pnpm jco:transpile

# Test WASM component
test-wasm:
    pnpm test:wasm-component

# Full WASM build pipeline
wasm: build-wasm transpile-wasm test-wasm

# === Utilities ===

# Clean build artifacts
clean:
    moon clean

# Download a website for testing
download url:
    pnpm download -- {{url}}

# Show test summary
status:
    @echo "Running tests..."
    @moon test 2>&1 | tail -1

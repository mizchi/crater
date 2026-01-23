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

# Run all MoonBit tests
test:
    moon test

# Run tests with native target
test-native:
    moon test --target native

# Run tests for specific package (e.g., just test-pkg mizchi/crater/layout/flex)
test-pkg pkg:
    moon test -p {{pkg}}

# Update test snapshots
test-update:
    moon test --update

# Run taffy compatibility tests
test-taffy:
    moon test -p mizchi/crater/tests/taffy_compat

# === Code Quality ===

# Check compilation (main + browser + js)
check:
    moon info
    moon check
    moon check -C browser
    moon check -C js

# Format code
fmt:
    moon fmt
    moon fmt -C browser
    moon fmt -C js

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

# Show test summary
status:
    @echo "Running tests..."
    @moon test 2>&1 | tail -1

# === Test Generation ===

# Generate MoonBit tests from taffy fixtures
gen-taffy-tests input output *args:
    npx tsx scripts/gen-taffy-tests.ts {{input}} {{output}} {{args}}

# Generate html5lib tests
gen-html5lib-tests *args:
    npx tsx scripts/gen-html5lib-tests.ts {{args}}

# === WPT (Web Platform Tests) ===
# Uses wpt/ submodule directly

# List available WPT modules
wpt-list:
    npx tsx scripts/wpt-runner.ts --list

# Run WPT tests for a module (e.g., css-flexbox)
wpt module:
    npx tsx scripts/wpt-runner.ts {{module}}

# Run all WPT tests
wpt-all:
    npx tsx scripts/wpt-runner.ts --all

# Update WPT README
wpt-update-readme:
    npx tsx scripts/update-wpt-readme.ts

# === Build ===

# Build JS module
build-js:
    moon build -C js --target js

# Build JS module for WASM-GC
build-js-wasm:
    moon build -C js --target wasm-gc

# Build WASM component
build-wasm:
    moon build -C wasm --target wasm
    wasm-tools component embed --world crater wasm/wit wasm/target/wasm/release/build/gen/gen.wasm -o wasm/target/crater-embedded.wasm
    wasm-tools component new wasm/target/crater-embedded.wasm -o wasm/target/crater.wasm

# Transpile WASM with jco
transpile-wasm:
    npx jco transpile wasm/target/crater.wasm -o wasm/dist --name crater

# Test WASM component
test-wasm:
    node --test wasm/test/component.test.mjs

# Full WASM build pipeline
wasm: build-wasm transpile-wasm test-wasm

# === Utilities ===

# Clean build artifacts
clean:
    moon clean
    moon clean -C browser
    moon clean -C js

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

# List available WPT CSS modules
wpt-list:
    npx tsx scripts/wpt-runner.ts --list

# Run WPT CSS tests for a module (e.g., css-flexbox)
wpt module:
    npx tsx scripts/wpt-runner.ts {{module}}

# Run all WPT CSS tests
wpt-all:
    npx tsx scripts/wpt-runner.ts --all

# Run all WPT tests and generate report
wpt-run-all:
    npx tsx scripts/wpt-runner.ts --all

# Update WPT README
wpt-update-readme:
    npx tsx scripts/update-wpt-readme.ts

# === WPT DOM Tests ===

# Run WPT DOM tests (single file or pattern)
wpt-dom pattern:
    npx tsx scripts/wpt-dom-runner.ts {{pattern}}

# Run all WPT DOM tests
wpt-dom-all:
    npx tsx scripts/wpt-dom-runner.ts --all

# List available WPT DOM tests
wpt-dom-list:
    npx tsx scripts/wpt-dom-runner.ts --list

# === WebDriver BiDi Server ===

# Build BiDi server
build-bidi:
    moon build -C browser --target js

# Start BiDi server (Deno)
start-bidi:
    deno run -A browser/target/js/release/build/bidi_main/bidi_main.js

# === WPT WebDriver BiDi Tests ===

# List available WebDriver BiDi test modules
wpt-webdriver-list:
    npx tsx scripts/wpt-webdriver-runner.ts --list

# Run WebDriver BiDi tests for a module (e.g., session/status)
wpt-webdriver module:
    npx tsx scripts/wpt-webdriver-runner.ts {{module}}

# Run all WebDriver BiDi tests
wpt-webdriver-all:
    npx tsx scripts/wpt-webdriver-runner.ts --all

# === Integration Tests ===

# Test Preact compatibility (requires BiDi server to be running)
test-preact:
    pnpm test:preact

# Test Playwright integration (requires BiDi server to be running)
test-playwright:
    pnpm test:bidi-e2e

# Test Playwright adapter with locator APIs
test-playwright-adapter:
    pnpm test:playwright

# Test website loading scenarios
test-website:
    pnpm test:website

# Run Playwright benchmark
bench-playwright:
    pnpm bench:playwright

# Run all Playwright-based tests
test-playwright-all: test-playwright-adapter test-website

# Run BiDi manual tests (Python, requires BiDi server to be running)
test-bidi-manual:
    uv run --no-project scripts/test-bidi-manual.py

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

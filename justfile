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

# Verify moon test result does not regress from recorded baseline
test-baseline:
    scripts/test-baseline.sh

# Update moon test baseline summary file
test-baseline-update:
    scripts/test-baseline-update.sh

# Verify WPT result does not regress from recorded baseline
wpt-baseline:
    scripts/test-wpt-baseline.sh

# Update WPT baseline summary file
wpt-baseline-update:
    scripts/test-wpt-baseline-update.sh

# === Code Quality ===

# Check compilation (main + browser + js)
check:
    moon info
    moon check
    moon check --manifest-path browser/moon.mod.json
    moon check --manifest-path js/moon.mod.json

# Format code
fmt:
    moon fmt
    moon fmt --manifest-path browser/moon.mod.json
    moon fmt --manifest-path js/moon.mod.json
    moon fmt --manifest-path wasm/moon.mod.json

# Update interface files (.mbti)
info:
    moon info

# Format and update interface (run before commit)
prepare:
    moon info
    just fmt

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

# Run WPT SVG DOM tests
wpt-svg:
    npx tsx scripts/wpt-dom-runner.ts --svg

# List available WPT DOM tests
wpt-dom-list:
    npx tsx scripts/wpt-dom-runner.ts --list

# === WPT Filter Effects & Compositing ===

# Run WPT filter-effects tests
wpt-filter-effects:
    npx tsx scripts/wpt-runner.ts filter-effects

# Run WPT compositing tests
wpt-compositing:
    npx tsx scripts/wpt-runner.ts compositing

# === WebDriver BiDi Server ===

# Build BiDi server
build-bidi:
    moon build --manifest-path browser/moon.mod.json --target js --release

# Start BiDi server (Deno)
start-bidi:
    deno run -A browser/_build/js/release/build/bidi_main/bidi_main.js

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
    moon build --manifest-path js/moon.mod.json --target js --release

# Build JS module for WASM-GC
build-js-wasm:
    moon build --manifest-path js/moon.mod.json --target wasm-gc --release

# Build WASM component
build-wasm:
    moon build --manifest-path wasm/moon.mod.json --target wasm --release
    wasm-tools component embed --world crater wasm/wit wasm/_build/wasm/release/build/gen/gen.wasm -o wasm/_build/crater-embedded.wasm
    wasm-tools component new wasm/_build/crater-embedded.wasm -o wasm/_build/crater.wasm

# Transpile WASM with jco
transpile-wasm:
    npx jco transpile wasm/_build/crater.wasm -o wasm/dist --name crater

# Test WASM component
test-wasm:
    node --test wasm/test/component.test.mjs

# Full WASM build pipeline
wasm: build-wasm transpile-wasm test-wasm

# === Utilities ===

# Clean build artifacts
clean:
    moon clean
    moon clean --manifest-path browser/moon.mod.json
    moon clean --manifest-path js/moon.mod.json

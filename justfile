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

# === Test Generation ===

# Generate test from HTML file
gentest file:
    node scripts/gentest.ts {{file}}

# Generate MoonBit tests from fixtures (generic)
gen-moonbit-tests input output *args:
    node scripts/gen-moonbit-tests.ts {{input}} {{output}} {{args}}

# Generate all taffy compatibility tests
gen-taffy-tests:
    @echo "Generating taffy compatibility tests..."
    node scripts/gen-moonbit-tests.ts tests/fixtures/block src/tests/taffy_compat/gen_block_test.mbt --compute-fn "@block.compute"
    node scripts/gen-moonbit-tests.ts tests/fixtures/flex src/tests/taffy_compat/gen_flex_test.mbt --compute-fn "@flex.compute"
    node scripts/gen-moonbit-tests.ts tests/fixtures/grid src/tests/taffy_compat/gen_grid_test.mbt --compute-fn "@grid.compute_layout"
    @echo "Done generating taffy compatibility tests"

# Run taffy compatibility tests
test-taffy:
    moon test -p mizchi/crater/tests/taffy_compat

# Generate html5lib tests
gen-html5lib-tests *args:
    node scripts/gen-html5lib-tests.ts {{args}}

# === WPT (Web Platform Tests) ===

# Fetch WPT tests for a module (e.g., css-flexbox)
wpt-fetch module:
    node scripts/fetch-wpt.ts {{module}}

# Fetch all available WPT tests
wpt-fetch-all:
    node scripts/fetch-wpt.ts --all

# List available WPT modules
wpt-list:
    node scripts/fetch-wpt.ts --list

# Run WPT comparison test
wpt file:
    node scripts/wpt-runner.ts {{file}}

# Run all WPT tests
wpt-run-all:
    ./scripts/run-wpt-tests.sh

# Run all WPT flexbox tests
wpt-flexbox:
    node scripts/wpt-runner.ts "wpt-tests/css-flexbox/*.html"

# Update WPT README
wpt-update-readme:
    node scripts/update-wpt-readme.ts

# === WASM ===

# Build WASM component
build-wasm:
    cd wasm && moon build --target wasm
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

# === JS ===

# Build JS module
build-js:
    moon build --directory js --target js

# Build JS module for WASM-GC
build-js-wasm:
    moon build --directory js --target wasm-gc

# === Utilities ===

# Clean build artifacts
clean:
    moon clean

# Download a website for testing
download url:
    node scripts/download-site.ts {{url}}

# Render HTML file
render file:
    node scripts/render.ts {{file}}

# Show test summary
status:
    @echo "Running tests..."
    @moon test 2>&1 | tail -1

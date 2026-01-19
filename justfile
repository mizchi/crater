# Justfile for crater - CSS Layout Engine

# WPT modules for testing
wpt_modules := "css-flexbox css-grid css-sizing css-position css-tables css-display"

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

# Generate test from HTML file
gentest file:
    npx tsx scripts/gentest.ts {{file}}

# Generate MoonBit tests from fixtures
gen-moonbit-tests input output *args:
    npx tsx scripts/gen-moonbit-tests.ts {{input}} {{output}} {{args}}

# Generate html5lib tests
gen-html5lib-tests *args:
    npx tsx scripts/gen-html5lib-tests.ts {{args}}

# === WPT (Web Platform Tests) ===

# Fetch WPT tests for a module (e.g., css-flexbox)
wpt-fetch module:
    npx tsx scripts/fetch-wpt.ts {{module}}

# Fetch all WPT tests
wpt-fetch-all:
    #!/usr/bin/env bash
    set -e
    echo "Fetching WPT tests..."
    for module in {{wpt_modules}}; do
        echo "Fetching $module..."
        npx tsx scripts/fetch-wpt.ts "$module"
    done
    echo "Done. Counting tests..."
    for module in {{wpt_modules}}; do
        count=$(ls -1 wpt-tests/"$module"/*.html 2>/dev/null | wc -l | tr -d ' ')
        echo "$module: $count tests"
    done

# List available WPT modules
wpt-list:
    npx tsx scripts/fetch-wpt.ts --list

# Run WPT comparison test
wpt file:
    npx tsx scripts/wpt-runner.ts {{file}}

# Run all WPT tests with summary
wpt-run-all:
    #!/usr/bin/env bash
    set -e
    echo "Running WPT tests..."
    total_passed=0
    total_failed=0
    for module in {{wpt_modules}}; do
        echo "Testing $module..."
        output=$(npx tsx scripts/wpt-runner.ts "wpt-tests/$module/*.html" 2>&1 || true)
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
            echo "$module: No results"
        fi
    done
    echo "===================="
    grand_total=$((total_passed + total_failed))
    if [ $grand_total -gt 0 ]; then
        grand_rate=$(echo "scale=1; $total_passed * 100 / $grand_total" | bc)
        echo "Total: $total_passed/$grand_total ($grand_rate%)"
    fi

# Run WPT flexbox tests
wpt-flexbox:
    npx tsx scripts/wpt-runner.ts "wpt-tests/css-flexbox/*.html"

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

# Download a website for testing
download url:
    npx tsx scripts/download-site.ts {{url}}

# Compare layout between browser and crater
compare file:
    npx tsx scripts/compare-layout.ts {{file}}

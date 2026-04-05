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

# Run all repository Vitest suites with an explicit include/exclude boundary
test-vitest:
    pnpm test:vitest

# Run node:test-based JS/WASM/browser contract tests
test-node:
    pnpm test:node

# Run the crater self-contained JS/TS test suites end-to-end
test-all:
    just test-vitest
    just test-node

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

# Run the current MoonBit suite against the recorded failure baseline
test-moon-baseline:
    just test-baseline

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

# Run WPT CSS tests and emit CI shard report JSON
wpt-css-report module report *args:
    npx tsx scripts/wpt-runner.ts {{module}} --json {{report}} {{args}}

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

# Run WPT DOM tests and emit CI shard report JSON
wpt-dom-report target report *args:
    npx tsx scripts/wpt-dom-runner.ts {{target}} --json {{report}} {{args}}

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

# Aggregate WPT CI shard reports and render markdown/json summary
wpt-ci-summary input json markdown:
    npx tsx scripts/wpt-ci-summary.ts --input {{input}} --json {{json}} --markdown {{markdown}}

# Aggregate CI job timing report from GitHub run jobs JSON
ci-timing-summary input json markdown:
    npx tsx scripts/ci-timing-summary.ts --input {{input}} --json {{json}} --markdown {{markdown}}

# === WebDriver BiDi Server ===

# Build BiDi server
build-bidi:
    moon -C browser/jsbidi build --target js --release

# Start BiDi server (Deno)
start-bidi:
    deno run -A browser/jsbidi/_build/js/release/build/bidi_main/bidi_main.js

# Start BiDi server with font metrics (for VRT)
start-bidi-with-font:
    deno run -A browser/jsbidi/bidi_main/start-with-font.ts

# === WPT WebDriver BiDi Tests ===

# List available WebDriver BiDi test modules
wpt-webdriver-list:
    npx tsx scripts/wpt-webdriver-runner.ts --list

# Run WebDriver BiDi tests for a module (e.g., session/status)
wpt-webdriver module:
    npx tsx scripts/wpt-webdriver-runner.ts {{module}}

# Run WebDriver BiDi tests and emit CI shard report JSON
wpt-webdriver-report module report *args:
    npx tsx scripts/wpt-webdriver-runner.ts {{module}} --json {{report}} {{args}}

# Run a predefined WebDriver BiDi profile (e.g., strict, network-no-auth)
wpt-webdriver-profile profile:
    npx tsx scripts/wpt-webdriver-runner.ts --profile {{profile}}

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

# Test website loading and browser user scenarios
test-website:
    pnpm test:website

# Compare a URL between Chromium and Crater (one-command VRT)
vrt-url *args:
    npx tsx scripts/vrt-url.ts {{args}}

# Compare a URL using native paint backend
vrt-url-native *args:
    npx tsx scripts/vrt-url.ts {{args}} --backend native

# Run relaxed paint visual regression tests against Chromium screenshots
test-vrt:
    pnpm test:vrt

# Run WPT visual regression tests against Chromium screenshots
test-wpt-vrt:
    pnpm test:wpt-vrt

# Run responsive VRT tests at multiple viewports
test-vrt-responsive:
    pnpm exec playwright test tests/paint-vrt-responsive.test.ts

# Run VRT levels tests
test-vrt-levels:
    pnpm exec playwright test tests/paint-vrt-levels.test.ts

# Capture a real-world snapshot for VRT testing
vrt-capture *args:
    npx tsx scripts/capture-real-world-snapshot.ts {{args}}

# Re-capture all URL snapshots
vrt-capture-all:
    npx tsx scripts/capture-real-world-snapshot.ts "https://example.com" --name example-com --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://info.cern.ch" --name info-cern-ch --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://news.ycombinator.com/" --name hackernews --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://www.google.com" --name google --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://en.wikipedia.org/wiki/Main_Page" --name wikipedia --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://craigslist.org" --name craigslist --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://lobste.rs" --name lobsters --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://lite.cnn.com" --name lite-cnn --width 800 --height 600
    npx tsx scripts/capture-real-world-snapshot.ts "https://www.npmjs.com/package/express" --name npmjs-express --width 800 --height 600

# Update WPT VRT baseline
wpt-vrt-baseline-update:
    WPT_VRT_UPDATE_BASELINE=1 pnpm test:wpt-vrt

# Run Playwright benchmark
bench-playwright:
    pnpm bench:playwright

# Run VRT API end-to-end benchmarks
bench-vrt:
    npx tsx scripts/vrt-bench.ts --group api

# Run VRT phase benchmarks (parse / node+layout / paint / json / diff)
bench-vrt-phases:
    npx tsx scripts/vrt-bench.ts --group phases

# Run all VRT API benchmarks
bench-vrt-all:
    npx tsx scripts/vrt-bench.ts --group all

# List resolved VRT benchmark indices
bench-vrt-list group="all":
    npx tsx scripts/vrt-bench.ts --group {{group}} --list

# Run VRT benchmarks and write parsed reports
bench-vrt-report group output_dir="vrt-bench":
    mkdir -p {{output_dir}}
    npx tsx scripts/vrt-bench.ts --group {{group}} --json {{output_dir}}/{{group}}.json --markdown {{output_dir}}/{{group}}.md | tee {{output_dir}}/{{group}}.log

# Compact flaker entrypoint
flaker *args:
    node scripts/flaker-entry.ts {{args}}

# List flaker-managed Playwright tasks
flaker-list:
    node scripts/flaker-entry.ts config list

# Validate flaker config against tracked Playwright specs
flaker-check:
    node scripts/flaker-entry.ts config check

# Resolve affected Playwright tasks from changed repo paths
flaker-affected *paths:
    node scripts/flaker-entry.ts config affected {{paths}}

# Generate a task-scoped flaker.toml from flaker.star
flaker-task-config task_id output="":
    if [ -n "{{output}}" ]; then node scripts/flaker-task-config.ts --task {{task_id}} --write {{output}}; else node scripts/flaker-task-config.ts --task {{task_id}}; fi

# Run flaker with a task-scoped generated config
flaker-task task_id *args:
    node scripts/flaker-task-run.ts --task {{task_id}} -- {{args}}

# Sample tests using flaker for a single task
flaker-task-sample task_id *args:
    node scripts/flaker-entry.ts task sample {{task_id}} {{args}}

# Import a Playwright JSON report into the shared flaker store for a task
flaker-task-import task_id report_path *args:
    node scripts/flaker-entry.ts task import {{task_id}} {{report_path}} {{args}}

# Run a Playwright task, persist its JSON report, and import it into flaker
flaker-task-record task_id report_path="" summary_dir="" *args:
    if [ -n "{{report_path}}" ] && [ -n "{{summary_dir}}" ]; then node scripts/flaker-task-record.ts --task {{task_id}} --report-path {{report_path}} --summary-dir {{summary_dir}} -- {{args}}; elif [ -n "{{report_path}}" ]; then node scripts/flaker-task-record.ts --task {{task_id}} --report-path {{report_path}} -- {{args}}; elif [ -n "{{summary_dir}}" ]; then node scripts/flaker-task-record.ts --task {{task_id}} --summary-dir {{summary_dir}} -- {{args}}; else node scripts/flaker-task-record.ts --task {{task_id}} -- {{args}}; fi

# Run tests using flaker for a single task
flaker-task-run task_id *args:
    node scripts/flaker-entry.ts task run {{task_id}} {{args}}

# Render task-scoped flaker eval/reason summary
flaker-task-summary task_id output_dir=".flaker/task-summary":
    mkdir -p {{output_dir}}
    node scripts/flaker-task-summary.ts --task {{task_id}} --json {{output_dir}}/{{task_id}}.json --markdown {{output_dir}}/{{task_id}}.md | tee {{output_dir}}/{{task_id}}.log

# Render full-batch plan for scheduled flaker runs
flaker-batch-plan output_dir=".flaker/batch-plan" tasks="" nodes="":
    mkdir -p {{output_dir}}
    if [ -n "{{tasks}}" ] && [ -n "{{nodes}}" ]; then node scripts/flaker-batch-plan.ts --tasks {{tasks}} --nodes {{nodes}} --json {{output_dir}}/plan.json --markdown {{output_dir}}/plan.md | tee {{output_dir}}/plan.log; elif [ -n "{{tasks}}" ]; then node scripts/flaker-batch-plan.ts --tasks {{tasks}} --json {{output_dir}}/plan.json --markdown {{output_dir}}/plan.md | tee {{output_dir}}/plan.log; elif [ -n "{{nodes}}" ]; then node scripts/flaker-batch-plan.ts --nodes {{nodes}} --json {{output_dir}}/plan.json --markdown {{output_dir}}/plan.md | tee {{output_dir}}/plan.log; else node scripts/flaker-batch-plan.ts --json {{output_dir}}/plan.json --markdown {{output_dir}}/plan.md | tee {{output_dir}}/plan.log; fi

# Aggregate full-batch flaker artifacts
flaker-batch-summary input_dir output_dir=".flaker/batch-summary":
    mkdir -p {{output_dir}}
    node scripts/flaker-batch-summary.ts --input {{input_dir}} --json {{output_dir}}/summary.json --markdown {{output_dir}}/summary.md | tee {{output_dir}}/summary.log

# Render flaker config summary for CI or local inspection
flaker-report output_dir=".flaker/report":
    mkdir -p {{output_dir}}
    node scripts/flaker-entry.ts config report {{output_dir}} | tee {{output_dir}}/summary.log

# Validate tracked flaker quarantine entries
flaker-quarantine-check:
    node scripts/flaker-entry.ts quarantine check

# Render flaker quarantine summary for CI or local inspection
flaker-quarantine-report output_dir=".flaker/quarantine":
    mkdir -p {{output_dir}}
    node scripts/flaker-entry.ts quarantine report {{output_dir}} | tee {{output_dir}}/quarantine.log

# Render upstream ownership inventory for flaker/crater boundaries
flaker-upstream-inventory output_dir=".flaker/upstream":
    mkdir -p {{output_dir}}
    node scripts/flaker-entry.ts upstream inventory {{output_dir}} | tee {{output_dir}}/inventory.log

# Stage one ready-to-upstream group into an export directory
flaker-upstream-export group output_dir=".flaker/upstream-export":
    mkdir -p {{output_dir}}
    node scripts/flaker-entry.ts upstream export {{group}} {{output_dir}} | tee {{output_dir}}/{{group}}.log

# Normalize a Playwright JSON report into JSON/Markdown summary
playwright-report-summary input label output_dir=".playwright-report":
    mkdir -p {{output_dir}}
    npx tsx scripts/playwright-report-summary.ts --input {{input}} --label {{label}} --json {{output_dir}}/{{label}}.json --markdown {{output_dir}}/{{label}}.md | tee {{output_dir}}/{{label}}.log

# Compare normalized Playwright summaries against a baseline
playwright-report-diff base_input head_input label output_dir=".playwright-report":
    mkdir -p {{output_dir}}
    npx tsx scripts/playwright-report-diff.ts --base {{base_input}} --head {{head_input}} --label {{label}} --json {{output_dir}}/{{label}}-diff.json --markdown {{output_dir}}/{{label}}-diff.md | tee {{output_dir}}/{{label}}-diff.log

# Summarize a WPT VRT shard result JSON
wpt-vrt-report input label output_dir="wpt-vrt-summary":
    mkdir -p {{output_dir}}
    npx tsx scripts/wpt-vrt-summary.ts --input {{input}} --label {{label}} --json {{output_dir}}/{{label}}.json --markdown {{output_dir}}/{{label}}.md | tee {{output_dir}}/{{label}}.log

# Aggregate WPT VRT shard summaries
wpt-vrt-report-aggregate input_dir output_dir="wpt-vrt-summary":
    mkdir -p {{output_dir}}
    npx tsx scripts/wpt-vrt-summary.ts --aggregate {{input_dir}} --json {{output_dir}}/wpt-vrt-summary.json --markdown {{output_dir}}/wpt-vrt-summary.md | tee {{output_dir}}/wpt-vrt-summary.log

# Capture a live site into real-world/ (gitignored)
capture-realworld *args:
    pnpm capture:realworld -- {{args}}

# Run real-world paint benchmark against Chromium and Crater
bench-realworld *args:
    pnpm bench:realworld -- {{args}}

# Run all Playwright-based tests
test-playwright-all: test-playwright test-playwright-adapter test-website

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

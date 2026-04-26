# Crater

A CSS layout engine written in [MoonBit](https://www.moonbitlang.com/), ported from [Taffy](https://github.com/DioxusLabs/taffy).

## Overview

Crater aims to provide layout computation similar to [Yoga](https://yogalayout.dev/) - calculating positions and dimensions of elements based on CSS properties like Flexbox and Grid, without requiring a full browser environment.

This library focuses purely on **layout calculation** - it computes the `x`, `y`, `width`, and `height` of each element in your tree. It does not handle:

- Font loading or text shaping
- Text rendering or measurement (uses approximate character-based sizing)
- Painting or drawing
- DOM manipulation

## Test Status

### Taffy Compatibility Tests

Layout algorithm tests ported from [Taffy](https://github.com/DioxusLabs/taffy):

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| Flexbox | 543 | 609 | 89.2% |
| Block | 204 | 226 | 90.3% |
| Grid | 268 | 331 | 81.0% |
| **Total** | **1015** | **1166** | **87.0%** |

### Parser Tests

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| CSS Parser | 332 | 332 | 100% |
| CSS Selector | 62 | 62 | 100% |
| CSS Media Query | 41 | 41 | 100% |

### Web Platform Tests (WPT)

CSS tests from [web-platform-tests](https://github.com/web-platform-tests/wpt):

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| css-flexbox | 282 | 289 | 97.6% |
| css-grid | 32 | 33 | 97.0% |
| css-tables | 30 | 32 | 93.8% |
| css-display | 79 | 79 | 100.0% |
| css-box | 30 | 30 | 100.0% |
| css-sizing | 83 | 94 | 88.3% |
| css-align | 37 | 44 | 84.1% |
| css-position | 83 | 84 | 98.8% |
| css-overflow | 214 | 243 | 88.1% |
| css-contain | 283 | 303 | 93.4% |
| css-variables | 107 | 107 | 100.0% |
| filter-effects | 98 | 106 | 92.5% |
| compositing | 2 | 2 | 100.0% |
| css-logical | 5 | 5 | 100.0% |
| css-content | 1 | 2 | 50.0% |
| css-multicol | 4 | 4 | 100.0% |
| css-break | 26 | 27 | 96.3% |
| **Total** | **1396** | **1484** | **94.1%** |

Detailed KPI snapshot and module breakdown: [docs/browser-support-kpi.md](docs/browser-support-kpi.md)

### Visual Regression Testing (VRT)

Pixel-level comparison between Chromium and Crater rendering using [kagura](https://github.com/mizchi/kagura) native paint backend:

| Site | Diff | Status |
|------|------|--------|
| example.com | 1.16% | PASS |
| info.cern.ch | 3.30% | PASS |
| www.google.com | 3.80% | PASS |
| news.ycombinator.com | 12.4% | WARN |
| en.wikipedia.org | 7.65% | WARN |

```bash
just vrt-url-native https://example.com        # Compare any URL
just test-wpt-vrt                                # WPT visual regression
CRATER_PAINT_BACKEND=native just test-vrt        # Full VRT suite
```

Browser behavior tests:

| Suite | Passed | Total | Rate |
|-------|--------|-------|------|
| DOM WPT (`wpt/dom/nodes`) | 9296 | 9296 | 100.0% |
| WebDriver BiDi `strict` | 277 | 277 | 100.0% |
| WebDriver BiDi `session` | 130 | 130 | 100.0% |
| WebDriver BiDi `browsing_context` | 1008 | 1008 | 100.0% |
| WebDriver BiDi `script` | 1025 | 1025 | 100.0% |
| WebDriver BiDi `input` | 708 | 708 | 100.0% |
| WebDriver BiDi `network` | 1389 | 1389 | 100.0% |

Run WPT tests:
```bash
npm run wpt:fetch-all  # Fetch all WPT tests
npm run wpt:run-all    # Run all WPT tests
```

WPT target selection is configured in `wpt.json`.

Browser WPT commands:

```bash
just wpt-dom-all
just wpt-webdriver-profile strict
just wpt-webdriver session
just wpt-webdriver browsing_context
just wpt-webdriver script
just wpt-webdriver input
just wpt-webdriver network
```

Optional: external intrinsic providers for text/image in WPT runner:

```bash
# Text module (mizchi/text-compatible or measureText(text, fontSize) module)
CRATER_TEXT_MODULE=/abs/path/to/text-module.js \
CRATER_TEXT_FONT_PATH=/abs/path/to/font.ttf \
npx tsx scripts/wpt-runner.ts css-overflow

# Image module patterns:
# - module itself as function, or resolveImageIntrinsicSize(src) / getImageSize(src) / sizeOf(src)
# - dimensions/getDimensions/metadata/identify/probe/readHeader/imageInfo style functions
# - image-size style functions that accept src, resolved local path, Uint8Array, or Buffer
# - nested namespace exports such as default.image.getImageSize or default.metadata.identify
# - result shapes: {width,height}, [width,height], {dimensions:{width,height}}, {columns,rows}, {shape:[height,width,...]}
# - mizchi/image-style decode_image_stream(bytes) / decode_png(bytes)
# - synchronous callback providers are supported; Promise/stream-only providers are not yet supported
CRATER_IMAGE_MODULE=/abs/path/to/image-module.js \
npx tsx scripts/wpt-runner.ts css-contain

# Optional local file resolver fallback for images (off by default)
CRATER_IMAGE_FILE_RESOLVE=1 \
npx tsx scripts/wpt-runner.ts wpt/css/css-contain/contain-size-021.html
```

- Added recursive module scan for `css-align` and `css-box` via `recursiveModules`
- Expanded `includePrefixes` for additional overflow/alignment coverage
  (`scroll-`, `scrollbar-`, `scrollable-`, `text-overflow-`,
  `column-scroll-`, `targeted-column-scroll-`, `align-`, `place-`)
- Excludes JS harness tests (`testharness.js`, `check-layout-th.js`, interpolation helpers)
  from layout-tree comparison runs

Check current enabled test counts:
```bash
npx tsx scripts/wpt-runner.ts --list
```

#### WPT CI Maintenance (Parallel Shards)

The CI workflow runs WPT compatibility checks with about 6 workers:

- `wpt-css`: 4 shards (`wpt-css (shard-1..4)`)
- `wpt-dom`: 1 job (`wpt-dom`, runs `--dom` and `--svg`)
- `wpt-webdriver`: 1 job (`wpt-webdriver`, runs 10 strict BiDi targets)

See the shard assignment in `.github/workflows/ci.yml` (`wpt-css-tests`, `wpt-dom-tests`, `wpt-webdriver-tests`).

Each run also publishes two summaries:

- `wpt-compat-summary`: compatibility totals/pass rate (`wpt-summary/wpt-compat-summary.md`)
- `ci-timing-summary`: queue/run bottlenecks by job and group (`ci-timing/summary.md`)

Use this checklist when maintaining shard balance:

1. Open the latest GitHub Actions run and check `ci-timing-summary`.
2. Compare `wpt-css (shard-*)` durations in "Slowest Jobs".
3. If one shard is consistently slower (roughly >10s), move modules between shard definitions in `.github/workflows/ci.yml`.
4. Keep each shard runtime close (current target is roughly 65-75s per CSS shard).
5. Verify compatibility totals from `wpt-compat-summary` are not regressing.

Optional local dry-run for summaries:

```bash
# Example: generate per-shard reports
mkdir -p /tmp/wpt-reports
npx tsx scripts/wpt-runner.ts css-overflow css-grid css-tables --workers 4 --json /tmp/wpt-reports/wpt-css-shard-1.json
npx tsx scripts/wpt-dom-runner.ts --dom --json /tmp/wpt-reports/wpt-dom-dom.json
npx tsx scripts/wpt-dom-runner.ts --svg --json /tmp/wpt-reports/wpt-dom-svg.json
npx tsx scripts/wpt-webdriver-runner.ts --subset --json /tmp/wpt-reports/wpt-webdriver-strict.json

# Optional: network sweep profile (non-gating, excludes auth-related paths)
npx tsx scripts/wpt-webdriver-runner.ts --profile network-no-auth --json /tmp/wpt-reports/wpt-webdriver-network-no-auth.json

# Aggregate compatibility summary
npx tsx scripts/wpt-ci-summary.ts --input /tmp/wpt-reports --json /tmp/wpt-summary.json --markdown /tmp/wpt-summary.md

# Analyze CI run timing from GitHub Actions run jobs API output
gh api repos/mizchi/crater/actions/runs/<RUN_ID>/jobs --paginate > /tmp/jobs.json
npx tsx scripts/ci-timing-summary.ts --input /tmp/jobs.json --json /tmp/ci-timing-summary.json --markdown /tmp/ci-timing-summary.md
```

When compatibility improvement/regression should become the new baseline, update `tests/wpt-baseline.env` (used by `scripts/wpt-ci-summary.ts` for CSS baseline delta).

## Features

### Layout Modes
- **Flexbox** - direction, wrap, wrap-reverse, alignment, grow/shrink
- **CSS Grid** - templates, auto-placement, areas, fr units, minmax, repeat
- **Block layout** - margin collapsing
- **Inline layout** - inline formatting context, inline-block

### Box Model
- `margin`, `padding`, `border`
- Percentage and fixed dimensions
- `min-width`, `max-width`, `min-height`, `max-height`
- Intrinsic sizing: `min-content`, `max-content`, `fit-content`
- `box-sizing: border-box`

### Positioning
- `position: static`, `relative`, `absolute`, `fixed`
- `top`, `right`, `bottom`, `left` (inset properties)

### Other Properties
- `gap` (row-gap, column-gap)
- `aspect-ratio`
- `overflow-x`, `overflow-y`
- `visibility: hidden` (with child override)
- CSS Variables (`--var`, `var()`)
- `calc()` CSS function

### Accessibility
- **Accessible Name Computation** - WAI-ARIA accname-1.2 algorithm
- **ARIA Snapshot** - Playwright-compatible YAML/JSON format
- **Accessibility Tree** - Full tree structure with roles, states, and `aria-owns` support

## Performance

HTML parser benchmarks (on Apple Silicon):

| Benchmark | Time |
|-----------|------|
| Simple HTML (100 elements) | ~27 µs |
| Large document (100 sections × 20 paragraphs) | ~5.2 ms |
| Attribute-heavy (200 elements, 6 attrs each) | ~390 µs |
| Table (100×20 cells) | ~990 µs |

Run benchmarks:
```bash
moon bench -p html
```

## Limitations

- **No font rendering**: Text measurement uses approximate monospace character sizing
- **No real text layout**: Word wrapping is simplified
- **Baseline alignment**: Partial implementation
- **Writing modes**: Limited support for vertical text

## Documentation

- [API Reference](docs/api.md) - Public interface documentation
- [Workspace Guide](docs/monorepo-workspace.md) - Canonical module layout, release policy, and migration notes

## Installation

```bash
moon add mizchi/crater
```

### Package Selection

For existing users, `mizchi/crater` and `mizchi/crater/css` remain available as
compatibility facades in the `0.17.x` line.

For new code, prefer importing the narrower module that matches your use case:

```bash
moon add mizchi/crater-layout
moon add mizchi/crater-css
moon add mizchi/crater-dom
moon add mizchi/crater-renderer
moon add mizchi/crater-browser
moon add mizchi/crater-browser-runtime
moon add mizchi/crater-webdriver-bidi
moon add mizchi/crater-wasm
```

Use the root module when you explicitly want the historical all-in-one surface.
Use the split modules when you want a smaller dependency graph or a more stable
public contract for one subsystem.

For browser runtime internals, `mizchi/crater-browser-runtime` is now the
canonical shared contract for the JS runtime and DOM serializer. The older
`mizchi/crater-browser/js` package remains only as a compatibility facade in
the `0.17.x` line.

### Release Policy

- MoonBit modules in this repository are versioned in lockstep with the repo
  release line. `0.17.x` is the first workspace-split line.
- New APIs land in the narrow modules first. The root module keeps compatibility
  wrappers where practical.
- Root compatibility imports are documented but are no longer the recommended
  entry point for new integrations.

## Usage

```moonbit
// Parse HTML and render layout

///|
let html = "<div style=\"display: flex; width: 300px;\"><div style=\"flex: 1\">A</div><div style=\"flex: 2\">B</div></div>"

///|
let ctx = @renderer.RenderContext::default()

///|
let layout = @renderer.render(html, ctx)

// layout contains x, y, width, height for each element
```

## License

Apache-2.0

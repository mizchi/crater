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
| css-flexbox | 289 | 289 | 100.0% |
| css-grid | 30 | 33 | 90.9% |
| css-tables | 26 | 32 | 81.2% |
| css-display | 71 | 79 | 89.9% |
| css-box | 30 | 30 | 100.0% |
| css-sizing | 88 | 94 | 93.6% |
| css-align | 38 | 44 | 86.4% |
| css-position | 84 | 84 | 100.0% |
| css-overflow | 231 | 243 | 95.1% |
| css-contain | 298 | 303 | 98.3% |
| css-variables | 100 | 107 | 93.5% |
| filter-effects | 99 | 106 | 93.4% |
| compositing | 2 | 2 | 100.0% |
| css-logical | 5 | 5 | 100.0% |
| css-content | 2 | 2 | 100.0% |
| css-multicol | 2 | 4 | 50.0% |
| css-break | 27 | 27 | 100.0% |
| **Total** | **1422** | **1484** | **95.8%** |

Run WPT tests:
```bash
npm run wpt:fetch-all  # Fetch all WPT tests
npm run wpt:run-all    # Run all WPT tests
```

WPT target selection is configured in `wpt.json`.

Optional: external intrinsic providers for text/image in WPT runner:

```bash
# Text module (mizchi/text-compatible or measureText(text, fontSize) module)
CRATER_TEXT_MODULE=/abs/path/to/text-module.js \
CRATER_TEXT_FONT_PATH=/abs/path/to/font.ttf \
npx tsx scripts/wpt-runner.ts css-overflow

# Image module (resolveImageIntrinsicSize(src) -> {width,height} or [w,h])
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

## Installation

```bash
moon add mizchi/crater
```

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

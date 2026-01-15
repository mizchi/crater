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
| css-flexbox | 162 | 253 | 64.0% |
| css-grid | 21 | 39 | 53.8% |
| css-sizing | 37 | 103 | 35.9% |
| css-position | 42 | 117 | 35.9% |
| css-tables | 11 | 74 | 14.9% |
| css-display | 12 | 93 | 12.9% |
| **Total** | **285** | **679** | **42.0%** |

Run WPT tests:
```bash
npm run wpt:fetch-all  # Fetch all WPT tests
npm run wpt:run-all    # Run all WPT tests
```

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

MIT

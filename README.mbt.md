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

Layout algorithm tests ported from Taffy:

- **1185 / 1436 tests passing** (82.5%)
- Covers Flexbox, Grid, and Block layout

### Web Platform Tests (WPT)

CSS tests from [web-platform-tests](https://github.com/web-platform-tests/wpt), compared against Chromium reference:

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| css-flexbox | 151 | 234 | 65% |
| css-grid | 16 | 30 | 53% |
| css-sizing | 18 | 50 | 36% |
| css-overflow | 5 | 20 | 25% |
| css-position | 4 | 30 | 13% |

## Features

- Flexbox layout (direction, wrap, wrap-reverse, alignment, grow/shrink)
- CSS Grid layout (templates, auto-placement, areas, fr units, minmax, repeat)
- Block layout with margin collapsing
- Inline layout with inline-block support
- Box model (margin, padding, border)
- Percentage and fixed dimensions
- `min-width`, `max-width`, `min-height`, `max-height`
- `gap` property for flex and grid
- Aspect ratio
- CSS border shorthand parsing
- `position: relative/absolute/fixed` positioning
- `overflow-x`, `overflow-y` properties

## Limitations

- **No font rendering**: Text measurement uses approximate monospace character sizing
- **No real text layout**: Word wrapping is simplified
- **display: none**: Not yet fully supported
- **Baseline alignment**: Partial implementation
- **Writing modes**: Limited support for vertical text

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

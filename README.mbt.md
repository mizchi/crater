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
| Flexbox | 547 | 607 | 90.1% |
| Block | 204 | 224 | 91.1% |
| Grid | 162 | 331 | 48.9% |
| **Total** | **913** | **1162** | **78.6%** |

### Parser Tests

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| CSS Parser | 150 | 150 | 100% |
| CSS Selector | 54 | 54 | 100% |
| CSS Media Query | 38 | 38 | 100% |
| HTML Parser | 106 | 111 | 95.5% |

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
- `position: relative`, `absolute`, `fixed`
- `top`, `right`, `bottom`, `left` (inset properties)

### Other Properties
- `gap` (row-gap, column-gap)
- `aspect-ratio`
- `overflow-x`, `overflow-y`
- `contain` (size, layout, inline-size)
- `calc()` CSS function

## Limitations

- **No font rendering**: Text measurement uses approximate monospace character sizing
- **No real text layout**: Word wrapping is simplified
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

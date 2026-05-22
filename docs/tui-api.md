# TUI API Reference

This document covers the current layout/TUI-facing package boundaries. The old
root type/style/layout subpackage paths have been retired; use the split
modules below.

## Imports

```json
{
  "import": [
    { "path": "mizchi/crater-core", "alias": "core" },
    { "path": "mizchi/crater-core/node", "alias": "node" },
    { "path": "mizchi/crater-layout", "alias": "layout" },
    { "path": "mizchi/crater-layout/tree", "alias": "tree" },
    { "path": "mizchi/crater-layout/core_subset", "alias": "core_subset" },
    { "path": "mizchi/css/style", "alias": "style" },
    { "path": "mizchi/css/values", "alias": "values" }
  ]
}
```

Use `mizchi/crater-browser/tui` only when you need the browser shell's terminal
runtime. Pure layout code should stay on `crater-core`, `crater-layout`, and
`mizchi/css`.

## Core Types

| Need | Package |
| --- | --- |
| Layout output records | `mizchi/crater-core` |
| Layout input nodes and measure functions | `mizchi/crater-core/node` |
| CSS dimensions, lengths, rects, and colors | `mizchi/css/values` |
| Display, flex, grid, overflow, position, and style values | `mizchi/css/style` |
| Layout computation | `mizchi/crater-layout` |
| Incremental layout trees | `mizchi/crater-layout/tree` |
| Checked TUI subset | `mizchi/crater-layout/core_subset` |

## Basic Layout

```moonbit
let root = @node.Node::new(
  id=1,
  style=@style.Style::default(),
  children=[],
)

let viewport = @values.Size::{ width: 800.0, height: 600.0 }
let result = @layout.compute_layout(root, viewport)
```

Use `compute_layout_with_warnings` when a caller needs diagnostics instead of a
plain layout result.

```moonbit
let result = @layout.compute_layout_with_warnings(root, viewport)
inspect(result.warnings.length())
```

## Incremental Tree

```moonbit
let tree = @layout.layout_tree_from_node(root, 800.0, 600.0)
let first = tree.compute_full()

tree.resize_viewport(1024.0, 768.0)
let updated = tree.compute_incremental()
```

Use the tree package for stateful TUI surfaces where only part of the node tree
changes between frames.

## Checked Core Subset

`mizchi/crater-layout/core_subset` is the safer boundary for TUI code that wants
layout validation before computing.

```moonbit
let checked = @core_subset.compute_layout_checked(root, viewport)
```

Prefer this package for terminal UI experiments and tests that should reject
unsupported layout states early.

## Paint For TUI

Browser-local terminal paint helpers live under `mizchi/crater-browser/tui`.
They are integration helpers, not the canonical paint model.

| Need | Package |
| --- | --- |
| Plain layout to paint conversion | `mizchi/crater-browser/tui/paint/plain` |
| Viewport-aware conversion | `mizchi/crater-browser/tui/paint/viewport` |
| Prepared paint runtime helpers | `mizchi/crater-browser/tui/paint/runtime` |
| JSON/framebuffer export | `mizchi/crater-browser/tui/paint/export` |
| PNG export | `mizchi/crater-browser/tui/paint/png` |

For reusable paint model code, use `mizchi/crater-painter` and
`mizchi/crater-painter/paint/model` instead.

## Public Surface Summary

| Symbol group | Package |
| --- | --- |
| `compute_layout`, `compute_layout_in_context`, `compute_layout_with_warnings` | `mizchi/crater-layout` |
| `LayoutTree`, `LayoutNode`, `CacheStats` | `mizchi/crater-layout/tree` |
| `Node`, `MeasureFunc`, `IntrinsicSize` | `mizchi/crater-core/node` |
| `Layout`, `LayoutContext`, `LayoutResult` | `mizchi/crater-core` |
| `Style` and display/flex/grid enums | `mizchi/css/style` |
| `Size`, `Rect`, `BoundingRect`, color/value types | `mizchi/css/values` |

Keep new TUI code on these module boundaries so browser integration remains
separate from the reusable layout kernel.

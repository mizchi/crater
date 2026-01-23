# Crater TUI API Subset

This document defines the stable API subset for Terminal User Interface (TUI) applications. Designed with the [moonbitlang/maria](https://github.com/moonbitlang/maria) TUI framework in mind.

## Design Philosophy

1. **Coordinate-based approach**: Specify rectangles with `x1, y1, x2, y2` (Grid) or flow-based (Flex)
2. **Programmable control**: Enable dynamic layout control from application code
3. **Overlapping support**: Allow cells to intersect for modal dialogs, popups, etc.
4. **Grid-first for 2D**: Grid with coordinate placement is clearer than nested Flex for complex layouts

Reference: [Programmable Grid Layout Control](https://zenn.dev/mizchi/articles/programmable-grid)

---

## Quick Start

```moonbit
// Import the crater package
// In moon.pkg.json: { "import": ["mizchi/crater", "mizchi/crater/types", "mizchi/crater/style", "mizchi/crater/layout/node"] }

// Build a simple flex layout
let style = @style.Style::default()
style.display = @types.Flex
style.flex_direction = @types.Column
style.width = @types.Length(80.0)
style.height = @types.Length(24.0)

let child_style = @style.Style::default()
child_style.flex_grow = 1.0

let root = @node.Node::new("root", style, [
  @node.Node::leaf("header", child_style),
  @node.Node::leaf("content", child_style),
])

// Compute layout
let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

// Access results
println(layout.children[0].height)  // Header height
println(layout.children[1].height)  // Content height
```

---

## Core Entry Point

### `mizchi/crater`

```moonbit
/// Compute layout from a Node tree (one-shot)
/// @param node - Root node of the layout tree
/// @param viewport - Available viewport size (width, height)
/// @return Computed layout with positions and sizes
pub fn compute_layout(node: Node, viewport: Size[Double]) -> Layout
```

---

## Incremental Layout (LayoutTree)

For TUI applications that need efficient re-layout on state changes, use `LayoutTree` instead of the one-shot `compute_layout`. The tree caches layout results and only recomputes dirty nodes.

### `mizchi/crater/layout/tree`

```moonbit
/// Layout tree with caching for incremental computation
pub struct LayoutTree {
  root : LayoutNode
  viewport_width : Double
  viewport_height : Double
  // ... internal fields
}

/// Create a layout tree from a Node
pub fn LayoutTree::from_node(node: Node, width: Double, height: Double) -> LayoutTree

/// Create a layout tree with a LayoutNode root
pub fn LayoutTree::new(root: LayoutNode, width: Double, height: Double) -> LayoutTree

/// Compute layout incrementally (uses cache for clean nodes)
pub fn LayoutTree::compute_incremental(self: LayoutTree) -> Layout

/// Force full recomputation (ignores cache)
pub fn LayoutTree::compute_full(self: LayoutTree) -> Layout

/// Mark a node as dirty by uid (triggers re-layout on next compute)
pub fn LayoutTree::mark_node_dirty(self: LayoutTree, uid: Int) -> Unit

/// Resize the viewport (marks viewport-dependent nodes dirty)
pub fn LayoutTree::resize_viewport(self: LayoutTree, width: Double, height: Double) -> Unit

/// Find a node by string id
pub fn LayoutTree::find_node_by_id(self: LayoutTree, id: String) -> LayoutNode?

/// Check if layout is needed
pub fn LayoutTree::needs_layout(self: LayoutTree) -> Bool
```

### LayoutNode

`LayoutNode` is a mutable node type with dirty tracking and Yoga-style setter methods.

```moonbit
pub struct LayoutNode {
  id : String
  uid : Int
  style : Style
  children : Array[LayoutNode]
  measure : MeasureFunc?
  text : String?
  mut dirty : Bool
  // ... caching fields
}

/// Create a layout node
pub fn LayoutNode::new(id: String, style: Style, children: Array[LayoutNode]) -> LayoutNode
pub fn LayoutNode::leaf(id: String, style: Style) -> LayoutNode
pub fn LayoutNode::with_measure(id: String, style: Style, measure: MeasureFunc) -> LayoutNode

/// Convert from Node to LayoutNode
pub fn LayoutNode::from_node(node: Node) -> LayoutNode

/// Mark this node as needing re-layout
pub fn LayoutNode::mark_dirty(self: LayoutNode) -> Unit

/// Check if node needs layout
pub fn LayoutNode::is_dirty(self: LayoutNode) -> Bool
pub fn LayoutNode::needs_layout(self: LayoutNode) -> Bool

/// Yoga-style setters (chainable, marks dirty automatically)
pub fn LayoutNode::set_width(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_height(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_width_percent(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_height_percent(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_width_auto(self: LayoutNode) -> LayoutNode
pub fn LayoutNode::set_height_auto(self: LayoutNode) -> LayoutNode
pub fn LayoutNode::set_flex_grow(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_flex_shrink(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_flex_direction(self: LayoutNode, dir: FlexDirection) -> LayoutNode
pub fn LayoutNode::set_display(self: LayoutNode, display: Display) -> LayoutNode
pub fn LayoutNode::set_margin(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_padding(self: LayoutNode, value: Double) -> LayoutNode
pub fn LayoutNode::set_gap(self: LayoutNode, value: Double) -> LayoutNode
// ... and many more setters
```

### Incremental Layout Example

```moonbit
fn main {
  // Build initial tree
  let root_style = @style.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column

  let root_node = @node.Node::new("root", root_style, [
    @node.Node::leaf("header", header_style),
    @node.Node::leaf("content", content_style),
  ])

  // Create layout tree
  let tree = @tree.LayoutTree::from_node(root_node, 80.0, 24.0)

  // Initial layout
  let layout = tree.compute_incremental()

  // ... user interaction changes content height ...

  // Find and modify a node
  match tree.find_node_by_id("content") {
    Some(node) => {
      node.set_height(10.0)  // Automatically marks dirty
    }
    None => ()
  }

  // Recompute only dirty nodes
  let new_layout = tree.compute_incremental()  // Fast: only recomputes affected nodes
}
```

### When to Use LayoutTree vs compute_layout

| Scenario | Recommended |
|----------|-------------|
| Static layout (computed once) | `compute_layout` |
| Frequent style changes | `LayoutTree` |
| Window resize handling | `LayoutTree` with `resize_viewport` |
| Animation/transitions | `LayoutTree` |
| Simple one-off layouts | `compute_layout` |

---

## Essential Types

### `mizchi/crater/types`

#### Size and Rect

```moonbit
/// 2D dimensions
pub struct Size[T] {
  width : T
  height : T
}
pub fn Size::new[T](width: T, height: T) -> Size[T]

/// Four-sided box model (margin, padding, border)
pub struct Rect[T] {
  left : T
  right : T
  top : T
  bottom : T
}
pub fn Rect::zero[T : Default]() -> Rect[T]
pub fn Rect::all[T](value: T) -> Rect[T]
```

#### Dimension

```moonbit
/// CSS dimension values for sizing
pub enum Dimension {
  Length(Double)      // Fixed size in units (e.g., characters for TUI)
  Percent(Double)     // Percentage of parent (0.0 - 100.0)
  Auto                // Automatic sizing based on content/parent
  MinContent          // Minimum size to fit content without wrapping
  MaxContent          // Size to fit content without constraints
  FitContent(Double)  // fit-content(max) - shrink to content up to max
}

/// Resolve dimension to concrete value
pub fn Dimension::resolve(self: Dimension, context: Double) -> Double?
pub fn Dimension::is_definite(self: Dimension) -> Bool
```

#### Display Mode

```moonbit
/// Layout display modes (TUI typically uses Block, Flex, Grid)
pub enum Display {
  Block       // Block-level, stacks vertically
  Flex        // Flexible box layout
  InlineFlex  // Inline-level flex container
  Grid        // Grid layout (coordinate-based)
  InlineGrid  // Inline-level grid container
  None        // Hidden, takes no space
  Contents    // Children promoted to parent
  // ... other values exist but rarely needed for TUI
}
```

#### Flexbox Types

```moonbit
/// Flex container direction
pub enum FlexDirection {
  Row           // Left to right (default)
  RowReverse    // Right to left
  Column        // Top to bottom
  ColumnReverse // Bottom to top
}

/// Flex line wrapping
pub enum FlexWrap {
  NoWrap      // Single line (default)
  Wrap        // Wrap to new lines
  WrapReverse // Wrap in reverse order
}

/// Alignment for justify-content, align-items, align-content
pub enum Alignment {
  Start         // Pack to start
  End           // Pack to end
  Center        // Pack to center
  SpaceBetween  // Distribute with space between items
  SpaceAround   // Distribute with space around items
  SpaceEvenly   // Distribute with equal space
  Stretch       // Stretch to fill (default for align-items)
  Baseline      // Align to text baseline
}

/// Self-alignment override
pub enum AlignSelf {
  Auto    // Inherit from parent's align-items
  Start
  End
  Center
  Stretch
  Baseline
}
```

#### Grid Types

```moonbit
/// Track sizing for grid rows/columns
pub enum TrackSizingFunction {
  Length(Double)              // Fixed size
  Percent(Double)             // Percentage of container
  Fr(Double)                  // Fractional unit (flexible)
  MinContent                  // Minimum content size
  MaxContent                  // Maximum content size
  FitContent(Double)          // Clamp to max
  Auto                        // Automatic sizing
  MinMax(MinMax)              // min-max range
  Repeat(RepeatCount, Array[TrackSizingFunction])  // Repeated tracks
}

/// Grid auto-placement algorithm
pub enum GridAutoFlow {
  Row         // Fill rows first (default)
  Column      // Fill columns first
  RowDense    // Row-first with dense packing
  ColumnDense // Column-first with dense packing
}

/// Grid line placement
pub struct GridLine {
  start : GridPlacement
  end : GridPlacement
}

/// Grid item placement
pub enum GridPlacement {
  Auto        // Automatic placement
  Line(Int)   // Specific grid line (1-indexed)
  Span(Int)   // Span N tracks
}
```

#### Measurement

```moonbit
/// Custom measurement function for text/replaced content
pub struct MeasureFunc {
  func : (Double, Double) -> IntrinsicSize
  // func(available_width, available_height) -> intrinsic sizes
}

/// Intrinsic size result from measurement
pub struct IntrinsicSize {
  min_width : Double   // Minimum width (e.g., longest word)
  max_width : Double   // Maximum width (e.g., unwrapped text)
  min_height : Double  // Minimum height
  max_height : Double  // Maximum height (e.g., wrapped text)
}
```

#### Position and Overflow

```moonbit
/// CSS position property
pub enum Position {
  Static    // Normal flow (default)
  Relative  // Offset from normal position
  Absolute  // Positioned relative to containing block
  Fixed     // Positioned relative to viewport
}

/// Overflow handling
pub enum Overflow {
  Visible // Content can overflow (default)
  Hidden  // Clip overflow content
  Scroll  // Always show scrollbars
  Auto    // Show scrollbars when needed
}
```

---

### `mizchi/crater/style`

#### Style Struct

All fields are mutable for easy configuration.

```moonbit
pub struct Style {
  // Display and positioning
  mut display : Display           // Default: Block
  mut position : Position         // Default: Static
  mut box_sizing : BoxSizing      // Default: ContentBox

  // Sizing
  mut width : Dimension           // Default: Auto
  mut height : Dimension          // Default: Auto
  mut min_width : Dimension       // Default: Auto
  mut min_height : Dimension      // Default: Auto
  mut max_width : Dimension       // Default: Auto
  mut max_height : Dimension      // Default: Auto

  // Box model
  mut margin : Rect[Dimension]    // Default: zero
  mut padding : Rect[Dimension]   // Default: zero
  mut border : Rect[Dimension]    // Default: zero

  // Flexbox (container)
  mut flex_direction : FlexDirection  // Default: Row
  mut flex_wrap : FlexWrap            // Default: NoWrap
  mut justify_content : Alignment     // Default: Start
  mut align_items : Alignment         // Default: Stretch
  mut align_content : Alignment       // Default: Stretch

  // Flexbox (item)
  mut align_self : AlignSelf      // Default: Auto
  mut flex_grow : Double          // Default: 0.0
  mut flex_shrink : Double        // Default: 1.0
  mut flex_basis : Dimension      // Default: Auto

  // Gap
  mut row_gap : Dimension         // Default: Length(0)
  mut column_gap : Dimension      // Default: Length(0)

  // Grid (container)
  mut grid_template_rows : Array[TrackSizingFunction]
  mut grid_template_columns : Array[TrackSizingFunction]
  mut grid_template_areas : Array[String]  // Named areas
  mut grid_auto_flow : GridAutoFlow        // Default: Row
  mut grid_auto_rows : Array[TrackSizingFunction]
  mut grid_auto_columns : Array[TrackSizingFunction]

  // Grid (item)
  mut grid_row : GridLine         // Row placement
  mut grid_column : GridLine      // Column placement
  mut grid_area : String?         // Named area placement

  // Position offsets (for position: relative/absolute/fixed)
  mut inset : Rect[Dimension]     // top, right, bottom, left

  // Overflow
  mut overflow_x : Overflow       // Default: Visible
  mut overflow_y : Overflow       // Default: Visible
}

/// Create a default style
pub fn Style::default() -> Style
```

---

### `mizchi/crater/layout/node`

#### Node Struct

```moonbit
pub struct Node {
  id : String              // Unique identifier for this node
  uid : Int                // Internal uid (auto-generated)
  style : Style            // CSS styles
  children : Array[Node]   // Child nodes
  measure : MeasureFunc?   // Custom measurement (for text/images)
  text : String?           // Text content (if any)
}
```

#### Constructors

```moonbit
/// Create a node with children
pub fn Node::new(id: String, style: Style, children: Array[Node]) -> Node

/// Create a leaf node (no children)
pub fn Node::leaf(id: String, style: Style) -> Node

/// Create a node with custom measurement function
pub fn Node::with_measure(
  id: String,
  style: Style,
  measure: MeasureFunc,
  text~ : String?
) -> Node

/// Create a text node (convenience wrapper)
pub fn Node::text(
  id: String,
  style: Style,
  measure: MeasureFunc,
  content: String
) -> Node
```

---

### Layout Result

```moonbit
/// Computed layout result
pub struct Layout {
  id : String              // Node identifier
  x : Double               // X position relative to parent
  y : Double               // Y position relative to parent
  width : Double           // Computed width
  height : Double          // Computed height
  margin : Rect[Double]    // Resolved margin values
  padding : Rect[Double]   // Resolved padding values
  border : Rect[Double]    // Resolved border values
  overflow_x : Overflow    // X overflow mode
  overflow_y : Overflow    // Y overflow mode
  children : Array[Layout] // Child layouts
  text : String?           // Text content (if any)
}
```

---

## Usage Examples

### Flex Layout (Vertical Stack)

```moonbit
fn main {
  // Root container: vertical flex
  let root_style = @style.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)

  // Header: fixed height
  let header_style = @style.Style::default()
  header_style.height = @types.Length(3.0)

  // Content: flexible
  let content_style = @style.Style::default()
  content_style.flex_grow = 1.0

  // Footer: fixed height
  let footer_style = @style.Style::default()
  footer_style.height = @types.Length(1.0)

  let root = @node.Node::new("root", root_style, [
    @node.Node::leaf("header", header_style),
    @node.Node::leaf("content", content_style),
    @node.Node::leaf("footer", footer_style),
  ])

  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Results:
  // header: y=0, height=3
  // content: y=3, height=20 (24 - 3 - 1)
  // footer: y=23, height=1
}
```

### Flex Layout (Horizontal Split)

```moonbit
fn main {
  let root_style = @style.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Row

  // Sidebar: 20 units wide
  let sidebar_style = @style.Style::default()
  sidebar_style.width = @types.Length(20.0)

  // Main: fill remaining space
  let main_style = @style.Style::default()
  main_style.flex_grow = 1.0

  let root = @node.Node::new("root", root_style, [
    @node.Node::leaf("sidebar", sidebar_style),
    @node.Node::leaf("main", main_style),
  ])

  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))
  // sidebar: x=0, width=20
  // main: x=20, width=60
}
```

### Grid Layout (Coordinate-Based)

```moonbit
fn main {
  // 3x3 grid
  let grid_style = @style.Style::default()
  grid_style.display = @types.Grid
  grid_style.width = @types.Length(80.0)
  grid_style.height = @types.Length(24.0)
  grid_style.grid_template_columns = [@types.Fr(1.0), @types.Fr(1.0), @types.Fr(1.0)]
  grid_style.grid_template_rows = [@types.Fr(1.0), @types.Fr(1.0), @types.Fr(1.0)]

  // Helper: place item at grid coordinates (x1, y1) -> (x2, y2)
  fn place_at(x1: Int, y1: Int, x2: Int, y2: Int) -> @style.Style {
    let s = @style.Style::default()
    s.grid_column = { start: @types.Line(x1), end: @types.Line(x2) }
    s.grid_row = { start: @types.Line(y1), end: @types.Line(y2) }
    s
  }

  // Header spans full width: (1,1) -> (4,2)
  let header = @node.Node::leaf("header", place_at(1, 1, 4, 2))

  // Sidebar: left column (1,2) -> (2,4)
  let sidebar = @node.Node::leaf("sidebar", place_at(1, 2, 2, 4))

  // Main content: right columns (2,2) -> (4,4)
  let main = @node.Node::leaf("main", place_at(2, 2, 4, 4))

  let root = @node.Node::new("root", grid_style, [header, sidebar, main])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))
}
```

### Grid Layout (Named Areas)

```moonbit
fn main {
  let grid_style = @style.Style::default()
  grid_style.display = @types.Grid
  grid_style.grid_template_columns = [@types.Fr(1.0), @types.Fr(2.0)]
  grid_style.grid_template_rows = [@types.Length(3.0), @types.Fr(1.0)]
  grid_style.grid_template_areas = [
    "header header",
    "sidebar main",
  ]

  fn area(name: String) -> @style.Style {
    let s = @style.Style::default()
    s.grid_area = Some(name)
    s
  }

  let root = @node.Node::new("root", grid_style, [
    @node.Node::leaf("header", area("header")),
    @node.Node::leaf("sidebar", area("sidebar")),
    @node.Node::leaf("main", area("main")),
  ])

  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))
}
```

### Text Measurement

```moonbit
/// Calculate display width of a string (considering wide characters)
fn string_display_width(s: String) -> Int {
  // Simple implementation - each char is 1 unit
  // For real TUI, use wcwidth or similar
  s.length()
}

/// Create a text measurement function
fn text_measure_func(text: String) -> @types.MeasureFunc {
  {
    func: fn(available_width: Double, _available_height: Double) -> @types.IntrinsicSize {
      let text_width = string_display_width(text).to_double()
      let wrapped_lines = if available_width > 0.0 {
        (text_width / available_width).ceil().max(1.0)
      } else {
        1.0
      }
      {
        min_width: 1.0,  // Minimum: 1 character
        max_width: text_width,
        min_height: 1.0,
        max_height: wrapped_lines,
      }
    }
  }
}

fn main {
  let text_style = @style.Style::default()

  let node = @node.Node::with_measure(
    "greeting",
    text_style,
    text_measure_func("Hello, World!"),
    text="Hello, World!"
  )

  let layout = @crater.compute_layout(node, @types.Size::new(80.0, 24.0))
  // layout.width based on text measurement
}
```

### Overlapping Elements (Modal Dialog)

```moonbit
fn main {
  let grid_style = @style.Style::default()
  grid_style.display = @types.Grid
  grid_style.grid_template_columns = [@types.Fr(1.0), @types.Fr(1.0), @types.Fr(1.0), @types.Fr(1.0)]
  grid_style.grid_template_rows = [@types.Fr(1.0), @types.Fr(1.0), @types.Fr(1.0), @types.Fr(1.0)]

  fn place_at(x1: Int, y1: Int, x2: Int, y2: Int) -> @style.Style {
    let s = @style.Style::default()
    s.grid_column = { start: @types.Line(x1), end: @types.Line(x2) }
    s.grid_row = { start: @types.Line(y1), end: @types.Line(y2) }
    s
  }

  // Background content: full grid
  let background = @node.Node::leaf("bg", place_at(1, 1, 5, 5))

  // Modal dialog: centered overlay (2,2) -> (4,4)
  let modal = @node.Node::leaf("modal", place_at(2, 2, 4, 4))

  let root = @node.Node::new("root", grid_style, [background, modal])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Both elements are positioned, modal overlaps background
  // Rendering order determines visual stacking
}
```

---

## API Stability Guidelines

### Stable (Will Not Change)

These APIs are stable and safe to depend on:

| API | Package |
|-----|---------|
| `compute_layout(Node, Size[Double]) -> Layout` | `mizchi/crater` |
| `Node::new`, `Node::leaf`, `Node::with_measure` | `mizchi/crater/layout/node` |
| `Style::default()` | `mizchi/crater/style` |
| `Size`, `Rect`, `Dimension`, `Layout` structs | `mizchi/crater/types` |
| `Display`, `FlexDirection`, `FlexWrap`, `Alignment`, `AlignSelf` enums | `mizchi/crater/types` |
| `Position`, `Overflow` enums | `mizchi/crater/types` |
| `MeasureFunc`, `IntrinsicSize` structs | `mizchi/crater/types` |

### Unstable (May Change)

These APIs may change before 1.0:

| API | Reason |
|-----|--------|
| `compute_layout_with_warnings()` | Warning format may change |
| Grid-related types (`TrackSizingFunction`, `GridPlacement`, etc.) | Grid spec is complex, API may evolve |
| `LayoutContext` | Internal implementation detail |

### Internal (Do Not Use)

These are internal implementation details:

| API | Reason |
|-----|--------|
| `DispatchFn`, `LayoutDispatchFunc` | Deprecated dispatch mechanism |
| `layout/dispatch`, `layout/tree` modules | Internal implementation |
| Web Vitals APIs | Not relevant for TUI |

---

## Not Included for TUI

The following Crater features are not part of the TUI API subset:

- **HTML/CSS parsing**: Use direct Node construction instead
- **DOM manipulation**: Build your own tree structure
- **Paint tree**: Implement your own rendering
- **Accessibility (AOM)**: Handle accessibility separately
- **Web Vitals**: Browser-specific metrics
- **Table layout**: Use Grid instead
- **Visual properties**: `color`, `background_color`, `opacity`, `z_index` - handle in your renderer

---

## Package Dependencies

For TUI applications, add these imports to your `moon.pkg.json`:

```json
{
  "import": [
    "mizchi/crater",
    "mizchi/crater/types",
    "mizchi/crater/style",
    "mizchi/crater/layout/node"
  ]
}
```

Minimal import (if you only need types):

```json
{
  "import": [
    "mizchi/crater",
    "mizchi/crater/types"
  ]
}
```

---

## Version Compatibility

- **Current**: Pre-1.0 (breaking changes possible)
- **Target**: Stable TUI API subset for 1.0 release
- **Semver**: Breaking changes will bump minor version until 1.0

When upgrading, check:
1. `.mbti` files for interface changes
2. This document for API stability updates
3. CHANGELOG for breaking changes

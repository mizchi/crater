# Crater Public API Reference

This document describes the public interfaces provided by Crater for external use.

## Package Overview

```
mizchi/crater                 # Main entry point
├── types/                    # Core types (Dimension, Rect, Size, Color)
├── style/                    # CSS style definitions (Style, Display, Position)
├── node/                     # Layout nodes (Node, Layout, LayoutContext)
├── html/                     # HTML parser (parse_document, Element)
├── css/
│   ├── parser/              # CSS parser (parse_stylesheet)
│   ├── cascade/             # Cascade algorithm (Stylesheet, CascadedValues)
│   ├── selector/            # CSS selectors (ComplexSelector, matches_*)
│   ├── media/               # Media queries (MediaQueryList)
│   └── diagnostics/         # CSS diagnostics (DiagnosticsCollector)
├── dom/                      # DOM tree (DomTree, MutationRecord)
├── tree/                     # Layout tree (LayoutTree, LayoutNode)
├── renderer/                 # Rendering API (render, RenderContext)
├── paint/                    # Paint tree (PaintNode, PaintProperties)
├── aom/                      # Accessibility (AccessibilityTree, Role)
└── webvitals/               # Web Vitals metrics (LCPTracker, LayoutShift)
```

---

## High-Level API

### `mizchi/crater` (Root Package)

Main entry point for layout computation.

```moonbit
// Compute layout from a Node tree
pub fn compute_layout(Node, Size[Double]) -> Layout

// Compute layout with warnings for unsupported features
pub fn compute_layout_with_warnings(Node, Size[Double]) -> LayoutResult

// Compute CLS (Cumulative Layout Shift) score
pub fn compute_total_cls(Array[BoundingRect], Array[BoundingRect], Size[Double]) -> Double
```

### `mizchi/crater/renderer`

High-level rendering API for HTML strings.

```moonbit
// Render HTML string to Layout
pub fn render(String, RenderContext) -> Layout

// Render HTML with external CSS
pub fn render_with_external_css(String, RenderContext, Array[String]) -> Layout

// Render to Node (without layout computation)
pub fn render_to_node(String, RenderContext) -> Node

// Render to Sixel format (terminal graphics)
pub fn render_to_sixel(String, Int, Int) -> String

// RenderContext configuration
pub struct RenderContext {
  viewport_width : Double
  viewport_height : Double
  root_font_size : Double
  color_scheme : ColorScheme
}
pub fn RenderContext::default() -> Self
```

---

## Core Types

### `mizchi/crater/types`

Basic geometric and color types.

```moonbit
// Dimension for CSS values
pub enum Dimension {
  Length(Double)      // Fixed pixel value
  Percent(Double)     // Percentage value
  Auto                // Auto sizing
  MinContent          // Minimum content size
  MaxContent          // Maximum content size
  FitContent(Double)  // Fit content with max
}

// Rectangle with four sides
pub struct Rect[T] {
  left : T
  right : T
  top : T
  bottom : T
}

// 2D Size
pub struct Size[T] {
  width : T
  height : T
}

// 2D Point
pub struct Point[T] {
  x : T
  y : T
}

// RGBA Color
pub struct Color {
  r : Int
  g : Int
  b : Int
  a : Double
}
pub fn Color::rgb(Int, Int, Int) -> Self
pub fn Color::rgba(Int, Int, Int, Double) -> Self

// Bounding rectangle
pub struct BoundingRect {
  x : Double
  y : Double
  width : Double
  height : Double
}
```

### `mizchi/crater/style`

CSS style property definitions.

```moonbit
pub struct Style {
  display : Display
  position : Position
  box_sizing : BoxSizing
  overflow_x : Overflow
  overflow_y : Overflow

  // Dimensions
  width : Dimension
  height : Dimension
  min_width : Dimension
  max_width : Dimension
  // ... (see full definition in style/pkg.generated.mbti)

  // Flexbox
  flex_direction : FlexDirection
  flex_wrap : FlexWrap
  justify_content : Alignment
  align_items : Alignment
  flex_grow : Double
  flex_shrink : Double
  flex_basis : Dimension

  // Grid
  grid_template_rows : Array[TrackSizingFunction]
  grid_template_columns : Array[TrackSizingFunction]
  grid_auto_flow : GridAutoFlow
  // ...
}

pub enum Display {
  Block | Inline | InlineBlock | Flex | InlineFlex
  Grid | InlineGrid | Table | None | Contents | FlowRoot
  // ...
}

pub enum Position { Static | Relative | Absolute | Fixed }
pub enum FlexDirection { Row | RowReverse | Column | ColumnReverse }
pub enum FlexWrap { NoWrap | Wrap | WrapReverse }
pub enum Alignment { Start | End | Center | SpaceBetween | SpaceAround | Stretch | ... }
pub enum GridAutoFlow { Row | Column | RowDense | ColumnDense }
```

---

## Layout System

### `mizchi/crater/node`

Layout node representation.

```moonbit
// Input node for layout computation
pub struct Node {
  id : String
  uid : Int
  style : Style
  children : Array[Node]
  measure : MeasureFunc?
  text : String?
}
pub fn Node::new(String, Style, Array[Node]) -> Self
pub fn Node::leaf(String, Style) -> Self
pub fn Node::with_measure(String, Style, MeasureFunc, text? : String) -> Self

// Output layout result
pub struct Layout {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  margin : Rect[Double]
  padding : Rect[Double]
  border : Rect[Double]
  overflow_x : Overflow
  overflow_y : Overflow
  children : Array[Layout]
  text : String?
}

// Layout computation context
pub struct LayoutContext {
  available_width : Double
  available_height : Double?
  sizing_mode : SizingMode
  viewport_width : Double
  viewport_height : Double
}

// Custom measurement function
pub struct MeasureFunc {
  func : (Double, Double) -> IntrinsicSize
}

pub struct IntrinsicSize {
  min_width : Double
  max_width : Double
  min_height : Double
  max_height : Double
}
```

### `mizchi/crater/tree`

Incremental layout tree for efficient updates.

```moonbit
// Layout tree with caching
pub struct LayoutTree {
  root : LayoutNode
  viewport_width : Double
  viewport_height : Double
  // ...
}
pub fn LayoutTree::new(LayoutNode, Double, Double) -> Self
pub fn LayoutTree::from_html_document(Document, Double, Double) -> Self
pub fn LayoutTree::from_node(Node, Double, Double) -> Self
pub fn LayoutTree::compute_incremental(Self) -> Layout
pub fn LayoutTree::compute_full(Self) -> Layout
pub fn LayoutTree::resize_viewport(Self, Double, Double) -> Unit
pub fn LayoutTree::mark_node_dirty(Self, Int) -> Unit

// Layout node with dirty tracking
pub struct LayoutNode {
  id : String
  uid : Int
  style : Style
  children : Array[LayoutNode]
  // ... caching fields
}
pub fn LayoutNode::new(String, Style, Array[LayoutNode]) -> Self
pub fn LayoutNode::mark_dirty(Self) -> Unit
pub fn LayoutNode::set_width(Self, Double) -> Self
pub fn LayoutNode::set_height(Self, Double) -> Self
pub fn LayoutNode::set_display(Self, Display) -> Self
// ... many style setters

// DOM + Layout unified document
pub struct Document {
  dom : DomTree
  layout : LayoutTree
  // ...
}
pub fn Document::new(Double, Double) -> Self
pub fn Document::create_element(Self, String) -> NodeId
pub fn Document::append_child(Self, NodeId, NodeId) -> Result[Unit, CoreError]
pub fn Document::compute_layout(Self) -> Layout
pub fn Document::update(Self) -> Layout
```

---

## Parsing

### `mizchi/crater/html`

HTML parser.

```moonbit
// Parse HTML to Element tree
pub fn parse(String) -> Element?
pub fn parse_document(String) -> Document
pub fn parse_fragment(String) -> Element

// Streaming parser for large documents
pub fn parse_document_streaming(String, Int) -> Document

pub struct Document {
  root : Element
  stylesheets : Array[String]
  stylesheet_links : Array[String]
}

pub struct Element {
  tag : String
  id : String?
  classes : Array[String]
  style : String?
  attributes : Map[String, String]
  children : Array[Node]
}

pub enum Node {
  Element(Element)
  Text(String)
}
```

### `mizchi/crater/css/parser`

CSS parser.

```moonbit
// Parse inline style string
pub fn parse_inline_style(String) -> Style

// Parse stylesheet
pub fn parse_stylesheet(String) -> Stylesheet

// Parse with diagnostics
pub fn parse_stylesheet_with_diagnostics(String) -> ParseResult

pub struct ParseResult {
  stylesheet : Stylesheet
  diagnostics : DiagnosticsCollector
}
```

### `mizchi/crater/css/cascade`

CSS cascade algorithm.

```moonbit
pub struct Stylesheet {
  rules : Array[CSSRule]
  origin : Origin
}
pub fn Stylesheet::new(Origin) -> Self
pub fn Stylesheet::match_element(Self, Element) -> Array[RuleMatch]

pub struct CascadedValues {
  values : Map[String, Declaration]
}
pub fn CascadedValues::get(Self, String) -> Declaration?
pub fn CascadedValues::get_value(Self, String) -> String?

pub struct Declaration {
  property : String
  value : PropertyValue
  origin : Origin
  importance : Importance
  specificity : Specificity
  source_order : Int
}

pub enum Origin { UserAgent | User | Author }
pub enum Importance { Normal | Important }
```

### `mizchi/crater/css/selector`

CSS selector matching.

```moonbit
// Parse and match selectors
pub fn parse_selector_text(String) -> ComplexSelector?
pub fn matches_selector_text(Element, String) -> Bool
pub fn matches_complex(Element, ComplexSelector) -> Bool

pub struct ComplexSelector {
  head : CompoundSelector
  tail : Array[ComplexSelectorStep]
}

pub struct Specificity {
  a : Int  // ID selectors
  b : Int  // Class, attribute, pseudo-class
  c : Int  // Type selectors, pseudo-elements
}
```

### `mizchi/crater/css/media`

Media query support.

```moonbit
pub fn parse_media_query_list(String) -> MediaQueryList

pub struct MediaQueryList {
  queries : Array[MediaQuery]
}
pub fn MediaQueryList::evaluate(Self, MediaEnvironment) -> Bool

pub struct MediaEnvironment {
  viewport_width : Double
  viewport_height : Double
  device_pixel_ratio : Double
  color_scheme : ColorScheme
}

pub enum ColorScheme { Light | Dark }
```

---

## DOM

### `mizchi/crater/dom`

DOM tree manipulation.

```moonbit
pub struct DomTree {
  // ...
}
pub fn DomTree::new() -> Self
pub fn DomTree::create_element(Self, String) -> NodeId
pub fn DomTree::create_text(Self, String) -> NodeId
pub fn DomTree::append_child(Self, NodeId, NodeId) -> Result[Unit, CoreError]
pub fn DomTree::remove_child(Self, NodeId, NodeId) -> Result[Unit, CoreError]
pub fn DomTree::set_attribute(Self, NodeId, String, String) -> Result[Unit, CoreError]
pub fn DomTree::get_attribute(Self, NodeId, String) -> Result[String?, CoreError]
pub fn DomTree::query_selector(Self, NodeId, String) -> Result[NodeId?, CoreError]
pub fn DomTree::query_selector_all(Self, NodeId, String) -> Result[Array[NodeId], CoreError]

// Mutation tracking
pub fn DomTree::flush_mutations(Self) -> (Array[MutationRecord], FlushResult)
pub fn DomTree::has_pending_mutations(Self) -> Bool

pub struct NodeId(Int)
pub fn NodeId::to_int(Self) -> Int

pub enum MutationType { ChildList | Attributes | CharacterData | StyleChange }

pub struct MutationRecord {
  type_ : MutationType
  target : NodeId
  added_nodes : Array[NodeId]
  removed_nodes : Array[NodeId]
  attribute_name : String?
  // ...
}
```

---

## Accessibility

### `mizchi/crater/aom`

Accessibility Object Model.

```moonbit
// Build accessibility tree from HTML
pub fn build_accessibility_tree(Document) -> AccessibilityTree
pub fn build_accessibility_tree_with_layout(Document, LayoutTree) -> AccessibilityTree

pub struct AccessibilityTree {
  root : AccessibilityNode
  node_map : Map[String, AccessibilityNode]
}
pub fn AccessibilityTree::find_by_id(Self, String) -> AccessibilityNode?
pub fn AccessibilityTree::find_by_role(Self, Role) -> Array[AccessibilityNode]
pub fn AccessibilityTree::to_aria_snapshot(Self) -> String
pub fn AccessibilityTree::to_aria_json(Self) -> String

pub struct AccessibilityNode {
  id : String
  role : Role
  name : String?
  description : String?
  states : Array[State]
  bounds : Bounds?
  children : Array[AccessibilityNode]
  focusable : Bool
  tabindex : Int?
  // ...
}

pub enum Role {
  Button | Checkbox | Link | Textbox | Heading | List | ListItem
  Navigation | Main | Banner | ContentInfo | Form | Search
  // ... (100+ roles)
}

pub enum State {
  Busy | Checked | Disabled | Expanded | Hidden | Invalid | Pressed | Selected
  // ...
}

// Focus management
pub struct FocusManager {
  tree : AccessibilityTree
  // ...
}
pub fn FocusManager::new(AccessibilityTree) -> Self
pub fn FocusManager::focus_next(Self) -> AccessibilityNode?
pub fn FocusManager::focus_prev(Self) -> AccessibilityNode?
pub fn FocusManager::current(Self) -> AccessibilityNode?
```

---

## Paint

### `mizchi/crater/paint`

Paint tree for rendering.

```moonbit
// Create paint tree from layout
pub fn from_layout(Layout) -> PaintNode
pub fn from_node_and_layout(Node, Layout) -> PaintNode

pub struct PaintNode {
  id : String
  tag : String
  x : Double
  y : Double
  width : Double
  height : Double
  overflow_x : Overflow
  overflow_y : Overflow
  paint : PaintProperties
  stacking_order : Int
  text : String?
  children : Array[PaintNode]
}

pub struct PaintProperties {
  z_index : ZIndex
  visibility : Visibility
  opacity : Double
  color : Color
  background_color : Color
}
pub fn PaintProperties::should_render(Self) -> Bool
```

---

## Metrics

### `mizchi/crater/webvitals`

Web Vitals metrics.

```moonbit
// Layout Shift calculation
pub fn compute_element_shift(BoundingRect, BoundingRect, Size[Double]) -> LayoutShift
pub fn compute_total(Array[BoundingRect], Array[BoundingRect], Size[Double]) -> Double

pub struct LayoutShift {
  impact_fraction : Double
  distance_fraction : Double
  score : Double
}

// LCP tracking
pub struct LCPTracker {
  // ...
}
pub fn LCPTracker::new(Double, Double) -> Self
pub fn LCPTracker::add_candidate(Self, LCPCandidate) -> Unit
pub fn LCPTracker::get_lcp(Self) -> LCPCandidate?
pub fn LCPTracker::get_lcp_time(Self) -> Double?

pub struct LCPCandidate {
  element_id : String
  element_type : LCPElementType
  size : Double
  // ...
}
```

---

## Diagnostics

### `mizchi/crater/css/diagnostics`

CSS property support diagnostics.

```moonbit
pub fn get_support_level(String) -> SupportLevel

pub enum SupportLevel {
  Supported
  Partial(String)
  UnsupportedLayout
  UnsupportedVisual
  Deprecated(String)
  Unknown
}

pub struct DiagnosticsCollector {
  // ...
}
pub fn DiagnosticsCollector::new() -> Self
pub fn DiagnosticsCollector::add_property(Self, String, String, String) -> Unit
pub fn DiagnosticsCollector::get_diagnostics(Self) -> Array[Diagnostic]
pub fn DiagnosticsCollector::get_summary(Self) -> DiagnosticSummary
pub fn DiagnosticsCollector::format_report(Self, Int) -> String
```

---

## Usage Examples

### Basic Layout

```moonbit
let html = "<div style=\"display: flex; width: 300px;\">
  <div style=\"flex: 1\">A</div>
  <div style=\"flex: 2\">B</div>
</div>"

let ctx = @renderer.RenderContext::default()
let layout = @renderer.render(html, ctx)
// layout.children[0].width == 100.0
// layout.children[1].width == 200.0
```

### Incremental Layout

```moonbit
let doc = @tree.Document::new(800.0, 600.0)
let root = doc.get_document_root()

let div = doc.create_element("div")
doc.set_attribute(div, "style", "display: flex; width: 100%")
doc.append_child(root, div)

let layout = doc.update()  // Compute initial layout

// Update style
doc.set_attribute(div, "style", "display: block; width: 50%")
let new_layout = doc.update()  // Only recompute affected nodes
```

### Accessibility Tree

```moonbit
let html = "<nav><a href=\"/\">Home</a><a href=\"/about\">About</a></nav>"
let doc = @html.parse_document(html)
let tree = @aom.build_accessibility_tree(doc)

let nav = tree.find_by_role(Role::Navigation)
let snapshot = tree.to_aria_snapshot()
// - navigation:
//   - link "Home"
//   - link "About"
```

# Browser Implementation API Guide

Crater provides synchronous, pure MoonBit APIs for browser implementers. This document describes how to use Crater's public APIs to build a browser engine.

## Design Principles

- **Pure MoonBit**: No external dependencies, no FFI
- **Synchronous**: All APIs are synchronous; async operations (network, file I/O, image decoding) are handled by the caller
- **Layered API**: High-level API for simple cases, low-level API for fine-grained control

## API Layers

| Layer | Package | Purpose |
|-------|---------|---------|
| **A. High-level** | `renderer` | HTML string → Layout in one call |
| **B. DOM/Tree** | `tree` | Node manipulation, incremental updates |
| **C. Style** | `css/cascade` | CSS parsing, cascade, style application |
| **D. Parse** | `html` | HTML parsing to DOM |
| **E. Color/Paint** | `types`, `paint` | Color values, visual properties |

---

## A. High-level API (`renderer`)

For simple use cases where you have complete HTML and just need layout results.

```moonbit
// Basic usage
let ctx = @renderer.RenderContext::default()
let layout = @renderer.render(html_string, ctx)

// With custom viewport
let ctx = @renderer.RenderContext::{
  viewport_width: 1024.0,
  viewport_height: 768.0,
  root_font_size: 16.0,
}
let layout = @renderer.render(html_string, ctx)

// Get Node tree (for further manipulation)
let node = @renderer.render_to_node(html_string, ctx)
```

### Key Types

```moonbit
pub struct RenderContext {
  viewport_width : Double   // default: 800.0
  viewport_height : Double  // default: 600.0
  root_font_size : Double   // default: 16.0
}

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
```

---

## B. Tree API (`tree`)

For dynamic applications requiring DOM manipulation and incremental layout updates.

### LayoutTree - Tree Management

```moonbit
// Create from HTML document
let doc = @html.parse_document(html_string)
let tree = @tree.LayoutTree::from_html_document(doc, 800.0, 600.0)

// Or create from Node
let node = @renderer.render_to_node(html_string, ctx)
let tree = @tree.LayoutTree::from_node(node, 800.0, 600.0)

// Compute layout
let layout = tree.compute_full()

// Incremental update (uses cache for unchanged nodes)
let layout = tree.compute_incremental()
```

### Node Operations

```moonbit
// Find nodes
let node = tree.find_node_by_id("my-element")
let node = tree.find_node(uid)

// Add/remove nodes
tree.add_node("new-id", parent_uid, new_node)
tree.remove_node("node-id")

// Update styles
tree.update_node_style("node-id", cascaded_values)
tree.batch_update_styles([("id1", values1), ("id2", values2)])

// Mark dirty for re-layout
tree.mark_node_dirty(uid)

// Viewport resize
tree.resize_viewport(1024.0, 768.0)
```

### LayoutNode - Individual Node

```moonbit
// Create nodes
let node = @tree.LayoutNode::create_with_id("my-id")
let node = @tree.LayoutNode::leaf("leaf-id", style)
let node = @tree.LayoutNode::new("parent-id", style, children)

// Style setters (chainable)
let node = @tree.LayoutNode::create()
  .set_display(@style.Display::Flex)
  .set_width(200.0)
  .set_height(100.0)
  .set_flex_direction(@style.FlexDirection::Row)
  .set_padding(10.0)
  .set_margin(5.0)

// Child manipulation
node.add_child(child)
node.insert_child(child, index)
node.remove_child_at(index)
node.remove_all_children()

// Dirty tracking
node.mark_dirty()
let dirty = node.is_dirty()
let needs = node.needs_layout()

// Read computed layout
let x = node.get_layout_x()
let y = node.get_layout_y()
let w = node.get_layout_width()
let h = node.get_layout_height()
```

### Available Style Setters

**Dimensions:**
- `set_width`, `set_height`, `set_width_auto`, `set_height_auto`
- `set_width_percent`, `set_height_percent`
- `set_min_width`, `set_min_height`, `set_max_width`, `set_max_height`

**Spacing:**
- `set_margin`, `set_margin_top/right/bottom/left`
- `set_padding`, `set_padding_top/right/bottom/left`
- `set_border`

**Flexbox:**
- `set_display`, `set_flex_direction`, `set_flex_wrap`
- `set_flex_grow`, `set_flex_shrink`, `set_flex_basis`, `set_flex_basis_auto`
- `set_justify_content`, `set_align_items`, `set_align_self`, `set_align_content`
- `set_gap`, `set_row_gap`, `set_column_gap`

**Grid:**
- `set_grid_template_columns`, `set_grid_template_rows`
- `set_grid_auto_columns`, `set_grid_auto_rows`, `set_grid_auto_flow`
- `set_grid_column`, `set_grid_row`, `set_grid_area`
- `set_grid_template_areas`
- `set_justify_items`, `set_justify_self`

**Other:**
- `set_position_type`

---

## C. Style API (`css/cascade`)

For CSS parsing and cascade calculation.

### Stylesheet Management

```moonbit
// Create stylesheet
let sheet = @cascade.Stylesheet::new(@cascade.Origin::Author)

// Parse and add rules
let selector = @selector.parse("div.container > p")
let declarations = ... // parsed declarations
sheet.add_rule(".container > p", selector, declarations)

// With media query
sheet.add_rule_with_media(selector_text, selector, declarations, media_query)
```

### Style Cascade

```moonbit
// Match element against stylesheets
let element = @selector.Element::new("div", id?, classes, attributes)
let matches = sheet.match_element(element)

// Cascade multiple sources
let declarations = @cascade.collect_declarations(matches, inline_declarations)
let cascaded = @cascade.cascade(declarations)

// Or cascade for specific element
let cascaded = @cascade.cascade_element(element, stylesheets, inline_declarations)

// Read cascaded values
let value = cascaded.get_value("display")  // -> String?
let decl = cascaded.get("margin-left")     // -> Declaration?
let has = cascaded.has("flex-direction")   // -> Bool
```

### Apply to LayoutNode

```moonbit
let node = @tree.LayoutNode::create_with_id("my-node")
let changed = node.apply_css_values(cascaded_values)  // returns true if style changed
```

---

## D. Parse API (`html`)

### HTML Parsing

```moonbit
// Parse complete document (extracts stylesheets)
let doc = @html.parse_document(html_string)
// doc.root : Element
// doc.stylesheets : Array[String]       // inline <style> contents
// doc.stylesheet_links : Array[String]  // <link> href values

// Parse fragment
let element = @html.parse_fragment(html_string)

// Parse with error handling
let element = @html.parse(html_string)  // -> Element?
```

### Element Structure

```moonbit
pub struct Element {
  tag : String
  id : String?
  classes : Array[String]
  style : String?                    // inline style attribute
  attributes : Map[String, String]
  children : Array[Node]
}

pub enum Node {
  Element(Element)
  Text(String)
}

pub struct Document {
  root : Element
  stylesheets : Array[String]        // <style> contents
  stylesheet_links : Array[String]   // <link href="...">
}
```

---

## Use Cases

### 1. Initial Page Render

```moonbit
// Parse HTML
let doc = @html.parse_document(html_string)

// Load external stylesheets (caller handles async fetch)
let external_css = fetch_stylesheets(doc.stylesheet_links)

// Build layout tree
let tree = @tree.LayoutTree::from_html_document(doc, viewport_w, viewport_h)

// Apply external styles
for css in external_css {
  // parse and apply...
}

// Compute layout
let layout = tree.compute_full()

// Render to screen (caller handles drawing)
draw_layout(layout)
```

### 2. Dynamic DOM Update

```moonbit
// User interaction adds new element
let new_node = @tree.LayoutNode::create_with_id("new-item")
  .set_display(@style.Display::Block)
  .set_width(100.0)
  .set_height(50.0)

tree.add_node("new-item", parent_uid, new_node)

// Incremental re-layout (only affected nodes recomputed)
let layout = tree.compute_incremental()
```

### 3. Style Change (e.g., hover)

```moonbit
// Update style on specific node
let new_values = compute_hover_styles(element)
tree.update_node_style("button-1", new_values)

// Re-layout
let layout = tree.compute_incremental()
```

### 4. Viewport Resize

```moonbit
tree.resize_viewport(new_width, new_height)
let layout = tree.compute_incremental()
```

### 5. Measure Text (External Dependency)

Crater doesn't measure text internally. Provide a measure function:

```moonbit
let measure_func = @node.MeasureFunc::{
  func: fn(available_width, available_height) {
    // Call external text measurement (font engine, canvas, etc.)
    let size = measure_text_external(text, font, available_width)
    @node.IntrinsicSize::{
      min_width: size.width,
      max_width: size.width,
      min_height: size.height,
      max_height: size.height,
    }
  }
}

let text_node = @tree.LayoutNode::with_measure("text-1", style, measure_func)
```

---

## E. Color & Paint API (`types`, `paint`)

Crater resolves CSS colors to RGBA values at style computation time.

### Color Type

```moonbit
pub struct Color {
  r : Int      // 0-255
  g : Int      // 0-255
  b : Int      // 0-255
  a : Double   // 0.0-1.0
}

// Create colors
let red = @types.Color::rgb(255, 0, 0)
let semi_transparent = @types.Color::rgba(0, 0, 255, 0.5)
let black = @types.Color::black()
let white = @types.Color::white()
let clear = @types.Color::transparent()

// Convert to string
color.to_hex()         // "#ff0000" or "#0000ff80"
color.to_rgba_string() // "rgb(255, 0, 0)" or "rgba(0, 0, 255, 0.5)"

// Query
color.is_transparent() // alpha == 0
color.is_opaque()      // alpha == 1
```

### CSS Color Parsing

```moonbit
// Parse any CSS color value
let parsed = @computed.parse_color("red")           // named color
let parsed = @computed.parse_color("#ff0000")       // hex
let parsed = @computed.parse_color("rgb(255,0,0)")  // rgb()
let parsed = @computed.parse_color("rgba(255,0,0,0.5)") // rgba()
let parsed = @computed.parse_color("currentColor")  // inherit text color
let parsed = @computed.parse_color("transparent")   // transparent

// Result is CssColorValue enum
match parsed {
  Resolved(color) => // Use the @types.Color directly
  CurrentColor => // Resolve using parent's color
  Inherit => // Inherit from parent
}
```

### Paint Properties

Colors are available in computed styles and paint properties:

```moonbit
// From computed Style
let text_color = style.color              // @types.Color
let bg_color = style.background_color     // @types.Color

// From PaintProperties (for rendering)
let paint = @paint.PaintProperties::from_style(style)
paint.color            // text color (inherited)
paint.background_color // background (not inherited)
paint.opacity          // 0.0-1.0
paint.visibility       // Visible/Hidden/Collapse
paint.z_index          // Auto/Value(n)

// Check if visible
if paint.should_render() {
  // Element is visible and has opacity > 0
}
```

### Supported CSS Color Formats

| Format | Example | Notes |
|--------|---------|-------|
| Named colors | `red`, `blue`, `rebeccapurple` | All 148 CSS named colors |
| Hex (3-digit) | `#f00` | Expands to `#ff0000` |
| Hex (6-digit) | `#ff0000` | Standard hex |
| Hex (4-digit) | `#f00a` | With alpha |
| Hex (8-digit) | `#ff0000aa` | With alpha |
| `rgb()` | `rgb(255, 0, 0)` | Comma-separated |
| `rgba()` | `rgba(255, 0, 0, 0.5)` | With alpha |
| `transparent` | `transparent` | Fully transparent |
| `currentColor` | `currentColor` | Inherits text color |
| `inherit` | `inherit` | Inherits from parent |

---

## Cache & Performance

### Incremental Layout

```moonbit
// Track cache statistics
let stats = @tree.CacheStats::new()
let layout = tree.compute_with_stats(stats)

println("Cache hits: \{stats.cache_hits}")
println("Cache misses: \{stats.cache_misses}")
println("Hit rate: \{stats.hit_rate()}%")
```

### Dirty Tracking

```moonbit
// Check if layout needed
if tree.needs_layout() {
  let layout = tree.compute_incremental()
}

// Check individual node
if node.is_dirty() || node.get_has_new_layout() {
  // handle update
}
node.mark_layout_seen()  // clear new layout flag
```

---

## Boundaries: What Crater Does NOT Handle

The following must be implemented by the browser layer:

| Responsibility | Description |
|---------------|-------------|
| **Network** | HTTP/HTTPS, fetching resources |
| **File I/O** | Reading local files |
| **Image Decoding** | PNG, JPEG, etc. → dimensions |
| **Font Loading** | TTF/OTF parsing, glyph metrics |
| **Text Measurement** | Given font + text → width/height |
| **Event Loop** | setTimeout, requestAnimationFrame |
| **Input Events** | Mouse, keyboard, touch |
| **JavaScript** | Script execution, DOM bindings |
| **Pixel Rendering** | Drawing to canvas/screen |

Crater provides the **layout and paint data pipeline**:
```
HTML/CSS → DOM → Styles → Layout Tree → Positions/Sizes + Colors
```

**What Crater provides for rendering:**
- Position and size of each element (x, y, width, height)
- Box model metrics (margin, padding, border)
- Text color (`color`) and background color (`background_color`)
- Visual properties (opacity, visibility, z-index)
- Stacking order for paint ordering

**What the browser must implement:**
- Actual pixel rendering (GPU, canvas, etc.)
- Text rasterization with fonts
- Image rendering
- Border styles (solid, dashed, etc.) - only width is computed
- Gradients, shadows, and other complex paint effects

///|
/// JavaScript API for Crater layout engine
/// Provides browser-friendly functions for HTML rendering

///|
/// Render HTML to layout tree (text representation)
pub fn renderHtml(html : String, width : Int, height : Int) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let buf = StringBuilder::new()
  format_layout(layout, buf, 0)
  buf.to_string()
}

///|
fn format_layout(
  layout : @node.Layout,
  buf : StringBuilder,
  indent : Int,
) -> Unit {
  let mut i = 0
  while i < indent {
    buf.write_string("  ")
    i = i + 1
  }
  buf.write_string(layout.id)
  buf.write_string(" (")
  buf.write_string(layout.x.to_string())
  buf.write_string(", ")
  buf.write_string(layout.y.to_string())
  buf.write_string(") ")
  buf.write_string(layout.width.to_string())
  buf.write_string("x")
  buf.write_string(layout.height.to_string())
  buf.write_string("\n")
  for child in layout.children {
    format_layout(child, buf, indent + 1)
  }
}

///|
/// Render HTML to JSON layout tree
pub fn renderHtmlToJson(html : String, width : Int, height : Int) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  @renderer.layout_to_json(layout)
}

///|
/// Render HTML to paint node tree (JSON format with colors)
pub fn renderHtmlToPaintTree(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  let paint_tree = @paint.from_node_and_layout(node, layout)
  paint_node_to_json(paint_tree)
}

///|
fn paint_node_to_json(node : @paint.PaintNode) -> String {
  let buf = StringBuilder::new()
  write_paint_node(node, buf)
  buf.to_string()
}

///|
fn write_paint_node(node : @paint.PaintNode, buf : StringBuilder) -> Unit {
  buf.write_string("{\"id\":\"")
  buf.write_string(escape_json_string(node.id))
  buf.write_string("\",\"x\":")
  buf.write_string(node.x.to_string())
  buf.write_string(",\"y\":")
  buf.write_string(node.y.to_string())
  buf.write_string(",\"width\":")
  buf.write_string(node.width.to_string())
  buf.write_string(",\"height\":")
  buf.write_string(node.height.to_string())
  buf.write_string(",\"backgroundColor\":\"")
  buf.write_string(color_to_css(node.paint.background_color))
  buf.write_string("\",\"color\":\"")
  buf.write_string(color_to_css(node.paint.color))
  buf.write_string("\",\"opacity\":")
  buf.write_string(node.paint.opacity.to_string())
  // Text content
  match node.text {
    Some(t) => {
      buf.write_string(",\"text\":\"")
      buf.write_string(escape_json_string(t))
      buf.write_string("\"")
    }
    None => ()
  }
  // Children
  buf.write_string(",\"children\":[")
  let mut first = true
  for child in node.children {
    if not(first) {
      buf.write_string(",")
    }
    first = false
    write_paint_node(child, buf)
  }
  buf.write_string("]}")
}

///|
fn color_to_css(color : @types.Color) -> String {
  let buf = StringBuilder::new()
  buf.write_string("rgba(")
  buf.write_string(color.r.to_string())
  buf.write_string(",")
  buf.write_string(color.g.to_string())
  buf.write_string(",")
  buf.write_string(color.b.to_string())
  buf.write_string(",")
  // alpha is already 0.0-1.0, round to 2 decimal places
  let alpha = (color.a * 100.0).to_int().to_double() / 100.0
  buf.write_string(alpha.to_string())
  buf.write_string(")")
  buf.to_string()
}

///|
fn escape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Render HTML to Sixel graphics string
pub fn renderHtmlToSixel(html : String, width : Int, height : Int) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  @sixel.render_layout_with_options(layout, width, height, false)
}

///|
/// Render HTML to Sixel with actual CSS colors
pub fn renderHtmlToSixelWithStyles(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  @sixel.render_with_styles(node, layout, width, height)
}

// =============================================================================
// Incremental Layout API
// =============================================================================

///|
/// Global layout tree for incremental updates
let global_tree : Ref[@tree.LayoutTree?] = { val: None }

///|
/// Global cache stats for performance tracking
let global_stats : Ref[@tree.CacheStats?] = { val: None }

///|
/// Create a new layout tree from HTML
/// Returns tree ID (always 0 for now, single tree)
pub fn createTree(html : String, width : Int, height : Int) -> Int {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let tree = @tree.LayoutTree::from_node(
    node,
    width.to_double(),
    height.to_double(),
  )
  global_tree.val = Some(tree)
  global_stats.val = Some(@tree.CacheStats::new())
  0
}

///|
/// Compute layout incrementally (uses cache when possible)
/// Returns JSON layout tree
pub fn computeIncremental() -> String {
  match global_tree.val {
    Some(tree) => {
      let stats = match global_stats.val {
        Some(s) => s
        None => {
          let s = @tree.CacheStats::new()
          global_stats.val = Some(s)
          s
        }
      }
      let layout = tree.compute_with_stats(stats)
      @renderer.layout_to_json(layout)
    }
    None => "{\"error\":\"No tree created\"}"
  }
}

///|
/// Compute full layout (ignores cache)
/// Returns JSON layout tree
pub fn computeFull() -> String {
  match global_tree.val {
    Some(tree) => {
      let layout = tree.compute_full()
      @renderer.layout_to_json(layout)
    }
    None => "{\"error\":\"No tree created\"}"
  }
}

///|
/// Mark a node as dirty by ID
/// Returns true if node was found and marked
pub fn markDirty(node_id : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          node.mark_dirty()
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Update node style property
/// Returns true if successful
pub fn updateStyle(node_id : String, css : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          let ctx = @computed.ComputeContext::new()
          let style = @computed.compute_inline(css, ctx)
          // Apply style changes
          node.style.width = style.width
          node.style.height = style.height
          node.style.margin = style.margin
          node.style.padding = style.padding
          node.style.display = style.display
          node.style.flex_direction = style.flex_direction
          node.style.flex_grow = style.flex_grow
          node.style.flex_shrink = style.flex_shrink
          node.style.justify_content = style.justify_content
          node.style.align_items = style.align_items
          node.style.row_gap = style.row_gap
          node.style.column_gap = style.column_gap
          node.mark_dirty()
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Resize viewport
pub fn resizeViewport(width : Int, height : Int) -> Unit {
  match global_tree.val {
    Some(tree) => tree.resize_viewport(width.to_double(), height.to_double())
    None => ()
  }
}

///|
/// Get cache statistics as JSON
pub fn getCacheStats() -> String {
  match global_stats.val {
    Some(stats) => {
      let buf = StringBuilder::new()
      buf.write_string("{\"hits\":")
      buf.write_string(stats.cache_hits.to_string())
      buf.write_string(",\"misses\":")
      buf.write_string(stats.cache_misses.to_string())
      buf.write_string(",\"nodesComputed\":")
      buf.write_string(stats.nodes_computed.to_string())
      buf.write_string(",\"hitRate\":")
      buf.write_string(stats.hit_rate().to_string())
      buf.write_string("}")
      buf.to_string()
    }
    None => "{\"hits\":0,\"misses\":0,\"nodesComputed\":0,\"hitRate\":0}"
  }
}

///|
/// Reset cache statistics
pub fn resetCacheStats() -> Unit {
  global_stats.val = Some(@tree.CacheStats::new())
}

///|
/// Check if tree needs layout recomputation
pub fn needsLayout() -> Bool {
  match global_tree.val {
    Some(tree) => tree.needs_layout()
    None => false
  }
}

///|
/// Destroy the current tree
pub fn destroyTree() -> Unit {
  global_tree.val = None
  global_stats.val = None
}

// =============================================================================
// Yoga-compatible Node API
// =============================================================================

///|
/// Create a new node with optional ID
/// Returns the node's UID
pub fn createNode(id : String) -> Int {
  let node = @tree.LayoutNode::create_with_id(id)
  node.uid
}

///|
/// Add a child node to parent (appends to end)
/// Returns true if successful
pub fn addChild(parent_id : String, child_id : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match (tree.find_node_by_id(parent_id), tree.find_node_by_id(child_id)) {
        (Some(parent), Some(child)) => {
          ignore(parent.add_child(child))
          true
        }
        _ => false
      }
    None => false
  }
}

///|
/// Insert child at specific index
pub fn insertChild(parent_id : String, child_id : String, index : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match (tree.find_node_by_id(parent_id), tree.find_node_by_id(child_id)) {
        (Some(parent), Some(child)) => {
          ignore(parent.insert_child(child, index))
          true
        }
        _ => false
      }
    None => false
  }
}

///|
/// Remove child at index
pub fn removeChild(parent_id : String, index : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(parent_id) {
        Some(parent) =>
          match parent.remove_child_at(index) {
            Some(_) => true
            None => false
          }
        None => false
      }
    None => false
  }
}

///|
/// Get child count
pub fn getChildCount(node_id : String) -> Int {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => node.get_child_count()
        None => 0
      }
    None => 0
  }
}

// =============================================================================
// Yoga-compatible Style Setters
// =============================================================================

///|
/// Set width in pixels
pub fn setWidth(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_width(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set width as percentage (0-100)
pub fn setWidthPercent(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_width_percent(value / 100.0))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set width to auto
pub fn setWidthAuto(node_id : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_width_auto())
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set height in pixels
pub fn setHeight(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_height(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set height as percentage (0-100)
pub fn setHeightPercent(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_height_percent(value / 100.0))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set height to auto
pub fn setHeightAuto(node_id : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_height_auto())
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set flex grow
pub fn setFlexGrow(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_flex_grow(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set flex shrink
pub fn setFlexShrink(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_flex_shrink(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set flex basis in pixels
pub fn setFlexBasis(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_flex_basis(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set flex direction: 0=row, 1=row-reverse, 2=column, 3=column-reverse
pub fn setFlexDirection(node_id : String, value : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          let dir : @style.FlexDirection = match value {
            0 => Row
            1 => RowReverse
            2 => Column
            3 => ColumnReverse
            _ => Row
          }
          ignore(node.set_flex_direction(dir))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set flex wrap: 0=no-wrap, 1=wrap, 2=wrap-reverse
pub fn setFlexWrap(node_id : String, value : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          let wrap : @style.FlexWrap = match value {
            0 => NoWrap
            1 => Wrap
            2 => WrapReverse
            _ => NoWrap
          }
          ignore(node.set_flex_wrap(wrap))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set justify content: 0=start, 1=end, 2=center, 3=space-between, 4=space-around, 5=space-evenly
pub fn setJustifyContent(node_id : String, value : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          let align : @style.Alignment = match value {
            0 => FlexStart
            1 => FlexEnd
            2 => Center
            3 => SpaceBetween
            4 => SpaceAround
            5 => SpaceEvenly
            _ => FlexStart
          }
          ignore(node.set_justify_content(align))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set align items: 0=start, 1=end, 2=center, 3=stretch, 4=baseline
pub fn setAlignItems(node_id : String, value : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          let align : @style.Alignment = match value {
            0 => FlexStart
            1 => FlexEnd
            2 => Center
            3 => Stretch
            4 => Baseline
            _ => Stretch
          }
          ignore(node.set_align_items(align))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set display: 0=flex, 1=none, 2=block, 3=grid
pub fn setDisplay(node_id : String, value : Int) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          let display : @style.Display = match value {
            0 => Flex
            1 => None
            2 => Block
            3 => Grid
            _ => Flex
          }
          ignore(node.set_display(display))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set margin on all sides
pub fn setMargin(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_margin(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set padding on all sides
pub fn setPadding(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_padding(value))
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Set gap (row and column)
pub fn setGap(node_id : String, value : Double) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          ignore(node.set_gap(value))
          true
        }
        None => false
      }
    None => false
  }
}

// =============================================================================
// Yoga-compatible Layout Getters
// =============================================================================

///|
/// Get computed X position
pub fn getComputedLeft(node_id : String) -> Double {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => node.get_layout_x()
        None => 0.0
      }
    None => 0.0
  }
}

///|
/// Get computed Y position
pub fn getComputedTop(node_id : String) -> Double {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => node.get_layout_y()
        None => 0.0
      }
    None => 0.0
  }
}

///|
/// Get computed width
pub fn getComputedWidth(node_id : String) -> Double {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => node.get_layout_width()
        None => 0.0
      }
    None => 0.0
  }
}

///|
/// Get computed height
pub fn getComputedHeight(node_id : String) -> Double {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => node.get_layout_height()
        None => 0.0
      }
    None => 0.0
  }
}

///|
/// Check if node has new layout
pub fn hasNewLayout(node_id : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => node.get_has_new_layout()
        None => false
      }
    None => false
  }
}

///|
/// Mark layout as seen
pub fn markLayoutSeen(node_id : String) -> Bool {
  match global_tree.val {
    Some(tree) =>
      match tree.find_node_by_id(node_id) {
        Some(node) => {
          node.mark_layout_seen()
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Calculate layout (Yoga-compatible name)
pub fn calculateLayout(width : Double, height : Double) -> String {
  match global_tree.val {
    Some(tree) => {
      let layout = tree.calculate_layout(width, height)
      @renderer.layout_to_json(layout)
    }
    None => "{\"error\":\"No tree created\"}"
  }
}

// =============================================================================
// Accessibility API
// =============================================================================

///|
/// Get ARIA snapshot in YAML format (Playwright-compatible)
pub fn getAriaSnapshot(html : String) -> String {
  let doc = @html.parse_document(html)
  let tree = @aom.build_accessibility_tree(doc)
  tree.to_aria_snapshot()
}

///|
/// Get ARIA snapshot in JSON format
pub fn getAriaSnapshotJson(html : String) -> String {
  let doc = @html.parse_document(html)
  let tree = @aom.build_accessibility_tree(doc)
  tree.to_aria_json()
}

///|
/// Get full accessibility tree as JSON
pub fn getAccessibilityTree(html : String) -> String {
  let doc = @html.parse_document(html)
  let tree = @aom.build_accessibility_tree(doc)
  accessibility_tree_to_json(tree)
}

///|
fn accessibility_tree_to_json(tree : @aom.AccessibilityTree) -> String {
  let buf = StringBuilder::new()
  write_accessibility_node(tree.root, buf, 0)
  buf.to_string()
}

///|
fn write_accessibility_node(
  node : @aom.AccessibilityNode,
  buf : StringBuilder,
  indent : Int,
) -> Unit {
  write_json_indent(buf, indent)
  buf.write_string("{\n")

  // id
  write_json_indent(buf, indent + 1)
  buf.write_string("\"id\": \"")
  buf.write_string(escape_json_string(node.id))
  buf.write_string("\",\n")

  // role
  write_json_indent(buf, indent + 1)
  buf.write_string("\"role\": \"")
  buf.write_string(node.role.to_string())
  buf.write_string("\"")

  // name
  match node.name {
    Some(name) => {
      buf.write_string(",\n")
      write_json_indent(buf, indent + 1)
      buf.write_string("\"name\": \"")
      buf.write_string(escape_json_string(name))
      buf.write_string("\"")
    }
    None => ()
  }

  // description
  match node.description {
    Some(desc) => {
      buf.write_string(",\n")
      write_json_indent(buf, indent + 1)
      buf.write_string("\"description\": \"")
      buf.write_string(escape_json_string(desc))
      buf.write_string("\"")
    }
    None => ()
  }

  // level
  match node.level {
    Some(level) => {
      buf.write_string(",\n")
      write_json_indent(buf, indent + 1)
      buf.write_string("\"level\": ")
      buf.write_string(level.to_string())
    }
    None => ()
  }

  // focusable
  if node.focusable {
    buf.write_string(",\n")
    write_json_indent(buf, indent + 1)
    buf.write_string("\"focusable\": true")
  }

  // states
  if not(node.states.is_empty()) {
    buf.write_string(",\n")
    write_json_indent(buf, indent + 1)
    buf.write_string("\"states\": [")
    for i, state in node.states {
      if i > 0 {
        buf.write_string(", ")
      }
      buf.write_string("\"")
      buf.write_string(state.to_string())
      buf.write_string("\"")
    }
    buf.write_string("]")
  }

  // children
  if not(node.children.is_empty()) {
    buf.write_string(",\n")
    write_json_indent(buf, indent + 1)
    buf.write_string("\"children\": [\n")
    for i, child in node.children {
      if i > 0 {
        buf.write_string(",\n")
      }
      write_accessibility_node(child, buf, indent + 2)
    }
    buf.write_string("\n")
    write_json_indent(buf, indent + 1)
    buf.write_string("]")
  }
  buf.write_string("\n")
  write_json_indent(buf, indent)
  buf.write_string("}")
}

///|
fn write_json_indent(buf : StringBuilder, level : Int) -> Unit {
  for _ in 0..<level {
    buf.write_string("  ")
  }
}

// =============================================================================
// Flat Layout Types and Functions (for WIT layout-result)
// =============================================================================

///|
/// Flat layout node (children referenced by parent-id)
pub(all) struct FlatLayoutNode {
  id : String
  parent_id : String // empty for root
  index : Int // child index in parent
  x : Double
  y : Double
  width : Double
  height : Double
  content_x : Double
  content_y : Double
  content_width : Double
  content_height : Double
  text : String // empty if not a text node
}

///|
/// Layout result with all nodes flattened (depth-first order)
pub(all) struct FlatLayoutResult {
  nodes : Array[FlatLayoutNode]
  root_id : String
}

///|
/// Flatten a hierarchical Layout tree to FlatLayoutResult
pub fn flatten_layout(layout : @node.Layout) -> FlatLayoutResult {
  let nodes : Array[FlatLayoutNode] = []
  flatten_layout_rec(layout, "", 0, nodes)
  { nodes, root_id: layout.id }
}

///|
fn flatten_layout_rec(
  layout : @node.Layout,
  parent_id : String,
  index : Int,
  nodes : Array[FlatLayoutNode],
) -> Unit {
  // Calculate content box (after padding and border)
  let content_x = layout.x + layout.padding.left + layout.border.left
  let content_y = layout.y + layout.padding.top + layout.border.top
  let content_width = layout.width -
    layout.padding.left -
    layout.padding.right -
    layout.border.left -
    layout.border.right
  let content_height = layout.height -
    layout.padding.top -
    layout.padding.bottom -
    layout.border.top -
    layout.border.bottom
  let node : FlatLayoutNode = {
    id: layout.id,
    parent_id,
    index,
    x: layout.x,
    y: layout.y,
    width: layout.width,
    height: layout.height,
    content_x,
    content_y,
    content_width: if content_width > 0.0 {
      content_width
    } else {
      0.0
    },
    content_height: if content_height > 0.0 {
      content_height
    } else {
      0.0
    },
    text: match layout.text {
      Some(t) => t
      None => ""
    },
  }
  nodes.push(node)
  // Recursively process children
  for i, child in layout.children {
    flatten_layout_rec(child, layout.id, i, nodes)
  }
}

// =============================================================================
// Core API Functions
// =============================================================================

///|
/// Compute layout from HTML (returns structured FlatLayoutResult)
pub fn computeLayout(
  html : String,
  width : Int,
  height : Int,
) -> FlatLayoutResult {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  flatten_layout(layout)
}

///|
/// Compute layout from HTML (returns JSON string)
pub fn computeLayoutJson(html : String, width : Int, height : Int) -> String {
  renderHtmlToJson(html, width, height)
}

// =============================================================================
// Incremental API - Structured return versions
// =============================================================================

///|
/// Compute layout incrementally (returns structured FlatLayoutResult)
pub fn computeStructured() -> FlatLayoutResult {
  match global_tree.val {
    Some(tree) => {
      let stats = match global_stats.val {
        Some(s) => s
        None => {
          let s = @tree.CacheStats::new()
          global_stats.val = Some(s)
          s
        }
      }
      let layout = tree.compute_with_stats(stats)
      flatten_layout(layout)
    }
    None => { nodes: [], root_id: "" }
  }
}

///|
/// Compute full layout (returns structured FlatLayoutResult)
pub fn computeFullStructured() -> FlatLayoutResult {
  match global_tree.val {
    Some(tree) => {
      let layout = tree.compute_full()
      flatten_layout(layout)
    }
    None => { nodes: [], root_id: "" }
  }
}

// =============================================================================
// Yoga API - Structured return version
// =============================================================================

///|
/// Calculate layout (returns structured FlatLayoutResult)
pub fn calculateLayoutStructured(
  width : Double,
  height : Double,
) -> FlatLayoutResult {
  match global_tree.val {
    Some(tree) => {
      let layout = tree.calculate_layout(width, height)
      flatten_layout(layout)
    }
    None => { nodes: [], root_id: "" }
  }
}

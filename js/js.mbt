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

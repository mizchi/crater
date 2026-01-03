///|
/// TUI Layout Example
/// Shows how to use crater for terminal UI layout like ink

// =============================================================================
// ANSI Escape Codes
// =============================================================================

///|
let esc : String = "\u001b"

///|
fn cursor_to(x : Int, y : Int) -> String {
  "\{esc}[\{y + 1};\{x + 1}H"
}

///|
fn clear_screen() -> String {
  "\{esc}[2J\{esc}[H"
}

///|
fn reset_style() -> String {
  "\{esc}[0m"
}

///|
pub fn set_fg(color : Int) -> String {
  "\{esc}[38;5;\{color}m"
}

///|
pub fn set_bg(color : Int) -> String {
  "\{esc}[48;5;\{color}m"
}

///|
pub fn bold() -> String {
  "\{esc}[1m"
}

// =============================================================================
// Screen Buffer
// =============================================================================

///|
pub struct ScreenBuffer {
  width : Int
  height : Int
  cells : Array[Array[String]]
}

///|
pub fn ScreenBuffer::new(width : Int, height : Int) -> ScreenBuffer {
  let cells = Array::makei(height, fn(_) { Array::make(width, " ") })
  { width, height, cells }
}

///|
pub fn ScreenBuffer::set(
  self : ScreenBuffer,
  x : Int,
  y : Int,
  ch : String,
) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.cells[y][x] = ch
  }
}

///|
pub fn ScreenBuffer::write_text(
  self : ScreenBuffer,
  x : Int,
  y : Int,
  text : String,
) -> Unit {
  let mut cx = x
  for ch in text {
    if cx < self.width {
      self.set(cx, y, ch.to_string())
      cx += 1
    }
  }
}

///|
pub fn ScreenBuffer::draw_box(
  self : ScreenBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Unit {
  if w < 2 || h < 2 {
    return
  }
  // Corners
  self.set(x, y, "┌")
  self.set(x + w - 1, y, "┐")
  self.set(x, y + h - 1, "└")
  self.set(x + w - 1, y + h - 1, "┘")
  // Horizontal lines
  for i = x + 1; i < x + w - 1; i = i + 1 {
    self.set(i, y, "─")
    self.set(i, y + h - 1, "─")
  }
  // Vertical lines
  for j = y + 1; j < y + h - 1; j = j + 1 {
    self.set(x, j, "│")
    self.set(x + w - 1, j, "│")
  }
}

///|
pub fn ScreenBuffer::fill_rect(
  self : ScreenBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  ch : String,
) -> Unit {
  for j = y; j < y + h; j = j + 1 {
    for i = x; i < x + w; i = i + 1 {
      self.set(i, j, ch)
    }
  }
}

///|
pub fn ScreenBuffer::render(self : ScreenBuffer) -> String {
  let mut output = clear_screen()
  for y, row in self.cells {
    output += cursor_to(0, y)
    for cell in row {
      output += cell
    }
  }
  output += reset_style()
  output
}

// =============================================================================
// TUI Box Component
// =============================================================================

///|
pub(all) struct BoxStyle {
  border : Bool
  bg_color : Int?
  fg_color : Int?
  title : String?
}

///|
pub fn BoxStyle::default() -> BoxStyle {
  { border: true, bg_color: None, fg_color: None, title: None }
}

///|
pub fn BoxStyle::with_title(title : String) -> BoxStyle {
  { border: true, bg_color: None, fg_color: None, title: Some(title) }
}

// =============================================================================
// TUI Renderer
// =============================================================================

///|
pub struct TuiApp {
  tree : @tree.LayoutTree
  root : @tree.LayoutNode
  box_styles : Map[String, BoxStyle]
  contents : Map[String, String]
}

///|
pub fn TuiApp::new(
  root : @tree.LayoutNode,
  width : Double,
  height : Double,
) -> TuiApp {
  let tree = @tree.LayoutTree::new(root, width, height)
  { tree, root, box_styles: {}, contents: {} }
}

///|
pub fn TuiApp::set_box_style(
  self : TuiApp,
  id : String,
  style : BoxStyle,
) -> Unit {
  self.box_styles[id] = style
}

///|
pub fn TuiApp::set_content(
  self : TuiApp,
  id : String,
  content : String,
) -> Unit {
  self.contents[id] = content
}

///|
pub fn TuiApp::calculate(self : TuiApp) -> Unit {
  let _ = self.tree.calculate_layout(
    self.tree.viewport_width,
    self.tree.viewport_height,
  )

}

///|
pub fn TuiApp::resize(self : TuiApp, width : Double, height : Double) -> Unit {
  let _ = self.root.set_width(width).set_height(height)
  self.tree.mark_node_dirty(self.root.uid)
  self.tree.resize_viewport(width, height)
}

///|
fn render_node(
  buf : ScreenBuffer,
  node : @tree.LayoutNode,
  offset_x : Int,
  offset_y : Int,
  box_styles : Map[String, BoxStyle],
  contents : Map[String, String],
) -> Unit {
  let x = node.get_layout_x().to_int() + offset_x
  let y = node.get_layout_y().to_int() + offset_y
  let w = node.get_layout_width().to_int()
  let h = node.get_layout_height().to_int()
  // Get style for this node
  let style = box_styles.get(node.id).unwrap_or(BoxStyle::default())
  // Draw border if enabled
  if style.border && w >= 2 && h >= 2 {
    buf.draw_box(x, y, w, h)
    // Draw title if present
    match style.title {
      Some(title) =>
        if title.length() + 2 < w {
          buf.write_text(x + 1, y, " \{title} ")
        }
      None => ()
    }
  }
  // Draw content if present
  match contents.get(node.id) {
    Some(text) => {
      let content_x = if style.border { x + 1 } else { x }
      let content_y = if style.border { y + 1 } else { y }
      buf.write_text(content_x, content_y, text)
    }
    None => ()
  }
  // Render children with offset
  for child in node.children {
    render_node(buf, child, x, y, box_styles, contents)
  }
}

///|
pub fn TuiApp::render(self : TuiApp) -> String {
  let w = self.tree.viewport_width.to_int()
  let h = self.tree.viewport_height.to_int()
  let buf = ScreenBuffer::new(w, h)
  render_node(buf, self.root, 0, 0, self.box_styles, self.contents)
  buf.render()
}

///|
/// Example: Create a typical TUI layout with header, sidebar, main, footer
pub fn create_tui_layout(
  term_width : Double,
  term_height : Double,
) -> @tree.LayoutNode {
  // Header - full width, fixed height
  let header = @tree.LayoutNode::create_with_id("header")
  let _ = header.set_width_percent(1.0).set_height(3.0)

  // Sidebar - fixed width
  let sidebar = @tree.LayoutNode::create_with_id("sidebar")
  let _ = sidebar.set_width(20.0).set_height_percent(1.0)

  // Main content - flex grow to fill remaining space
  let main = @tree.LayoutNode::create_with_id("main")
  let _ = main.set_flex_grow(1.0).set_height_percent(1.0)

  // Body container (sidebar + main)
  let body = @tree.LayoutNode::create_with_id("body")
  let _ = body
    .set_display(@style.Flex)
    .set_flex_direction(@style.Row)
    .set_flex_grow(1.0)
    .set_width_percent(1.0)
  let _ = body.add_child(sidebar).add_child(main)

  // Footer - full width, fixed height
  let footer = @tree.LayoutNode::create_with_id("footer")
  let _ = footer.set_width_percent(1.0).set_height(1.0)

  // Root container
  let root = @tree.LayoutNode::create_with_id("root")
  let _ = root
    .set_display(@style.Flex)
    .set_flex_direction(@style.Column)
    .set_width(term_width)
    .set_height(term_height)
  let _ = root.add_child(header).add_child(body).add_child(footer)
  root
}

///|
/// Example: Grid-based panel layout
pub fn create_grid_layout(
  term_width : Double,
  term_height : Double,
) -> @tree.LayoutNode {
  let root = @tree.LayoutNode::create_with_id("root")
  let _ = root
    .set_display(@style.Grid)
    .set_width(term_width)
    .set_height(term_height)
    .set_grid_template_columns([
        @style.Fr(1.0), // Left panel
        @style.Fr(2.0), // Center panel (wider)
        @style.Fr(1.0),
      ], // Right panel
    )
    .set_grid_template_rows([
      @style.Length(3.0), // Header
      @style.Fr(1.0), // Content
      @style.Length(1.0), // Footer
    ])
    .set_gap(1.0)

  // Header spans full width
  let header = @tree.LayoutNode::create_with_id("header")
  let _ = header.set_grid_column(@style.Line(1), @style.Line(4))

  // Three panels in the middle row
  let left = @tree.LayoutNode::create_with_id("left")
  let center = @tree.LayoutNode::create_with_id("center")
  let right = @tree.LayoutNode::create_with_id("right")

  // Footer spans full width
  let footer = @tree.LayoutNode::create_with_id("footer")
  let _ = footer.set_grid_column(@style.Line(1), @style.Line(4))
  let _ = root
    .add_child(header)
    .add_child(left)
    .add_child(center)
    .add_child(right)
    .add_child(footer)
  root
}

///|
test "tui_layout/basic" {
  @dispatch.setup()
  let root = create_tui_layout(80.0, 24.0)
  let tree = @tree.LayoutTree::new(root, 80.0, 24.0)
  let _ = tree.calculate_layout(80.0, 24.0)

  // Check header
  match tree.find_node_by_id("header") {
    Some(h) => {
      inspect(h.get_layout_x(), content="0")
      inspect(h.get_layout_y(), content="0")
      inspect(h.get_layout_width(), content="80")
      inspect(h.get_layout_height(), content="3")
    }
    None => panic()
  }

  // Check sidebar
  match tree.find_node_by_id("sidebar") {
    Some(s) => {
      inspect(s.get_layout_x(), content="0")
      inspect(s.get_layout_y(), content="0") // Relative to body
      inspect(s.get_layout_width(), content="20")
    }
    None => panic()
  }

  // Check footer
  match tree.find_node_by_id("footer") {
    Some(f) => {
      inspect(f.get_layout_width(), content="80")
      inspect(f.get_layout_height(), content="1")
    }
    None => panic()
  }
}

///|
test "tui_layout/resize" {
  @dispatch.setup()
  let root = create_tui_layout(80.0, 24.0)
  let tree = @tree.LayoutTree::new(root, 80.0, 24.0)

  // Initial layout
  let _ = tree.calculate_layout(80.0, 24.0)
  match tree.find_node_by_id("main") {
    Some(m) => inspect(m.get_layout_width(), content="60") // 80 - 20 (sidebar)
    None => panic()
  }

  // Resize terminal - need to update root size and mark dirty
  let _ = root.set_width(120.0).set_height(30.0)
  tree.mark_node_dirty(root.uid)
  let _ = tree.calculate_layout(120.0, 30.0)
  match tree.find_node_by_id("main") {
    Some(m) => inspect(m.get_layout_width(), content="100") // 120 - 20 (sidebar)
    None => panic()
  }
}

///|
fn main {
  @dispatch.setup()

  // Create layout
  let root = create_tui_layout(80.0, 24.0)
  let app = TuiApp::new(root, 80.0, 24.0)

  // Set box styles with titles
  app.set_box_style("header", BoxStyle::with_title("Header"))
  app.set_box_style("sidebar", BoxStyle::with_title("Menu"))
  app.set_box_style("main", BoxStyle::with_title("Content"))
  app.set_box_style("footer", {
    border: false,
    bg_color: None,
    fg_color: None,
    title: None,
  })
  app.set_box_style("body", {
    border: false,
    bg_color: None,
    fg_color: None,
    title: None,
  })
  app.set_box_style("root", {
    border: false,
    bg_color: None,
    fg_color: None,
    title: None,
  })

  // Set content
  app.set_content("header", "Welcome to Crater TUI!")
  app.set_content("sidebar", "1. Home")
  app.set_content("main", "Main content area")
  app.set_content("footer", " Press 'q' to quit | Arrow keys to navigate")

  // Calculate layout and render
  app.calculate()
  println(app.render())
}

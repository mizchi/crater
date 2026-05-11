///|
/// Public TUI render entrypoints and output result types.

///|
/// Render result containing ANSI string and link regions.
pub(all) struct RenderResult {
  ansi : String
  link_regions : Array[LinkRegion]
  hit_regions : Array[HitRegion]
}

///|
/// Region where an image should be rendered via graphics protocol.
pub(all) struct ImageRegion {
  col : Int // Start column in character grid
  row : Int // Start row in character grid
  width : Int // Width in characters
  height : Int // Height in characters
  pixel_width : Double // Original pixel width
  pixel_height : Double // Original pixel height
  src : String // Image source URL
  source_id : String // Source element id for stable placement reuse
}

///|
/// Render result with raw buffer for diff rendering.
pub(all) struct BufferRenderResult {
  buffer : CharBuffer
  link_regions : Array[LinkRegion]
  hit_regions : Array[HitRegion]
  scrollable_elements : Array[@tui_paint_runtime.ScrollableElement]
  image_regions : Array[ImageRegion]
}

///|
fn prepare_viewport_paint(
  node : @node.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
) -> @tui_paint_runtime.PreparedPaint? {
  @tui_paint_runtime.prepare_viewport_paint(
    node, layout, viewport_top, viewport_bottom, 0.0,
  )
}

///|
/// Render a Node + Layout tree to ANSI string.
pub fn render_to_ansi(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  focused_element_name? : String? = None,
) -> RenderResult {
  let result = render_to_buffer(
    node,
    layout,
    width,
    height,
    scroll_y,
    focused_element_name~,
  )
  {
    ansi: buffer_to_ansi(result.buffer),
    link_regions: result.link_regions,
    hit_regions: result.hit_regions,
  }
}

///|
/// Render a Node + Layout tree to a CharBuffer.
pub fn render_to_buffer(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  focused_element_name? : String? = None,
) -> BufferRenderResult {
  let buf = CharBuffer::new(width, height)
  let white_cell : CharCell = {
    char: ' ',
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, 0, width, height, white_cell)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + height).to_double() * font_height
  let prepared = match
    prepare_viewport_paint(node, layout, viewport_top, viewport_bottom) {
    Some(p) => p
    None =>
      return {
        buffer: buf,
        link_regions: [],
        hit_regions: [],
        scrollable_elements: [],
        image_regions: [],
      }
  }
  let link_regions : Array[LinkRegion] = []
  let hit_regions : Array[HitRegion] = []
  let image_regions : Array[ImageRegion] = []
  let scrollable_elements = prepared.scrollable_elements
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: height,
    link_regions,
    hit_regions,
    image_regions,
    focused_element_name,
    dark_mode: false,
    element_scroll_positions: {},
  }
  render_paint_node(ctx, prepared.tree, 0.0, 0.0, false)
  { buffer: buf, link_regions, hit_regions, scrollable_elements, image_regions }
}

///|
/// Render a Node + Layout tree with status bar at top.
pub fn render_to_ansi_with_status(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_element_name? : String? = None,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
) -> RenderResult {
  let result = render_to_buffer_with_status(
    node,
    layout,
    width,
    height,
    scroll_y,
    url,
    link_count,
    focused_link,
    focused_element_name~,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
  {
    ansi: buffer_to_ansi(result.buffer),
    link_regions: result.link_regions,
    hit_regions: result.hit_regions,
  }
}

///|
/// Render a Node + Layout tree with status bar to a CharBuffer.
pub fn render_to_buffer_with_status(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_element_name? : String? = None,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
  total_content_height? : Int = 0,
  show_scrollbar? : Bool = false,
  element_scroll_positions? : Map[String, ElementScrollPos] = {},
) -> BufferRenderResult {
  let content_height = height - 1
  let content_start_row = 1
  let buf = CharBuffer::new(width, height)
  let (content_fg, content_bg) = if dark_mode {
    (@types.Color::rgb(220, 220, 220), @types.Color::rgb(30, 30, 30))
  } else {
    (@types.Color::black(), @types.Color::white())
  }
  let bg_cell : CharCell = {
    char: ' ',
    fg: content_fg,
    bg: content_bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, content_start_row, width, content_height, bg_cell)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + content_height).to_double() * font_height
  let prepared = match
    prepare_viewport_paint(node, layout, viewport_top, viewport_bottom) {
    Some(p) => p
    None => {
      draw_status_bar(
        buf,
        0,
        url,
        link_count,
        focused_link,
        focused_link_url~,
        selection_mode~,
        dark_mode~,
      )
      return {
        buffer: buf,
        link_regions: [],
        hit_regions: [],
        scrollable_elements: [],
        image_regions: [],
      }
    }
  }
  let scrollable_elements = prepared.scrollable_elements
  let link_regions : Array[LinkRegion] = []
  let hit_regions : Array[HitRegion] = []
  let image_regions : Array[ImageRegion] = []
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
    link_regions,
    hit_regions,
    image_regions,
    focused_element_name,
    dark_mode,
    element_scroll_positions,
  }
  render_paint_node(
    ctx,
    prepared.tree,
    0.0,
    content_start_row.to_double() * font_height,
    false,
  )
  draw_status_bar(
    buf,
    0,
    url,
    link_count,
    focused_link,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
  if show_scrollbar && total_content_height > content_height * 16 {
    let content_height_chars = total_content_height / 16
    draw_scrollbar(
      buf,
      width - 1,
      content_start_row,
      content_height,
      scroll_y,
      content_height_chars,
      content_height,
    )
  }
  { buffer: buf, link_regions, hit_regions, scrollable_elements, image_regions }
}

///|
/// Get total content height in character rows.
pub fn get_content_height_chars(layout : @types.Layout) -> Int {
  px_to_row(layout.height)
}

///|
/// Render with hints overlay.
pub fn render_to_ansi_with_hints(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  hints : Array[HintData],
  hint_input : String,
  focused_element_name? : String? = None,
) -> RenderResult {
  let result = render_to_buffer_with_hints(
    node,
    layout,
    width,
    height,
    scroll_y,
    hints,
    hint_input,
    focused_element_name~,
  )
  {
    ansi: buffer_to_ansi(result.buffer),
    link_regions: result.link_regions,
    hit_regions: result.hit_regions,
  }
}

///|
/// Render with hints overlay to a CharBuffer.
pub fn render_to_buffer_with_hints(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  hints : Array[HintData],
  hint_input : String,
  focused_element_name? : String? = None,
) -> BufferRenderResult {
  let content_height = height - 1
  let buf = CharBuffer::new(width, height)
  let white_cell : CharCell = {
    char: ' ',
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, 0, width, content_height, white_cell)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + content_height).to_double() * font_height
  let prepared = match
    prepare_viewport_paint(node, layout, viewport_top, viewport_bottom) {
    Some(p) => p
    None => {
      draw_hints(buf, hints, content_height)
      draw_hint_mode_status_bar(buf, content_height, hint_input, hints)
      return {
        buffer: buf,
        link_regions: [],
        hit_regions: [],
        scrollable_elements: [],
        image_regions: [],
      }
    }
  }
  let scrollable_elements = prepared.scrollable_elements
  let link_regions : Array[LinkRegion] = []
  let hit_regions : Array[HitRegion] = []
  let image_regions : Array[ImageRegion] = []
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
    link_regions,
    hit_regions,
    image_regions,
    focused_element_name,
    dark_mode: false,
    element_scroll_positions: {},
  }
  render_paint_node(ctx, prepared.tree, 0.0, 0.0, false)
  draw_hints(buf, hints, content_height)
  draw_hint_mode_status_bar(buf, content_height, hint_input, hints)
  { buffer: buf, link_regions, hit_regions, scrollable_elements, image_regions }
}

///|
/// Calculate content extent from layout tree (max y + height of descendants).
pub fn get_content_extent(layout : @types.Layout) -> Double {
  let mut max_extent = layout.y + layout.height
  for child in layout.children {
    let child_extent = get_content_extent(child)
    if child_extent > max_extent {
      max_extent = child_extent
    }
  }
  max_extent
}

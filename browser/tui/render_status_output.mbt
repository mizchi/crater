///|
/// TUI render entrypoints that draw the browser status bar.

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

///|
/// TUI render entrypoints that draw hint overlays.

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

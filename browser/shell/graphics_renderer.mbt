///|
/// Render current content to Sixel
fn Browser::render(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  let installed_provider = self.install_sixel_image_provider()
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  let (node, layout) = self.render_graphics_node_and_layout(ctx, false)
  let output = @sixel.render_with_styles_scrolled(
    node,
    layout,
    self.viewport_width,
    self.viewport_height,
    self.scroll_y,
  )
  if installed_provider {
    @raster.clear_image_provider()
  }
  output
}

///|
/// Render current content to Kitty graphics protocol
fn Browser::render_kitty(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  let (node, layout) = self.render_graphics_node_and_layout(ctx, false)
  let paint_node = @tui_paint_plain.from_node_and_layout(node, layout)
  let base = @painter_terminal.render_paint_node_to_kitty_scrolled(
    paint_node,
    self.viewport_width,
    self.viewport_height,
    self.scroll_y,
  )
  self.collect_graphics_image_regions_from_node_layout(node, layout)
  let overlay = self.build_kitty_image_overlay()
  if overlay.length() > 0 {
    base + overlay
  } else {
    base
  }
}

///|
async fn[T : @io.Writer] Browser::write_kitty_output(
  self : Browser,
  writer : T,
) -> Unit {
  if self.html_content.length() == 0 {
    return
  }
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  let (node, layout) = self.render_graphics_node_and_layout(ctx, false)
  let paint_node = @tui_paint_plain.from_node_and_layout(node, layout)
  @painter_terminal.write_paint_node_to_kitty_scrolled(
    writer,
    paint_node,
    self.viewport_width,
    self.viewport_height,
    self.scroll_y,
  )
  self.collect_graphics_image_regions_from_node_layout(node, layout)
  let overlay = self.build_kitty_image_overlay()
  if overlay.length() > 0 {
    writer.write(overlay) catch {
      _ => ()
    }
  }
}

///|
fn Browser::collect_graphics_image_regions_from_node_layout(
  self : Browser,
  render_node : @layout.Node,
  layout : @types.Layout,
) -> Unit {
  let char_width = self.viewport_width / 8
  let char_height = self.viewport_height / 16
  let char_scroll_y = self.scroll_y / 16
  let focused_element_name = self.get_focused_element_name()
  let buffer_result = @tui.render_to_buffer(
    render_node,
    layout,
    char_width,
    char_height,
    char_scroll_y,
    focused_element_name~,
  )
  self.image_regions = buffer_result.image_regions
}

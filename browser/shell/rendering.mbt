///|
fn Browser::set_external_css(
  self : Browser,
  external_css : Array[String],
) -> Unit {
  self.external_css = external_css
  self.prepared_external_css = Some(
    @renderer.prepare_external_css(external_css),
  )
  self.prepared_render_document = None
}

///|
fn Browser::external_css_handle(
  self : Browser,
) -> @renderer.PreparedExternalCss {
  match self.prepared_external_css {
    Some(prepared) => prepared
    None => {
      let prepared = @renderer.prepare_external_css(self.external_css)
      self.prepared_external_css = Some(prepared)
      prepared
    }
  }
}

///|
fn Browser::clear_render_cache(self : Browser) -> Unit {
  self.render_node = None
  self.layout_tree = None
  self.graphics_render_node = None
  self.graphics_layout = None
  self.prev_buffer = None
  self.last_render_key = ""
  self.prepared_render_document = None
}

///|
fn Browser::prepare_render_document_for_context(
  self : Browser,
  doc : @html.Document,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> @renderer.PreparedRenderDocument {
  match self.prepared_render_document {
    Some(prepared) if self.prepared_render_document_dark == dark => prepared
    _ => {
      let prepared = @renderer.prepare_render_document_with_prepared_external_css(
        doc,
        ctx,
        self.external_css_handle(),
      )
      self.prepared_render_document = Some(prepared)
      self.prepared_render_document_dark = dark
      prepared
    }
  }
}

///|
fn Browser::render_node_from_document(
  self : Browser,
  doc : @html.Document,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> @layout.Node {
  let prepared = self.prepare_render_document_for_context(doc, ctx, dark)
  @renderer.build_render_root_node(doc, ctx, prepared)
}

///|
fn Browser::render_node_and_layout_from_document(
  self : Browser,
  doc : @html.Document,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> (@layout.Node, @types.Layout) {
  let prepared = self.prepare_render_document_for_context(doc, ctx, dark)
  let node = @renderer.build_render_root_node(doc, ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(node, prepared, ctx)
  (node, layout)
}

///|
fn Browser::render_graphics_node_and_layout(
  self : Browser,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> (@layout.Node, @types.Layout) {
  match (self.graphics_render_node, self.graphics_layout) {
    (Some(node), Some(layout)) if self.graphics_render_dark == dark =>
      (node, layout)
    _ => {
      let (node, layout) = match self.parsed_doc {
        Some(doc) => self.render_node_and_layout_from_document(doc, ctx, dark)
        None =>
          @renderer.render_to_node_and_layout_with_external_css(
            self.html_content,
            ctx,
            self.external_css,
          )
      }
      self.graphics_render_node = Some(node)
      self.graphics_layout = Some(layout)
      self.graphics_render_dark = dark
      (node, layout)
    }
  }
}

///|
fn Browser::refresh_links_from_render_source(self : Browser) -> Unit {
  self.links = extract_links(self.html_content)
}

///|
/// Render current content in selected output mode
pub fn Browser::render_output(self : Browser, mode : OutputMode) -> String {
  self.ensure_declarative_shadow_dom_normalized()
  match mode {
    Sixel => self.render()
    Kitty => self.render_kitty()
    Text => self.render_text()
    Json => self.render_json()
    Aom => self.render_aom()
    Arc90 => self.render_arc90()
    ExtractMain => self.render_extract_main()
    Grounding => self.render_grounding()
  }
}

///|
pub async fn[T : @io.Writer] Browser::write_output(
  self : Browser,
  mode : OutputMode,
  writer : T,
) -> Unit {
  match mode {
    Kitty => self.write_kitty_output(writer)
    _ => writer.write(self.render_output(mode)) catch { _ => () }
  }
}

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
    @image.clear_image_provider()
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
/// Render current content to ANSI text (TUI mode)
fn Browser::render_text(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  let rt0 = perf_now()
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    self.dark_mode,
  )
  if self.last_color_scheme_dark != self.dark_mode {
    self.clear_render_cache()
  }
  let mut force_full = false
  // Build or reuse cached render node + layout tree
  let render_node = match (self.render_node, self.layout_tree) {
    (Some(node), Some(_tree)) => node
    _ => {
      force_full = true
      let rn0 = perf_now()
      let n = match self.parsed_doc {
        Some(doc) => self.render_node_from_document(doc, ctx, self.dark_mode)
        None =>
          @renderer.render_to_node_with_external_css(
            self.html_content,
            ctx,
            self.external_css,
          )
      }
      let rn1 = perf_now()
      let tree = @layout.LayoutTree::from_node(
        n,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      let rn2 = perf_now()
      perf_log(
        "[perf:build] css_cascade+node=\{(rn1 - rn0).to_int()}ms layout_tree_init=\{(rn2 - rn1).to_int()}ms",
      )
      self.render_node = Some(n)
      self.layout_tree = Some(tree)
      n
    }
  }
  let rt1 = perf_now()
  let (layout, dirty_rects) = match self.layout_tree {
    Some(tree) => {
      let l = tree.compute_incremental()
      let rects = tree.collect_dirty_rects()
      tree.mark_all_layouts_seen()
      self.layout_tree = Some(tree)
      (l, rects)
    }
    None => {
      force_full = true
      let tree = @layout.LayoutTree::from_node(
        render_node,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      let l = tree.compute_incremental()
      let rects = tree.collect_dirty_rects()
      tree.mark_all_layouts_seen()
      self.layout_tree = Some(tree)
      (l, rects)
    }
  }
  let rt2 = perf_now()
  // Update content_height from layout result (avoids duplicate layout pass)
  if self.content_height == 0 {
    self.content_height = @tui.get_content_extent(layout).to_int()
  }
  // Convert pixel dimensions to character dimensions
  // Buffer width = viewport / 8 (wider than terminal for proper CSS layout)
  // Output is clipped to terminal_cols at ANSI rendering stage
  let char_width = self.viewport_width / 8
  let char_height = self.viewport_height / 16
  let char_scroll_y = self.scroll_y / 16
  // Get focused element name for :focus styling
  let focused_element_name = self.get_focused_element_name()
  // Get focused link URL for status bar
  let focused_link_url = self.get_focused_link_url()
  let render_key = self.current_url +
    "|" +
    self.scroll_y.to_string() +
    "|" +
    self.focused_link.to_string() +
    "|" +
    focused_element_name.unwrap_or("") +
    "|" +
    focused_link_url.unwrap_or("") +
    "|" +
    self.hint_mode.to_string() +
    "|" +
    self.hint_input +
    "|" +
    self.selection_mode.to_string() +
    "|" +
    self.dark_mode.to_string() +
    "|" +
    self.viewport_width.to_string() +
    "|" +
    self.viewport_height.to_string()
  if render_key != self.last_render_key {
    force_full = true
  }
  // Use hint mode rendering if in hint mode
  let buffer_result = if self.hint_mode {
    @tui.render_to_buffer_with_hints(
      render_node,
      layout,
      char_width,
      char_height,
      char_scroll_y,
      self.hints,
      self.hint_input,
      focused_element_name~,
    )
  } else {
    @tui.render_to_buffer_with_status(
      render_node,
      layout,
      char_width,
      char_height,
      char_scroll_y,
      self.current_url,
      self.get_visible_focusable_count(),
      self.get_visible_focus_index(),
      focused_element_name~,
      focused_link_url~,
      selection_mode=self.selection_mode,
      dark_mode=self.dark_mode,
      total_content_height=self.content_height,
      show_scrollbar=true,
      element_scroll_positions=self.get_element_scroll_positions(),
    )
  }
  let rt3 = perf_now()
  // Store link regions for click hit testing
  self.link_regions = buffer_result.link_regions
  self.hit_regions = buffer_result.hit_regions
  self.image_regions = buffer_result.image_regions
  // Initialize scroll states for scrollable elements
  self.init_scrollable_elements(buffer_result.scrollable_elements)
  let plain_links = self.build_plain_links(buffer_result.link_regions)
  // Choose buffer-to-output based on no_color mode
  // Clip output to terminal_cols (buffer may be wider than terminal)
  let max_cols = self.terminal_cols
  let ansi = match self.prev_buffer {
    Some(prev) =>
      if force_full {
        if self.no_color {
          @tui.clear_screen() +
          @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
        } else {
          @tui.clear_screen() +
          @tui.buffer_to_ansi(buffer_result.buffer, max_cols~)
        }
      } else if dirty_rects.length() > 0 && !self.no_color {
        // Diff rendering only for color mode (plain mode always does full redraw)
        let content_height = if self.hint_mode {
          char_height - 1
        } else {
          char_height - 1
        }
        let row_offset = if self.hint_mode { 0 } else { 1 }
        let dirty_cells = @tui.dirty_rects_to_cells(
          dirty_rects,
          self.scroll_y,
          char_width,
          content_height,
          row_offset,
        )
        @tui.buffer_diff_to_ansi_rects(
          buffer_result.buffer,
          prev,
          dirty_cells,
          max_cols~,
        )
      } else if self.no_color {
        @tui.clear_screen() +
        @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
      } else {
        ""
      }
    None =>
      if self.no_color {
        @tui.clear_screen() +
        @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
      } else {
        @tui.clear_screen() +
        @tui.buffer_to_ansi(buffer_result.buffer, max_cols~)
      }
  }
  // Append kitty graphics commands for image regions
  let kitty_overlay = self.build_kitty_image_overlay()
  let final_output = if kitty_overlay.length() > 0 {
    ansi + kitty_overlay
  } else {
    ansi
  }
  let rt4 = perf_now()
  self.prev_buffer = Some(buffer_result.buffer)
  self.last_render_key = render_key
  self.last_color_scheme_dark = self.dark_mode
  perf_log(
    "[perf:render] node+layout_build=\{(rt1 - rt0).to_int()}ms layout_compute=\{(rt2 - rt1).to_int()}ms tui_buffer=\{(rt3 - rt2).to_int()}ms ansi=\{(rt4 - rt3).to_int()}ms total=\{(rt4 - rt0).to_int()}ms",
  )
  final_output
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

///|
fn Browser::build_plain_links(
  self : Browser,
  link_regions : Array[@tui.LinkRegion],
) -> Array[@tui.PlainLink] {
  let plain_links : Array[@tui.PlainLink] = []
  if !self.no_color {
    return plain_links
  }
  for region in link_regions {
    match self.get_link_href_for_region(region) {
      Some(href) => {
        let url = resolve_url(self.current_url, href)
        if url.length() > 0 {
          plain_links.push({
            col: region.col,
            row: region.row,
            width: region.width,
            url,
          })
        }
      }
      None => ()
    }
  }
  plain_links
}

///|
pub fn Browser::render_text_full_page(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    self.dark_mode,
  )
  if self.last_color_scheme_dark != self.dark_mode {
    self.clear_render_cache()
  }
  let render_node = match (self.render_node, self.layout_tree) {
    (Some(node), Some(_tree)) => node
    _ => {
      let n = match self.parsed_doc {
        Some(doc) => self.render_node_from_document(doc, ctx, self.dark_mode)
        None =>
          @renderer.render_to_node_with_external_css(
            self.html_content,
            ctx,
            self.external_css,
          )
      }
      let tree = @layout.LayoutTree::from_node(
        n,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      self.render_node = Some(n)
      self.layout_tree = Some(tree)
      n
    }
  }
  let layout = match self.layout_tree {
    Some(tree) => {
      let l = tree.compute_incremental()
      tree.mark_all_layouts_seen()
      self.layout_tree = Some(tree)
      l
    }
    None => {
      let tree = @layout.LayoutTree::from_node(
        render_node,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      let l = tree.compute_incremental()
      tree.mark_all_layouts_seen()
      self.layout_tree = Some(tree)
      l
    }
  }
  if self.content_height == 0 {
    self.content_height = @tui.get_content_extent(layout).to_int()
  }
  let char_width = self.viewport_width / 8
  let content_height = @tui.get_content_height_chars(layout).max(1)
  let focused_element_name = self.get_focused_element_name()
  let buffer_result = @tui.render_to_buffer(
    render_node,
    layout,
    char_width,
    content_height,
    0,
    focused_element_name~,
  )
  self.link_regions = buffer_result.link_regions
  self.hit_regions = buffer_result.hit_regions
  self.image_regions = buffer_result.image_regions
  self.init_scrollable_elements(buffer_result.scrollable_elements)
  self.prev_buffer = None
  self.last_render_key = ""
  self.last_color_scheme_dark = self.dark_mode
  let plain_links = self.build_plain_links(buffer_result.link_regions)
  if self.no_color {
    @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
  } else {
    @tui.buffer_to_ansi(buffer_result.buffer, max_cols=self.terminal_cols)
  }
}

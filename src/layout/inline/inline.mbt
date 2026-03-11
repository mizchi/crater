///|
/// Inline Formatting Context (IFC) implementation
/// Handles horizontal layout of inline and inline-block elements

///|
/// A single line box containing inline-level content
priv struct LineBox {
  items : Array[LineItem] // Items on this line
  mut width : Double // Current width of the line
  mut height : Double // Height of the line (max of all items)
  mut baseline : Double // Distance from top of line box to baseline
}

///|
/// An item positioned within a line box
priv struct LineItem {
  index : Int // Original child index
  layout : @types.Layout // Computed layout
  baseline : Double // Distance from top of item to its baseline
}

///|
fn LineBox::new() -> LineBox {
  { items: [], width: 0.0, height: 0.0, baseline: 0.0 }
}

///|
/// Resolve inset dimension (left/right/top/bottom) against containing size.
fn resolve_inset_dimension(
  dim : @types.Dimension,
  available : Double,
) -> Double? {
  match dim {
    @types.Length(v) => Some(v)
    @types.Percent(p) => Some(available * p)
    _ => None
  }
}

///|
fn inline_establishes_abs_containing_block(style : @style.Style) -> Bool {
  match style.position {
    @types.Absolute | @types.Fixed | @types.Relative => true
    @types.Static =>
      style.display != @types.Inline &&
      (style.contain.layout || style.contain.paint)
  }
}

///|
priv struct WrappedTextMetrics {
  line_count : Int
  last_line_width : Double
}

///|
let inline_text_glyph_height_ratio : Double = 1.045

///|
/// Browser fallback monospace metrics used by WPT in Puppeteer.
let inline_wrap_carry_char_width_ratio : Double = 0.378

///|
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x3040 && cp <= 0x309F) ||
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
fn char_display_width(c : Char) -> Int {
  if is_wide_char(c) {
    2
  } else {
    1
  }
}

///|
fn is_inline_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn first_text_char(node : @node.Node) -> Char? {
  match node.text {
    Some(text) =>
      for c in text.iter() {
        return Some(c)
      }
    None => ()
  }
  for child in node.children {
    match first_text_char(child) {
      Some(c) => return Some(c)
      None => ()
    }
  }
  None
}

///|
fn last_text_char(node : @node.Node) -> Char? {
  let mut i = node.children.length()
  while i > 0 {
    let idx = i - 1
    match last_text_char(node.children[idx]) {
      Some(c) => return Some(c)
      None => ()
    }
    i = i - 1
  }
  match node.text {
    Some(text) => {
      let mut last : Char? = None
      for c in text.iter() {
        last = Some(c)
      }
      last
    }
    None => None
  }
}

///|
fn has_inline_break_opportunity_between(
  prev : @node.Node,
  next : @node.Node,
) -> Bool {
  let no_soft_wrap_prev = match prev.style.white_space {
    @style.WhiteSpace::Nowrap | @style.WhiteSpace::Pre => true
    _ => false
  }
  let no_soft_wrap_next = match next.style.white_space {
    @style.WhiteSpace::Nowrap | @style.WhiteSpace::Pre => true
    _ => false
  }
  if no_soft_wrap_prev || no_soft_wrap_next {
    return false
  }
  match (last_text_char(prev), first_text_char(next)) {
    (Some(prev_last), Some(next_first)) =>
      is_inline_whitespace_char(prev_last) ||
      is_inline_whitespace_char(next_first)
    _ => true
  }
}

///|
fn place_word_with_wrap(
  lines : Int,
  line_width : Int,
  word_width : Int,
  cols_available : Int,
  needs_space : Bool,
) -> (Int, Int) {
  if cols_available <= 0 {
    return (lines, line_width)
  }
  let mut new_lines = lines
  let mut new_line_width = line_width
  let mut space_width = 0
  if needs_space && new_line_width > 0 {
    space_width = 1
  }
  if new_line_width > 0 &&
    new_line_width + space_width + word_width <= cols_available {
    new_line_width = new_line_width + space_width + word_width
    return (new_lines, new_line_width)
  }
  if new_line_width > 0 {
    new_lines = new_lines + 1
    new_line_width = 0
  }
  if word_width <= cols_available {
    return (new_lines, word_width)
  }
  let full_lines = word_width / cols_available
  let remainder = word_width % cols_available
  if remainder == 0 {
    if full_lines > 0 {
      new_lines = new_lines + full_lines - 1
      new_line_width = cols_available
    } else {
      new_line_width = 0
    }
  } else {
    new_lines = new_lines + full_lines
    new_line_width = remainder
  }
  (new_lines, new_line_width)
}

///|
fn estimate_wrapped_text_metrics(
  node : @node.Node,
  available_width : Double,
) -> WrappedTextMetrics? {
  match node.text {
    Some(raw_text) => {
      let text = raw_text.trim().to_string()
      if text.is_empty() || node.style.writing_mode.is_vertical() {
        return None
      }
      let font_size = node.style.font_size
      let char_width = if font_size > 0.0 { font_size * 0.5 } else { 0.0 }
      if char_width <= 0.0 {
        return None
      }
      let no_wrap = match node.style.white_space {
        @style.WhiteSpace::Nowrap => true
        _ => false
      }
      let use_word_wrap = match node.style.white_space {
        @style.WhiteSpace::Normal | @style.WhiteSpace::PreLine => true
        _ => false
      }
      let mut cols_available = if no_wrap {
        1000000
      } else if available_width > 0.0 {
        (available_width / char_width).to_int()
      } else {
        80
      }
      if cols_available <= 0 {
        cols_available = 80
      }

      let mut total_lines = 1
      let mut last_line_cols = 0
      if use_word_wrap && not(no_wrap) {
        let mut current_line_width = 0
        let mut current_word_width = 0
        let mut has_pending_space = false
        for c in text.iter() {
          if c == '\n' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            total_lines = total_lines + 1
            current_line_width = 0
            has_pending_space = false
          } else if c == ' ' || c == '\t' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            has_pending_space = true
          } else {
            current_word_width = current_word_width + char_display_width(c)
          }
        }
        if current_word_width > 0 {
          let (l, w) = place_word_with_wrap(
            total_lines, current_line_width, current_word_width, cols_available,
            has_pending_space,
          )
          total_lines = l
          current_line_width = w
        }
        last_line_cols = current_line_width
      } else {
        let mut current_line_width = 0
        total_lines = 0
        for c in text.iter() {
          if c == '\n' {
            let line_visual_lines = if cols_available > 0 &&
              current_line_width > 0 {
              (current_line_width + cols_available - 1) / cols_available
            } else {
              1
            }
            total_lines = total_lines + line_visual_lines
            current_line_width = 0
          } else if c == ' ' || c == '\t' {
            current_line_width = current_line_width + 1
          } else {
            current_line_width = current_line_width + char_display_width(c)
          }
        }
        let last_line_visual = if cols_available > 0 && current_line_width > 0 {
          (current_line_width + cols_available - 1) / cols_available
        } else {
          1
        }
        total_lines = total_lines + last_line_visual
        if cols_available > 0 && current_line_width > cols_available {
          last_line_cols = current_line_width % cols_available
          if last_line_cols == 0 {
            last_line_cols = cols_available
          }
        } else {
          last_line_cols = current_line_width
        }
      }
      Some({
        line_count: if total_lines > 0 {
          total_lines
        } else {
          1
        },
        last_line_width: last_line_cols.to_double() * char_width,
      })
    }
    None => None
  }
}

///|
fn estimate_inline_wrap_carry_width(
  prev : @node.Node,
  next : @node.Node,
) -> Double? {
  match prev.text {
    Some(raw_text) => {
      let collapses_space = match prev.style.white_space {
        @style.WhiteSpace::Normal | @style.WhiteSpace::PreLine => true
        _ => false
      }
      if not(collapses_space) {
        return None
      }
      let font_size = prev.style.font_size
      if font_size <= 0.0 {
        return None
      }
      let char_width = font_size * inline_wrap_carry_char_width_ratio
      if char_width <= 0.0 {
        return None
      }

      let mut seen_non_ws = false
      let mut in_word = false
      let mut current_word_cols = 0
      let mut last_word_cols = 0
      let mut word_count = 0
      let mut trailing_boundary_space = false

      for c in raw_text.iter() {
        if is_inline_whitespace_char(c) {
          if in_word {
            if current_word_cols > 0 {
              last_word_cols = current_word_cols
            }
            current_word_cols = 0
            in_word = false
          }
          if seen_non_ws {
            trailing_boundary_space = true
          }
        } else {
          seen_non_ws = true
          if not(in_word) {
            word_count = word_count + 1
          }
          in_word = true
          current_word_cols = current_word_cols + char_display_width(c)
          trailing_boundary_space = false
        }
      }
      if in_word && current_word_cols > 0 {
        last_word_cols = current_word_cols
      }
      if last_word_cols <= 0 {
        return None
      }

      match first_text_char(next) {
        Some(c) =>
          if is_inline_whitespace_char(c) {
            trailing_boundary_space = true
          }
        None => ()
      }
      let mut carry_cols = last_word_cols
      if word_count > 1 || trailing_boundary_space {
        carry_cols = carry_cols + 1
      }
      if carry_cols <= 0 {
        None
      } else {
        Some(carry_cols.to_double() * char_width)
      }
    }
    None => None
  }
}

///|
/// Add an item to the line box
fn LineBox::add_item(
  self : LineBox,
  index : Int,
  layout : @types.Layout,
  baseline : Double,
  line_height : Double,
  margin_top : Double,
  margin_bottom : Double,
  margin_left : Double,
  margin_right : Double,
) -> Unit {
  self.items.push({ index, layout, baseline })
  self.width = self.width + layout.width + margin_left + margin_right

  // Update line box baseline and height based on baseline alignment
  // Items are aligned by their baselines, so we need to track:
  // - max distance from top to baseline (above baseline)
  // - max distance from baseline to bottom (below baseline)
  // Negative vertical margins do not pull the line box itself upward/downward.
  let effective_margin_top = if margin_top > 0.0 { margin_top } else { 0.0 }
  let effective_margin_bottom = if margin_bottom > 0.0 {
    margin_bottom
  } else {
    0.0
  }
  let above_baseline = baseline + effective_margin_top
  let below_baseline = line_height - baseline + effective_margin_bottom
  if self.items.length() == 1 {
    // First item sets the initial baseline
    self.baseline = above_baseline
    self.height = above_baseline + below_baseline
  } else {
    // Adjust line box to accommodate this item's baseline
    if above_baseline > self.baseline {
      // This item has more content above baseline
      self.height = self.height + (above_baseline - self.baseline)
      self.baseline = above_baseline
    }
    let current_below = self.height - self.baseline
    if below_baseline > current_below {
      // This item has more content below baseline
      self.height = self.baseline + below_baseline
    }
  }
}

///|
fn id_matches_tag(node_id : String, tag : String) -> Bool {
  node_id == tag ||
  node_id.has_prefix(tag + "#") ||
  node_id.has_prefix(tag + ".")
}

///|
fn is_whitespace_text_node(node : @node.Node) -> Bool {
  if not(node.id.has_prefix("#text")) {
    return false
  }
  match node.text {
    Some(text) => text.trim().is_empty()
    None => true
  }
}

///|
fn has_non_whitespace_text_descendant(node : @node.Node) -> Bool {
  match node.text {
    Some(text) => if not(text.trim().is_empty()) { return true }
    None => ()
  }
  for child in node.children {
    if has_non_whitespace_text_descendant(child) {
      return true
    }
  }
  false
}

///|
fn has_absolute_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    if child.style.position == @types.Absolute {
      return true
    }
    if has_absolute_descendant(child) {
      return true
    }
  }
  false
}

///|
fn has_inflow_block_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    if child.id == "br" || child.id.has_prefix("#text") {
      continue
    }
    if child.style.display == @types.Contents {
      if has_inflow_block_descendant(child) {
        return true
      }
      continue
    }
    if not(is_inline_level(child.style.display)) {
      return true
    }
    if has_inflow_block_descendant(child) {
      return true
    }
  }
  false
}

///|
fn inline_atomic_box_ignores_descendant_block_breaks(
  display : @types.Display,
) -> Bool {
  match display {
    @types.InlineBlock
    | @types.InlineFlex
    | @types.InlineGrid
    | @types.InlineTable => true
    _ => false
  }
}

///|
fn shift_layout_subtree(
  layout : @types.Layout,
  dx : Double,
  dy : Double,
) -> @types.Layout {
  let shifted_children : Array[@types.Layout] = []
  for child in layout.children {
    shifted_children.push(shift_layout_subtree(child, dx, dy))
  }
  { ..layout, x: layout.x + dx, y: layout.y + dy, children: shifted_children }
}

///|
fn is_generated_pseudo_text_only(node : @node.Node) -> Bool {
  if node.id.has_prefix("#text") {
    return true
  }
  if not(node.id.has_prefix("#pseudo::")) {
    return false
  }
  for child in node.children {
    if not(is_generated_pseudo_text_only(child)) {
      return false
    }
  }
  true
}

///|
fn ruby_annotation_only_should_collapse(node : @node.Node) -> Bool {
  let mut has_annotation_child = false
  for child in node.children {
    if id_matches_tag(child.id, "rt") {
      if not(child.style.contain.size) && not(child.style.contain.paint) {
        return false
      }
      has_annotation_child = true
      for grand_child in child.children {
        if not(is_generated_pseudo_text_only(grand_child)) {
          return false
        }
      }
      continue
    }
    if id_matches_tag(child.id, "rp") {
      continue
    }
    if is_whitespace_text_node(child) {
      continue
    }
    return false
  }
  has_annotation_child
}

///|
fn ruby_has_rt_child(node : @node.Node) -> Bool {
  for child in node.children {
    if id_matches_tag(child.id, "rt") {
      return true
    }
  }
  false
}

///|
fn ruby_has_base_child(node : @node.Node) -> Bool {
  for child in node.children {
    if id_matches_tag(child.id, "rb") || id_matches_tag(child.id, "rbc") {
      return true
    }
    if id_matches_tag(child.id, "rt") ||
      id_matches_tag(child.id, "rtc") ||
      id_matches_tag(child.id, "rp") {
      continue
    }
    if is_whitespace_text_node(child) {
      continue
    }
    return true
  }
  false
}

///|
fn ruby_annotation_only(node : @node.Node) -> Bool {
  id_matches_tag(node.id, "ruby") &&
  ruby_has_rt_child(node) &&
  not(ruby_has_base_child(node))
}

///|
fn is_ruby_annotation_child(parent : @node.Node, child : @node.Node) -> Bool {
  id_matches_tag(parent.id, "ruby") && id_matches_tag(child.id, "rt")
}

///|
fn ruby_annotation_band_height(layout : @types.Layout) -> Double {
  let mut max_height = 0.0
  for child in layout.children {
    if id_matches_tag(child.id, "rt") || id_matches_tag(child.id, "rtc") {
      let child_height = child.height + child.margin.top + child.margin.bottom
      if child_height > max_height {
        max_height = child_height
      }
    }
  }
  max_height
}

///|
fn line_height_from_style(style : @style.Style) -> Double {
  if style.line_height > 0.0 {
    style.line_height
  } else if style.font_size > 0.0 {
    style.font_size
  } else {
    16.0
  }
}

///|
fn strut_baseline_from_style(style : @style.Style) -> Double {
  let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
  let line_height = line_height_from_style(style)
  let leading = if line_height > font_size {
    line_height - font_size
  } else {
    0.0
  }
  font_size * 0.8 + leading * 0.5
}

///|
fn is_ruby_internal_container(node_id : String) -> Bool {
  id_matches_tag(node_id, "rb") ||
  id_matches_tag(node_id, "rbc") ||
  id_matches_tag(node_id, "rt") ||
  id_matches_tag(node_id, "rtc")
}

///|
fn is_replaced_strut_candidate(node : @node.Node) -> Bool {
  if node.text is Some(_) {
    return false
  }
  match node.measure {
    Some(_) => ()
    None => return false
  }
  let id = node.id
  id_matches_tag(id, "br") ||
  id_matches_tag(id, "img") ||
  id_matches_tag(id, "canvas") ||
  id_matches_tag(id, "video") ||
  id_matches_tag(id, "audio") ||
  id_matches_tag(id, "embed") ||
  id_matches_tag(id, "object") ||
  id_matches_tag(id, "iframe") ||
  id_matches_tag(id, "svg") ||
  id_matches_tag(id, "input") ||
  id_matches_tag(id, "select") ||
  id_matches_tag(id, "textarea")
}

///|
fn inline_source_children_only_contribute_floats(
  children : Array[@node.Node],
) -> Bool {
  let mut has_float_contribution = false
  for child in children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    if child.id.has_prefix("#text") {
      match child.text {
        Some(text) =>
          if not(is_whitespace_text_node(child)) && not(text.is_empty()) {
            return false
          }
        None => ()
      }
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => {
        has_float_contribution = true
        continue
      }
      @types.Float::None => ()
    }
    if child.children.length() == 0 ||
      is_inline_level(child.style.display) ||
      child.style.display == @types.Contents ||
      not(inline_source_children_only_contribute_floats(child.children)) {
      return false
    }
    has_float_contribution = true
  }
  has_float_contribution
}

///|
fn adjust_inline_float_only_wrapper(
  layout : @types.Layout,
  source_node : @node.Node,
  writing_mode : @style.WritingMode,
) -> @types.Layout {
  if not(id_matches_tag(layout.id, "span")) ||
    not(id_matches_tag(source_node.id, "span")) ||
    writing_mode.is_vertical() ||
    layout.height != 0.0 ||
    layout.width <= 0.0 ||
    layout.children.length() == 0 {
    return layout
  }
  if not(inline_source_children_only_contribute_floats(source_node.children)) {
    return layout
  }
  let shifted_children : Array[@types.Layout] = []
  let mut has_visible_child = false
  for child in layout.children {
    if child.width > 0.0 || child.height > 0.0 {
      has_visible_child = true
    }
    shifted_children.push({ ..child, x: child.x - layout.width })
  }
  if not(has_visible_child) {
    return layout
  }
  {
    ..layout,
    x: layout.x + layout.width,
    width: 0.0,
    children: shifted_children,
  }
}

///|
fn is_replaced_intrinsic_candidate(node : @node.Node) -> Bool {
  if node.text is Some(_) {
    return false
  }
  match node.measure {
    Some(_) => ()
    None => return false
  }
  let id = node.id
  id_matches_tag(id, "img") ||
  id_matches_tag(id, "canvas") ||
  id_matches_tag(id, "video") ||
  id_matches_tag(id, "audio") ||
  id_matches_tag(id, "embed") ||
  id_matches_tag(id, "object") ||
  id_matches_tag(id, "iframe") ||
  id_matches_tag(id, "svg") ||
  id_matches_tag(id, "input") ||
  id_matches_tag(id, "textarea")
}

///|
fn text_glyph_height_from_style(style : @style.Style) -> Double {
  if style.font_size > 0.0 {
    style.font_size * inline_text_glyph_height_ratio
  } else {
    0.0
  }
}

///|
fn max_text_glyph_height_in_node(node : @node.Node) -> Double {
  let mut max_height = 0.0
  match node.text {
    Some(_) => {
      let glyph = text_glyph_height_from_style(node.style)
      if glyph > max_height {
        max_height = glyph
      }
    }
    None => ()
  }
  for child in node.children {
    let child_height = max_text_glyph_height_in_node(child)
    if child_height > max_height {
      max_height = child_height
    }
  }
  max_height
}

///|
fn resolve_abs_static_position_in_inline(
  container_style : @style.Style,
  abs_child_style : @style.Style,
  inline_cursor_x : Double,
  inline_cursor_y : Double,
  inline_line_height : Double,
) -> (Double, Double) {
  let line_advance = if inline_line_height > 0.0 {
    inline_line_height
  } else {
    line_height_from_style(container_style)
  }
  if container_style.writing_mode.is_vertical() {
    let static_x = if is_inline_level(abs_child_style.display) {
      inline_cursor_x
    } else if container_style.writing_mode.is_block_rtl() {
      // Vertical-rl static-positioned block descendants advance to the
      // previous column edge before abs alignment is applied.
      inline_cursor_x - line_advance * 2.0
    } else {
      inline_cursor_x
    }
    (static_x, inline_cursor_y)
  } else {
    let static_x = if is_inline_level(abs_child_style.display) {
      inline_cursor_x
    } else {
      0.0
    }
    let static_y = if is_inline_level(abs_child_style.display) {
      inline_cursor_y
    } else if inline_line_height > 0.0 {
      inline_cursor_y + inline_line_height
    } else {
      inline_cursor_y
    }
    (static_x, static_y)
  }
}

///|
/// Ensure each line box includes the inline formatting strut from parent font metrics.
/// The strut defines the line box minimum ascent/descent from line-height.
fn LineBox::ensure_line_strut(
  self : LineBox,
  children : Array[@node.Node],
) -> Unit {
  if self.items.length() == 0 {
    return ()
  }
  let mut replaced_like_count = 0
  let mut has_text_item = false
  let mut has_br_item = false
  for item in self.items {
    let child = children[item.index]
    if child.text is Some(_) {
      has_text_item = true
    }
    if child.id == "br" {
      has_br_item = true
    }
    if is_replaced_strut_candidate(child) {
      replaced_like_count = replaced_like_count + 1
    }
  }
  if has_text_item || (replaced_like_count == 0 && not(has_br_item)) {
    return ()
  }
  if replaced_like_count > 0 && not(has_br_item) {
    // Browser WPT behavior: replaced-only lines size to the replaced items
    // themselves; they do not get an additional inline formatting strut band.
    return ()
  }
  let first_item = self.items[0]
  let first_child = children[first_item.index]
  let font_size = first_child.style.font_size
  let line_height = if first_child.style.line_height > 0.0 {
    first_child.style.line_height
  } else {
    font_size
  }
  let ascender_ratio = 0.8
  let leading = if line_height > font_size {
    line_height - font_size
  } else {
    0.0
  }
  let strut_baseline = if has_br_item {
    font_size * ascender_ratio + leading * 0.5
  } else {
    font_size * ascender_ratio
  }
  let strut_below = if line_height > strut_baseline {
    line_height - strut_baseline
  } else {
    0.0
  }

  if self.baseline < strut_baseline {
    self.height = self.height + (strut_baseline - self.baseline)
    self.baseline = strut_baseline
  }
  let current_below = self.height - self.baseline
  if current_below < strut_below {
    self.height = self.baseline + strut_below
  }
}

///|
/// Check if an item can fit in this line
fn LineBox::can_fit(
  self : LineBox,
  item_width : Double,
  margin_left : Double,
  margin_right : Double,
  available_width : Double,
) -> Bool {
  let item_advance = item_width + margin_left + margin_right
  self.width + item_width + margin_left + margin_right <= available_width ||
  (
    self.items.length() > 0 &&
    self.width > available_width &&
    item_advance <= 0.0
  ) ||
  self.items.length() == 0 // Always fit at least one item per line
}

///|
fn resolve_text_align_offset(
  text_align : @style.TextAlign,
  direction : @style.Direction,
  available_width : Double,
  line_width : Double,
) -> Double {
  let remaining = if available_width > line_width {
    available_width - line_width
  } else {
    0.0
  }
  match text_align {
    @style.TextAlign::Center => remaining / 2.0
    @style.TextAlign::Start => 0.0
    @style.TextAlign::End => remaining
    @style.TextAlign::Left => if direction.is_rtl() { remaining } else { 0.0 }
    @style.TextAlign::Right => if direction.is_rtl() { 0.0 } else { remaining }
    @style.TextAlign::Justify => 0.0
  }
}

///|
/// Result of IFC computation
pub struct InlineLayoutResult {
  layouts : Array[@types.Layout] // Positioned child layouts
  total_height : Double // Total height of all line boxes
}

///|
/// Compute inline formatting context for children
/// Returns positioned layouts and total height
pub fn compute_ifc(
  children : Array[@node.Node],
  available_width : Double,
  available_height : Double?,
  content_offset_x : Double, // Padding + border left
  content_offset_y : Double, // Padding + border top
  dispatch : @node.DispatchFn,
  container_writing_mode? : @style.WritingMode = @style.WritingMode::HorizontalTb,
  container_direction? : @style.Direction = @style.Direction::Ltr,
  container_text_align? : @style.TextAlign = @style.TextAlign::Start,
  container_white_space? : @style.WhiteSpace = @style.WhiteSpace::Normal,
) -> InlineLayoutResult {
  if children.length() == 0 {
    return { layouts: [], total_height: 0.0 }
  }

  // Inline progression should follow container writing-mode, not child writing-mode.
  let writing_mode = container_writing_mode
  let is_vertical_rl = writing_mode.is_vertical() && writing_mode.is_block_rtl()
  let allow_soft_wrap = match container_white_space {
    @style.WhiteSpace::Nowrap | @style.WhiteSpace::Pre => false
    _ => true
  }
  if writing_mode.is_vertical() {
    let columns : Array[Array[Int]] = []
    let column_widths : Array[Double] = []
    let column_heights : Array[Double] = []
    let layout_map : Map[Int, @types.Layout] = {}
    let child_layout_cache : Map[Int, @types.Layout] = {}
    let child_margin_cache : Map[Int, @types.Rect[Double]] = {}

    let mut current_column : Array[Int] = []
    let mut current_width = 0.0
    let mut current_height = 0.0
    let max_inline_extent : Double? = match available_height {
      Some(h) if h > 0.0 => Some(h)
      _ => None
    }

    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      if child.style.display == @types.Display::None {
        layout_map[i] = create_zero_layout(child)
        continue
      }
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )
      let child_available_width = @types.max(
        0.0,
        available_width - child_margin.left - child_margin.right,
      )
      let child_layout = compute_inline_child(
        child, child_available_width, available_height, dispatch,
      )
      let child_layout = if is_whitespace_text_node(child) {
        // Keep inline advance for whitespace runs but avoid column-height inflation.
        { ..child_layout, height: 0.0 }
      } else {
        child_layout
      }
      child_layout_cache[i] = child_layout
      child_margin_cache[i] = child_margin

      let outer_height = child_layout.height +
        child_margin.top +
        child_margin.bottom
      let should_wrap_column = match max_inline_extent {
        Some(limit) =>
          allow_soft_wrap &&
          current_column.length() > 0 &&
          child.id != "br" &&
          current_height + outer_height >= limit
        None => false
      }
      if should_wrap_column {
        columns.push(current_column)
        column_widths.push(current_width)
        column_heights.push(current_height)
        current_column = []
        current_width = 0.0
        current_height = 0.0
      }

      current_column.push(i)
      let outer_width = child_layout.width +
        child_margin.left +
        child_margin.right
      if outer_width > current_width {
        current_width = outer_width
      }
      current_height = current_height + outer_height

      if child.id == "br" {
        columns.push(current_column)
        column_widths.push(current_width)
        column_heights.push(current_height)
        current_column = []
        current_width = 0.0
        current_height = 0.0
      }
    }

    if current_column.length() > 0 {
      columns.push(current_column)
      column_widths.push(current_width)
      column_heights.push(current_height)
    }

    let mut total_height = 0.0
    let mut total_columns_width = 0.0
    for col_width in column_widths {
      total_columns_width = total_columns_width + col_width
    }
    let resolved_inline_span = if available_width > total_columns_width {
      available_width
    } else {
      total_columns_width
    }
    let mut x_cursor = if is_vertical_rl {
      content_offset_x + resolved_inline_span
    } else {
      content_offset_x
    }

    for col_idx = 0; col_idx < columns.length(); col_idx = col_idx + 1 {
      let column = columns[col_idx]
      let col_width = column_widths[col_idx]
      let col_height = column_heights[col_idx]
      if col_height > total_height {
        total_height = col_height
      }

      let mut col_x = x_cursor
      if is_vertical_rl {
        x_cursor = x_cursor - col_width
        col_x = x_cursor
      } else {
        col_x = x_cursor
        x_cursor = x_cursor + col_width
      }

      let mut y_cursor = content_offset_y
      for item_index in column {
        match child_layout_cache.get(item_index) {
          Some(item_layout) =>
            match child_margin_cache.get(item_index) {
              Some(child_margin) => {
                let positioned : @types.Layout = {
                  id: item_layout.id,
                  x: col_x + child_margin.left,
                  y: y_cursor + child_margin.top,
                  width: item_layout.width,
                  height: item_layout.height,
                  margin: child_margin,
                  padding: item_layout.padding,
                  border: item_layout.border,
                  overflow_x: item_layout.overflow_x,
                  overflow_y: item_layout.overflow_y,
                  scroll_width: item_layout.scroll_width,
                  scroll_height: item_layout.scroll_height,
                  children: item_layout.children,
                  text: item_layout.text,
                }
                layout_map[item_index] = positioned
                y_cursor = positioned.y +
                  item_layout.height +
                  child_margin.bottom
              }
              None => ()
            }
          None => ()
        }
      }
    }

    let layouts : Array[@types.Layout] = []
    for i = 0; i < children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => layouts.push(layout)
        None => ()
      }
    }
    return { layouts, total_height }
  }

  // Collect inline-level children and compute their layouts
  let line_boxes : Array[LineBox] = []
  let mut current_line = LineBox::new()
  let layout_map : Map[Int, @types.Layout] = {}
  let child_has_abs_desc_cache : Map[Int, Bool] = {}
  let child_has_non_ws_text_cache : Map[Int, Bool] = {}
  let child_has_inflow_block_desc_flag : Array[Bool] = []
  for child in children {
    if child.style.display == @types.Display::None {
      child_has_inflow_block_desc_flag.push(false)
    } else if inline_atomic_box_ignores_descendant_block_breaks(
        child.style.display,
      ) {
      child_has_inflow_block_desc_flag.push(false)
    } else {
      child_has_inflow_block_desc_flag.push(has_inflow_block_descendant(child))
    }
  }
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let child_has_inflow_block_desc = child_has_inflow_block_desc_flag[i]

    // Skip display:none children
    if child.style.display == @types.Display::None {
      layout_map[i] = create_zero_layout(child)
      continue
    }

    // Resolve child's box model
    let child_margin = @types.resolve_rect(child.style.margin, available_width)
    let child_available_width = @types.max(
      0.0,
      available_width - child_margin.left - child_margin.right,
    )

    // Compute child's intrinsic size
    let child_layout = compute_inline_child(
      child, child_available_width, available_height, dispatch,
    )
    let child_layout = if current_line.items.length() == 0 &&
      is_whitespace_text_node(child) {
      // Collapsible leading whitespace at line start should not shift following items.
      { ..child_layout, width: 0.0, height: 0.0 }
    } else {
      child_layout
    }
    let child_layout = if is_whitespace_text_node(child) {
      // Keep inter-item spacing while preventing indentation whitespace from
      // inflating line box metrics.
      { ..child_layout, height: 0.0 }
    } else {
      child_layout
    }

    // Calculate baseline based on font metrics
    // For text nodes, baseline is at font_size * ascender_ratio from top
    // Typical ascender ratio is ~0.8 (80% of font height is above baseline)
    let mut baseline = if child.id == "br" {
      // <br> participates in line boxes but its baseline should align with text baseline,
      // not with its full line-height box bottom.
      let font_size = child.style.font_size
      // Use text ascent-like baseline for br so tall line-height runs don't
      // sink the break position too far down.
      let ascender_ratio = 0.8
      let raw = font_size * ascender_ratio
      let br_baseline = if raw > 0.0 { raw } else { 0.0 }
      br_baseline + child_layout.padding.top + child_layout.border.top
    } else if child.id.has_prefix("#text") {
      // Text node: use baseline synthesis that includes half-leading.
      @baseline.compute_node_baseline(child, child_layout.height)
    } else if child.style.contain.size &&
      is_replaced_strut_candidate(child) &&
      child.text is None {
      // Browser-like quirk for contain:size replaced inlines:
      // baseline sits near margin-box bottom, which keeps following whitespace
      // and <br> on the lower line band in mixed replaced/text runs.
      child_layout.height + child_margin.bottom
    } else if child.style.contain.size &&
      child.text is Some(_) &&
      id_matches_tag(child.id, "img") {
      // For contain:size replaced inlines, preserve additional baseline depth
      // contributed by suppressed intrinsic content so mixed inline lines don't
      // collapse too short.
      child_layout.height +
      child_layout.padding.bottom +
      child_layout.border.bottom
    } else {
      // Non-text inline elements should use synthesized content baseline
      // instead of always falling back to bottom.
      @baseline.compute_node_baseline(child, child_layout.height)
    }
    let mut line_metrics_height = child_layout.height
    if ruby_annotation_only(child) {
      let annotation_height = ruby_annotation_band_height(child_layout)
      if annotation_height > 0.0 {
        line_metrics_height = annotation_height +
          line_height_from_style(child.style)
        baseline = annotation_height + strut_baseline_from_style(child.style)
      }
    }
    let line_metrics_baseline = match child.style.vertical_align {
      // Top-aligned inline-level boxes should not pull the line baseline down.
      @style.VerticalAlign::Top | @style.VerticalAlign::TextTop => 0.0
      _ => baseline
    }

    if current_line.items.length() > 0 && child_has_inflow_block_desc {
      current_line.ensure_line_strut(children)
      line_boxes.push(current_line)
      current_line = LineBox::new()
    }

    // <br> always forces a line break after itself.
    if child.id == "br" {
      current_line.add_item(
        i,
        child_layout,
        line_metrics_baseline,
        line_metrics_height,
        child_margin.top,
        child_margin.bottom,
        child_margin.left,
        child_margin.right,
      )
      current_line.ensure_line_strut(children)
      line_boxes.push(current_line)
      current_line = LineBox::new()
      continue
    }

    // Check if this item fits in the current line
    if current_line.can_fit(
        child_layout.width,
        child_margin.left,
        child_margin.right,
        available_width,
      ) {
      current_line.add_item(
        i,
        child_layout,
        line_metrics_baseline,
        line_metrics_height,
        child_margin.top,
        child_margin.bottom,
        child_margin.left,
        child_margin.right,
      )
    } else {
      let mut keep_same_line = false
      if current_line.items.length() > 0 {
        let prev_item = current_line.items[current_line.items.length() - 1]
        let prev_child = children[prev_item.index]
        let has_break_opportunity = has_inline_break_opportunity_between(
          prev_child, child,
        )
        keep_same_line = not(has_break_opportunity)
        let child_establishes_abs_cb = inline_establishes_abs_containing_block(
          child.style,
        )
        let child_has_abs_desc = if child_establishes_abs_cb {
          match child_has_abs_desc_cache.get(i) {
            Some(v) => v
            None => {
              let v = has_absolute_descendant(child)
              child_has_abs_desc_cache[i] = v
              v
            }
          }
        } else {
          false
        }
        if has_break_opportunity &&
          child_establishes_abs_cb &&
          child_has_abs_desc &&
          not(child_has_inflow_block_desc) {
          // Inline abs-containing wrappers may keep their first fragment on the
          // current line even when the overall bounding box exceeds line width.
          keep_same_line = true
        }
      }
      if keep_same_line {
        current_line.add_item(
          i,
          child_layout,
          line_metrics_baseline,
          line_metrics_height,
          child_margin.top,
          child_margin.bottom,
          child_margin.left,
          child_margin.right,
        )
        continue
      }
      // Start a new line
      current_line.ensure_line_strut(children)
      line_boxes.push(current_line)
      current_line = LineBox::new()
      current_line.add_item(
        i,
        child_layout,
        line_metrics_baseline,
        line_metrics_height,
        child_margin.top,
        child_margin.bottom,
        child_margin.left,
        child_margin.right,
      )
    }
  }

  // Don't forget the last line
  if current_line.items.length() > 0 {
    current_line.ensure_line_strut(children)
    line_boxes.push(current_line)
  }

  // Position items within line boxes
  let is_rtl_inline = container_direction.is_rtl()
  let default_text_align = container_text_align == @style.TextAlign::Start
  let mut current_y = content_offset_y
  for line_index = 0
      line_index < line_boxes.length()
      line_index = line_index + 1 {
    let line = line_boxes[line_index]
    let line_offset = if default_text_align {
      0.0
    } else {
      resolve_text_align_offset(
        container_text_align,
        container_direction,
        available_width,
        line.width,
      )
    }
    let mut current_x = if is_rtl_inline {
      content_offset_x + available_width - line_offset
    } else {
      content_offset_x + line_offset
    }
    for item_index = 0
        item_index < line.items.length()
        item_index = item_index + 1 {
      let item = line.items[item_index]
      let child = children[item.index]
      let child_has_inflow_block_desc = child_has_inflow_block_desc_flag[item.index]
      let child_establishes_abs_cb = inline_establishes_abs_containing_block(
        child.style,
      )
      let child_has_abs_desc = if child_establishes_abs_cb {
        match child_has_abs_desc_cache.get(item.index) {
          Some(v) => v
          None => {
            let v = has_absolute_descendant(child)
            child_has_abs_desc_cache[item.index] = v
            v
          }
        }
      } else {
        false
      }
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )

      // Position at current x with margin
      let x = if is_rtl_inline {
        current_x - child_margin.right - item.layout.width
      } else {
        current_x + child_margin.left
      }

      // Vertical alignment based on child's vertical-align property
      let y = match child.style.vertical_align {
        @style.VerticalAlign::Top | @style.VerticalAlign::TextTop =>
          // Align to top of line box
          current_y + child_margin.top
        @style.VerticalAlign::Middle =>
          // Align to middle of line box
          current_y + (line.height - item.layout.height) / 2.0
        @style.VerticalAlign::Bottom | @style.VerticalAlign::TextBottom =>
          // Align to bottom of line box
          current_y + (line.height - item.layout.height)
        @style.VerticalAlign::Baseline =>
          // Align item's baseline to line box's baseline
          // y_offset = line_baseline - item_baseline
          current_y + (line.baseline - item.baseline)
        @style.VerticalAlign::Sub => {
          // Subscript: baseline shifted down by ~30% of font size
          let baseline_y = current_y + (line.baseline - item.baseline)
          baseline_y + child.style.font_size * 0.3
        }
        @style.VerticalAlign::Super => {
          // Superscript: baseline shifted up by ~40% of font size
          let baseline_y = current_y + (line.baseline - item.baseline)
          baseline_y - child.style.font_size * 0.4
        }
      }
      let mut positioned_x = x
      let mut positioned_y = y
      if child.id == "br" && item_index > 0 {
        let prev_item = line.items[item_index - 1]
        let prev_child = children[prev_item.index]
        if prev_child.id.has_prefix("#text") {
          match layout_map.get(prev_item.index) {
            Some(prev_layout) => {
              let wrap_width = if prev_layout.width > 0.0 {
                prev_layout.width
              } else {
                available_width
              }
              match estimate_wrapped_text_metrics(prev_child, wrap_width) {
                Some(metrics) if metrics.line_count > 1 => {
                  let line_height = if prev_child.style.line_height > 0.0 {
                    prev_child.style.line_height
                  } else {
                    prev_layout.height
                  }
                  let fallback_last_width = prev_layout.width
                  let mut last_line_width = metrics.last_line_width
                  if last_line_width <= 0.0 {
                    last_line_width = fallback_last_width
                  }
                  let raw_x = prev_layout.x + last_line_width
                  if available_width > 0.0 {
                    let max_x = content_offset_x + available_width
                    positioned_x = if raw_x > max_x { max_x } else { raw_x }
                  } else {
                    positioned_x = raw_x
                  }
                  positioned_y = prev_layout.y +
                    (metrics.line_count - 1).to_double() * line_height
                }
                _ => ()
              }
            }
            _ => ()
          }
        }
      }
      if item_index == 0 &&
        line_index > 0 &&
        inline_establishes_abs_containing_block(child.style) &&
        not(child_has_inflow_block_desc) {
        let prev_line = line_boxes[line_index - 1]
        if prev_line.items.length() > 0 {
          let prev_item = prev_line.items[prev_line.items.length() - 1]
          let prev_child = children[prev_item.index]
          if has_inline_break_opportunity_between(prev_child, child) {
            match estimate_inline_wrap_carry_width(prev_child, child) {
              Some(carry_width) => {
                let mut max_carry = available_width -
                  item.layout.width -
                  child_margin.left -
                  child_margin.right
                if max_carry < 0.0 {
                  max_carry = 0.0
                }
                let bounded_carry = if carry_width > max_carry {
                  max_carry
                } else {
                  carry_width
                }
                if bounded_carry > 0.0 {
                  positioned_x = content_offset_x +
                    child_margin.left +
                    bounded_carry
                }
              }
              None => ()
            }
          }
        }
      }
      if is_vertical_rl {
        let rel_x = positioned_x - content_offset_x
        positioned_x = content_offset_x +
          available_width -
          rel_x -
          item.layout.width
        if child.id == "br" {
          // br is positioned at inline advance end before forcing next column.
          // After x-mirroring for vertical-rl, compensate the consumed advance.
          positioned_x = positioned_x + item.layout.width * 2.0
        }
      }
      if ruby_annotation_only(child) &&
        not(ruby_annotation_only_should_collapse(child)) {
        let annotation_height = ruby_annotation_band_height(item.layout)
        if annotation_height > 0.0 {
          positioned_y = positioned_y + annotation_height
        }
      }
      if child.style.position == @types.Relative {
        let rel_left = resolve_inset_dimension(
          child.style.inset.left,
          available_width,
        )
        let rel_right = resolve_inset_dimension(
          child.style.inset.right,
          available_width,
        )
        let rel_top = resolve_inset_dimension(
          child.style.inset.top,
          available_height.unwrap_or(0.0),
        )
        let rel_bottom = resolve_inset_dimension(
          child.style.inset.bottom,
          available_height.unwrap_or(0.0),
        )
        let x_offset = match (rel_left, rel_right) {
          (Some(l), Some(r)) => l - r
          (Some(l), None) => l
          (None, Some(r)) => -r
          _ => 0.0
        }
        let y_offset = match (rel_top, rel_bottom) {
          (Some(t), Some(b)) => t - b
          (Some(t), None) => t
          (None, Some(b)) => -b
          _ => 0.0
        }
        positioned_x = positioned_x + x_offset
        positioned_y = positioned_y + y_offset
      }
      let mut effective_layout = item.layout
      if item_index > 0 &&
        child_establishes_abs_cb &&
        child_has_abs_desc &&
        not(child_has_inflow_block_desc) &&
        positioned_x > content_offset_x {
        let carry_x = positioned_x - content_offset_x
        let shifted_children : Array[@types.Layout] = []
        for child_layout in effective_layout.children {
          shifted_children.push(
            shift_layout_subtree(child_layout, carry_x, 0.0),
          )
        }
        let child_has_non_ws_text = match
          child_has_non_ws_text_cache.get(item.index) {
          Some(v) => v
          None => {
            let v = has_non_whitespace_text_descendant(child)
            child_has_non_ws_text_cache[item.index] = v
            v
          }
        }
        let line_band = line_height_from_style(child.style)
        let expanded_height = if effective_layout.height > line_band &&
          child_has_non_ws_text {
          effective_layout.height + line_band * 2.0
        } else if effective_layout.height > line_band {
          effective_layout.height + line_band
        } else {
          effective_layout.height
        }
        effective_layout = {
          ..effective_layout,
          height: expanded_height,
          children: shifted_children,
        }
        positioned_x = content_offset_x
      }
      let is_contents_child = child.style.display == @types.Contents
      let positioned : @types.Layout = {
        id: effective_layout.id,
        x: positioned_x,
        y: positioned_y,
        width: if is_contents_child {
          0.0
        } else {
          effective_layout.width
        },
        height: if is_contents_child {
          0.0
        } else {
          effective_layout.height
        },
        margin: child_margin,
        padding: if is_contents_child {
          @types.Rect::zero()
        } else {
          effective_layout.padding
        },
        border: if is_contents_child {
          @types.Rect::zero()
        } else {
          effective_layout.border
        },
        overflow_x: effective_layout.overflow_x,
        overflow_y: effective_layout.overflow_y,
        scroll_width: effective_layout.scroll_width,
        scroll_height: effective_layout.scroll_height,
        children: effective_layout.children,
        text: effective_layout.text,
      }
      let positioned = adjust_inline_float_only_wrapper(
        positioned, child, container_writing_mode,
      )
      layout_map[item.index] = positioned
      current_x = if is_rtl_inline {
        positioned_x - child_margin.left
      } else {
        positioned_x + item.layout.width + child_margin.right
      }
    }
    current_y = current_y + line.height
  }

  // Assemble layouts in original order
  let layouts : Array[@types.Layout] = []
  for i = 0; i < children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(layout) => layouts.push(layout)
      None => ()
    }
  }
  { layouts, total_height: current_y - content_offset_y }
}

///|
/// Compute layout for an inline-level child
fn compute_inline_child(
  node : @node.Node,
  available_width : Double,
  available_height : Double?,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style
  let is_contents_display = style.display == @types.Contents
  let padding = if is_contents_display {
    @types.Rect::zero()
  } else {
    @types.resolve_rect(style.padding, available_width)
  }
  let border = if is_contents_display {
    @types.Rect::zero()
  } else {
    @types.resolve_rect(style.border, available_width)
  }

  // Handle leaf nodes with MeasureFunc (e.g., text nodes, replaced elements)
  match node.measure {
    Some(mf) => {
      // First, get unconstrained intrinsic sizes (for min-content, max-content)
      let unconstrained = (mf.func)(
        @double.infinity,
        available_height.unwrap_or(0.0),
      )
      let suppress_inline_intrinsic = style.suppresses_intrinsic_width()
      let suppress_block_intrinsic = style.suppresses_intrinsic_height()
      let use_intrinsic_ratio_fallback = is_replaced_intrinsic_candidate(node) &&
        not(style.contain.size)
      let intrinsic_ratio : Double? = if use_intrinsic_ratio_fallback &&
        unconstrained.max_width > 0.0 &&
        unconstrained.max_height > 0.0 {
        Some(unconstrained.max_width / unconstrained.max_height)
      } else {
        None
      }
      let ratio_for_auto = match style.aspect_ratio {
        Some(r) => Some(r)
        None => intrinsic_ratio
      }

      // Check if we should use aspect_ratio to derive dimensions
      // For replaced elements like canvas/img with aspect_ratio:
      // - If width is Auto and height is definite (Length or Percent), derive width from height * aspect_ratio
      let height_is_definite = match style.height {
        @types.Length(_) | @types.Percent(_) => true
        _ => false
      }

      // Calculate height first (needed for aspect_ratio calculation)
      let initial_height : Double? = match style.height {
        @types.Length(h) => Some(h)
        @types.Percent(p) =>
          match available_height {
            Some(ah) => Some(ah * p)
            None => None
          }
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => None
      }

      // Calculate content width based on sizing mode and aspect_ratio
      let content_width = match style.width {
        @types.Length(w) =>
          w - padding.horizontal_sum() - border.horizontal_sum()
        @types.Percent(p) =>
          available_width * p -
          padding.horizontal_sum() -
          border.horizontal_sum()
        @types.MinContent =>
          if suppress_inline_intrinsic {
            style.contained_intrinsic_width_fallback()
          } else {
            unconstrained.min_width
          }
        @types.MaxContent =>
          if suppress_inline_intrinsic {
            style.contained_intrinsic_width_fallback()
          } else {
            unconstrained.max_width
          }
        @types.FitContent(_) | @types.Auto =>
          // Check if we can derive width from aspect_ratio
          match (ratio_for_auto, initial_height, height_is_definite) {
            (Some(ratio), Some(h), true) if ratio > 0.0 =>
              // Derive width from height using aspect_ratio
              // For content-box sizing, use content height
              if style.box_sizing == @types.BorderBox {
                h * ratio - padding.horizontal_sum() - border.horizontal_sum()
              } else {
                let content_h = h -
                  padding.vertical_sum() -
                  border.vertical_sum()
                if content_h > 0.0 {
                  content_h * ratio
                } else if suppress_inline_intrinsic {
                  style.contained_intrinsic_width_fallback()
                } else {
                  unconstrained.max_width
                }
              }
            _ => {
              // Fallback: use intrinsic width, constrained to available_width
              let max_content = if suppress_inline_intrinsic {
                style.contained_intrinsic_width_fallback()
              } else {
                unconstrained.max_width
              }
              let min_content = if suppress_inline_intrinsic {
                style.contained_intrinsic_width_fallback()
              } else {
                unconstrained.min_width
              }
              let content_available = available_width -
                padding.horizontal_sum() -
                border.horizontal_sum()
              if content_available <= 0.0 {
                min_content
              } else if max_content < content_available {
                max_content
              } else {
                content_available
              }
            }
          }
      }

      // Re-call MeasureFunc with constrained width to get correct height
      let constrained = (mf.func)(
        content_width,
        available_height.unwrap_or(0.0),
      )
      let intrinsic_height_for_auto = if suppress_block_intrinsic {
        style.contained_intrinsic_height_fallback()
      } else {
        constrained.max_height
      }
      let text_like_vertical_auto_width = style.writing_mode.is_vertical() &&
        style.width == @types.Auto &&
        node.id.has_prefix("#text")
      let width = if text_like_vertical_auto_width {
        constrained.max_width +
        padding.horizontal_sum() +
        border.horizontal_sum()
      } else {
        content_width + padding.horizontal_sum() + border.horizontal_sum()
      }

      // Calculate final height
      let height = match style.height {
        @types.Length(h) => h
        @types.Percent(p) =>
          match available_height {
            Some(ah) => ah * p
            None =>
              // No definite parent height, fall back to intrinsic + aspect_ratio
              match ratio_for_auto {
                Some(ratio) if ratio > 0.0 => width / ratio
                _ =>
                  intrinsic_height_for_auto +
                  padding.vertical_sum() +
                  border.vertical_sum()
              }
          }
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) =>
          match ratio_for_auto {
            Some(ratio) if ratio > 0.0 =>
              // Derive auto-height from the used width for replaced-like inline leaves.
              if style.box_sizing == @types.BorderBox {
                width / ratio
              } else {
                content_width / ratio +
                padding.vertical_sum() +
                border.vertical_sum()
              }
            _ =>
              intrinsic_height_for_auto +
              padding.vertical_sum() +
              border.vertical_sum()
          }
      }
      let min_width = style.min_width.resolve_or(available_width, 0.0)
      let max_width = style.max_width.resolve_or(
        available_width, @double.infinity,
      )
      let height_context = available_height.unwrap_or(0.0)
      let min_height = style.min_height.resolve_or(height_context, 0.0)
      let max_height = style.max_height.resolve_or(
        height_context, @double.infinity,
      )
      let mut final_width = @types.clamp(width, min_width, max_width)
      let mut final_height = @types.clamp(height, min_height, max_height)
      match style.aspect_ratio {
        Some(ratio) if ratio > 0.0 => {
          let width_changed = final_width != width
          let height_changed = final_height != height
          if width_changed && not(height_changed) {
            final_height = final_width / ratio
          } else if height_changed && not(width_changed) {
            final_width = final_height * ratio
          }
          final_width = @types.clamp(final_width, min_width, max_width)
          final_height = @types.clamp(final_height, min_height, max_height)
        }
        _ => ()
      }
      return {
        id: node.id,
        x: 0.0,
        y: 0.0,
        width: final_width,
        height: final_height,
        margin: @types.Rect::zero(),
        padding,
        border,
        overflow_x: style.overflow_x,
        overflow_y: style.overflow_y,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [],
        text: node.text,
      }
    }
    None => ()
  }

  // For inline-block, inline-flex, inline-grid, use shrink-to-fit via layout dispatcher
  if style.display == @types.InlineBlock ||
    style.display == @types.InlineFlex ||
    style.display == @types.InlineGrid {
    let sizing_mode = if style.display == @types.InlineBlock {
      // Inline-block width:auto shrink-to-fit is handled in block layout even in Definite mode.
      // Keep Definite here so percentage padding/height resolve against containing block.
      @types.Definite
    } else {
      @types.MaxContent
    }
    // Use the dispatch function to get proper block/flex/grid layout
    let ctx : @types.LayoutContext = {
      available_width,
      available_height,
      sizing_mode,
      viewport_width: available_width,
      viewport_height: available_height.unwrap_or(0.0),
      stretch_width: false,
      stretch_height: false,
    } // Use MaxContent for shrink-to-fit
    let @node.DispatchFn(dispatch_fn) = dispatch
    let layout = dispatch_fn(node, ctx, dispatch)
    return layout
  }

  // For plain inline elements (no MeasureFunc), calculate size based on children
  // and handle absolute positioned children
  let children : Array[@types.Layout] = []
  let mut content_width = 0.0
  let mut content_height = 0.0
  let mut inline_cursor_x = 0.0
  let mut inline_cursor_y = 0.0
  let mut inline_line_height = 0.0
  let mut max_line_width = 0.0

  // Process children - handle absolute positioned elements
  let absolute_entries : Array[(Int, @node.Node, Double, Double)] = []
  let mut saw_out_of_flow_child = false
  for child in node.children {
    if child.style.display == @types.Display::None {
      children.push(create_zero_layout(child))
    } else if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      // Absolute/fixed children need to be laid out
      // Use dispatch to get proper sizing
      let child_ctx : @types.LayoutContext = {
        available_width,
        available_height,
        sizing_mode: @types.MaxContent,
        viewport_width: available_width,
        viewport_height: available_height.unwrap_or(0.0),
        stretch_width: false,
        stretch_height: false,
      }
      let @node.DispatchFn(dispatch_fn) = dispatch
      let child_layout = dispatch_fn(child, child_ctx, dispatch)
      let layout_index = children.length()
      children.push(child_layout)
      if child.style.position == @types.Absolute {
        let (static_x, static_y) = resolve_abs_static_position_in_inline(
          style,
          child.style,
          inline_cursor_x,
          inline_cursor_y,
          inline_line_height,
        )
        absolute_entries.push((layout_index, child, static_x, static_y))
      }
      saw_out_of_flow_child = true
      // Absolute children don't contribute to inline element's size
    } else if child.style.display == @types.Contents {
      // display: contents does not generate its own box, but its inline descendants
      // still participate in line layout and the wrapper node is kept for tree parity.
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )
      let contents_children : Array[@types.Layout] = []
      let mut contents_cursor_x = 0.0
      let mut contents_height = 0.0
      for grand_child in child.children {
        if grand_child.style.display == @types.Display::None {
          contents_children.push(create_zero_layout(grand_child))
        } else if grand_child.style.position == @types.Absolute ||
          grand_child.style.position == @types.Fixed {
          let child_ctx : @types.LayoutContext = {
            available_width,
            available_height,
            sizing_mode: @types.MaxContent,
            viewport_width: available_width,
            viewport_height: available_height.unwrap_or(0.0),
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          let grand_layout = dispatch_fn(grand_child, child_ctx, dispatch)
          contents_children.push(grand_layout)
          // Out-of-flow children don't contribute to inline progression
        } else if grand_child.style.display == @types.Contents ||
          is_inline_level(grand_child.style.display) {
          let raw_grand_layout = compute_inline_child(
            grand_child, available_width, available_height, dispatch,
          )
          let grand_margin = @types.resolve_rect(
            grand_child.style.margin,
            available_width,
          )
          let is_contents_grand = grand_child.style.display == @types.Contents
          let grand_layout = if is_contents_grand {
            {
              ..raw_grand_layout,
              width: 0.0,
              height: 0.0,
              padding: @types.Rect::zero(),
              border: @types.Rect::zero(),
              scroll_width: 0.0,
              scroll_height: 0.0,
            }
          } else {
            raw_grand_layout
          }
          let positioned_grand : @types.Layout = {
            ..grand_layout,
            x: contents_cursor_x + grand_margin.left,
            y: 0.0,
            margin: grand_margin,
          }
          contents_children.push(positioned_grand)
          contents_cursor_x = contents_cursor_x +
            grand_margin.left +
            raw_grand_layout.width +
            grand_margin.right
          if raw_grand_layout.height > contents_height &&
            not(is_ruby_annotation_child(node, grand_child)) {
            contents_height = raw_grand_layout.height
          }
        }
      }
      let positioned_contents : @types.Layout = {
        id: child.id,
        x: inline_cursor_x + child_margin.left,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: child_margin,
        padding: @types.Rect::zero(),
        border: @types.Rect::zero(),
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: contents_children,
        text: child.text,
      }
      children.push(positioned_contents)
      inline_cursor_x = inline_cursor_x +
        child_margin.left +
        contents_cursor_x +
        child_margin.right
      content_width = inline_cursor_x
      if contents_height > content_height {
        content_height = contents_height
      }
      saw_out_of_flow_child = false
    } else if is_inline_level(child.style.display) {
      // Recursively process inline children
      let raw_child_layout = compute_inline_child(
        child, available_width, available_height, dispatch,
      )
      let collapse_whitespace_after_out_of_flow = saw_out_of_flow_child &&
        is_whitespace_text_node(child)
      let collapse_standalone_whitespace = is_whitespace_text_node(child)
      let child_layout = if collapse_whitespace_after_out_of_flow {
        { ..raw_child_layout, width: 0.0, height: 0.0 }
      } else if collapse_standalone_whitespace {
        // Indentation whitespace should keep inline advance but not inflate line height.
        { ..raw_child_layout, height: 0.0 }
      } else {
        raw_child_layout
      }
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )
      let mut child_x = inline_cursor_x + child_margin.left
      let mut child_y = inline_cursor_y
      if child.style.position == @types.Relative {
        let rel_left = resolve_inset_dimension(
          child.style.inset.left,
          available_width,
        )
        let rel_right = resolve_inset_dimension(
          child.style.inset.right,
          available_width,
        )
        let rel_top = resolve_inset_dimension(
          child.style.inset.top,
          available_height.unwrap_or(0.0),
        )
        let rel_bottom = resolve_inset_dimension(
          child.style.inset.bottom,
          available_height.unwrap_or(0.0),
        )
        let x_offset = match (rel_left, rel_right) {
          (Some(l), Some(r)) => l - r
          (Some(l), None) => l
          (None, Some(r)) => -r
          _ => 0.0
        }
        let y_offset = match (rel_top, rel_bottom) {
          (Some(t), Some(b)) => t - b
          (Some(t), None) => t
          (None, Some(b)) => -b
          _ => 0.0
        }
        child_x = child_x + x_offset
        child_y = child_y + y_offset
      }
      let positioned_child : @types.Layout = {
        ..child_layout,
        x: child_x,
        y: child_y,
        margin: child_margin,
      }
      let positioned_child = adjust_inline_float_only_wrapper(
        positioned_child,
        child,
        style.writing_mode,
      )
      children.push(positioned_child)
      // Accumulate content size from flow children
      // For inline elements, children are laid out horizontally.
      // A <br> child forces a new line.
      if child.id == "br" {
        let line_width = inline_cursor_x +
          child_margin.left +
          child_layout.width +
          child_margin.right
        if line_width > max_line_width {
          max_line_width = line_width
        }
        let mut advance = inline_line_height
        if child_layout.height > advance {
          advance = child_layout.height
        }
        if advance <= 0.0 {
          advance = line_height_from_style(style)
        }
        inline_cursor_y = inline_cursor_y + advance
        inline_cursor_x = 0.0
        inline_line_height = 0.0
        content_height = inline_cursor_y
      } else {
        inline_cursor_x = inline_cursor_x +
          child_margin.left +
          child_layout.width +
          child_margin.right
        content_width = inline_cursor_x
        if child_layout.height > inline_line_height &&
          not(is_ruby_annotation_child(node, child)) {
          inline_line_height = child_layout.height
        }
        let line_bottom = inline_cursor_y + inline_line_height
        if line_bottom > content_height {
          content_height = line_bottom
        }
      }
      if not(collapse_whitespace_after_out_of_flow) {
        saw_out_of_flow_child = false
      }
    } else if is_ruby_internal_container(node.id) {
      // Ruby internal boxes can contain non-inline descendants in WPT fixtures.
      // Keep them in-flow as inline contributions instead of dropping them.
      let child_ctx : @types.LayoutContext = {
        available_width,
        available_height,
        sizing_mode: @types.MaxContent,
        viewport_width: available_width,
        viewport_height: available_height.unwrap_or(0.0),
        stretch_width: false,
        stretch_height: false,
      }
      let @node.DispatchFn(dispatch_fn) = dispatch
      let child_layout = dispatch_fn(child, child_ctx, dispatch)
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )
      let mut child_x = inline_cursor_x + child_margin.left
      let mut child_y = 0.0
      if child.style.position == @types.Relative {
        let rel_left = resolve_inset_dimension(
          child.style.inset.left,
          available_width,
        )
        let rel_right = resolve_inset_dimension(
          child.style.inset.right,
          available_width,
        )
        let rel_top = resolve_inset_dimension(
          child.style.inset.top,
          available_height.unwrap_or(0.0),
        )
        let rel_bottom = resolve_inset_dimension(
          child.style.inset.bottom,
          available_height.unwrap_or(0.0),
        )
        let x_offset = match (rel_left, rel_right) {
          (Some(l), Some(r)) => l - r
          (Some(l), None) => l
          (None, Some(r)) => -r
          _ => 0.0
        }
        let y_offset = match (rel_top, rel_bottom) {
          (Some(t), Some(b)) => t - b
          (Some(t), None) => t
          (None, Some(b)) => -b
          _ => 0.0
        }
        child_x = child_x + x_offset
        child_y = child_y + y_offset
      }
      let positioned_child : @types.Layout = {
        ..child_layout,
        x: child_x,
        y: child_y,
        margin: child_margin,
      }
      children.push(positioned_child)
      inline_cursor_x = inline_cursor_x +
        child_margin.left +
        child_layout.width +
        child_margin.right
      content_width = inline_cursor_x
      if child_layout.height > content_height &&
        not(is_ruby_annotation_child(node, child)) {
        content_height = child_layout.height
      }
      saw_out_of_flow_child = false
    } else {
      // Block-level children inside inline formatting context split line boxes.
      let child_ctx : @types.LayoutContext = {
        available_width,
        available_height,
        sizing_mode: @types.MaxContent,
        viewport_width: available_width,
        viewport_height: available_height.unwrap_or(0.0),
        stretch_width: false,
        stretch_height: false,
      }
      let @node.DispatchFn(dispatch_fn) = dispatch
      let child_layout_raw = dispatch_fn(child, child_ctx, dispatch)
      let child_layout = if child_layout_raw.width <= 0.0 &&
        not(style.writing_mode.is_vertical()) {
        { ..child_layout_raw, width: available_width }
      } else {
        child_layout_raw
      }
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )

      if inline_cursor_x > 0.0 {
        let mut advance = inline_line_height
        if advance <= 0.0 {
          advance = line_height_from_style(style)
        }
        inline_cursor_y = inline_cursor_y + advance
        inline_cursor_x = 0.0
        inline_line_height = 0.0
      }

      let mut child_x = child_margin.left
      let mut child_y = inline_cursor_y + child_margin.top
      if child.style.position == @types.Relative {
        let rel_left = resolve_inset_dimension(
          child.style.inset.left,
          available_width,
        )
        let rel_right = resolve_inset_dimension(
          child.style.inset.right,
          available_width,
        )
        let rel_top = resolve_inset_dimension(
          child.style.inset.top,
          available_height.unwrap_or(0.0),
        )
        let rel_bottom = resolve_inset_dimension(
          child.style.inset.bottom,
          available_height.unwrap_or(0.0),
        )
        let x_offset = match (rel_left, rel_right) {
          (Some(l), Some(r)) => l - r
          (Some(l), None) => l
          (None, Some(r)) => -r
          _ => 0.0
        }
        let y_offset = match (rel_top, rel_bottom) {
          (Some(t), Some(b)) => t - b
          (Some(t), None) => t
          (None, Some(b)) => -b
          _ => 0.0
        }
        child_x = child_x + x_offset
        child_y = child_y + y_offset
      }
      let positioned_child : @types.Layout = {
        ..child_layout,
        x: child_x,
        y: child_y,
        margin: child_margin,
      }
      children.push(positioned_child)

      let block_advance = child_margin.top +
        child_layout.height +
        child_margin.bottom
      inline_cursor_y = inline_cursor_y + block_advance
      inline_cursor_x = 0.0
      inline_line_height = 0.0
      if inline_cursor_y > content_height {
        content_height = inline_cursor_y
      }
      if child_layout.height > 0.0 {
        let block_width = child_margin.left +
          child_layout.width +
          child_margin.right
        if block_width > max_line_width {
          max_line_width = block_width
        }
      }
      saw_out_of_flow_child = false
    }
    // Block-level children in inline context are not supported (would need anonymous blocks)
  }

  if inline_cursor_x > max_line_width {
    max_line_width = inline_cursor_x
  }
  if max_line_width > content_width {
    content_width = max_line_width
  }
  let last_line_bottom = inline_cursor_y + inline_line_height
  if last_line_bottom > content_height {
    content_height = last_line_bottom
  }

  // Calculate final width and height
  // For inline elements, content width is the sum of children widths
  // Content height is the maximum child height
  let mut final_width = content_width +
    padding.horizontal_sum() +
    border.horizontal_sum()
  let mut final_height = content_height +
    padding.vertical_sum() +
    border.vertical_sum()
  let text_glyph_height = max_text_glyph_height_in_node(node)
  if text_glyph_height > 0.0 {
    let text_box_height = text_glyph_height +
      padding.vertical_sum() +
      border.vertical_sum()
    let has_forced_line_break = inline_cursor_y > 0.0
    if not(has_forced_line_break) && final_height > text_box_height {
      final_height = text_box_height
    }
  }
  let ruby_annotation_only_box = ruby_annotation_only(node)
  let ruby_collapsed = id_matches_tag(node.id, "ruby") &&
    ruby_annotation_only_should_collapse(node)
  if ruby_collapsed {
    final_width = padding.horizontal_sum() + border.horizontal_sum()
    final_height = padding.vertical_sum() + border.vertical_sum()
  } else if ruby_annotation_only_box {
    final_height = line_height_from_style(style) +
      padding.vertical_sum() +
      border.vertical_sum()
  } else if final_height == 0.0 &&
    id_matches_tag(node.id, "ruby") &&
    ruby_has_rt_child(node) {
    final_height = if style.font_size > 0.0 { style.font_size } else { 16.0 }
  }
  if final_height == 0.0 && id_matches_tag(node.id, "source") {
    final_height = text_glyph_height_from_style(style)
  }
  let node_has_non_ws_text_desc = if absolute_entries.length() > 0 &&
    inline_cursor_y == 0.0 &&
    not(style.writing_mode.is_vertical()) {
    has_non_whitespace_text_descendant(node)
  } else {
    false
  }
  if not(style.writing_mode.is_vertical()) &&
    absolute_entries.length() > 0 &&
    inline_cursor_y == 0.0 &&
    not(node_has_non_ws_text_desc) {
    let horizontal_inline_line_height = line_height_from_style(style) +
      padding.vertical_sum() +
      border.vertical_sum()
    if final_height > horizontal_inline_line_height {
      final_height = horizontal_inline_line_height
    }
  }
  if style.writing_mode.is_vertical() && absolute_entries.length() > 0 {
    let vertical_inline_line_height = line_height_from_style(style) +
      padding.vertical_sum() +
      border.vertical_sum()
    if final_height > vertical_inline_line_height {
      final_height = vertical_inline_line_height
    }
  }

  // Keep static-position baseline fallback for abspos descendants when this
  // inline box is not their containing block.
  for entry in absolute_entries {
    let (idx, abs_child, static_x, static_y) = entry
    let left_auto = match abs_child.style.inset.left {
      @types.Auto => true
      _ => false
    }
    let right_auto = match abs_child.style.inset.right {
      @types.Auto => true
      _ => false
    }
    let top_auto = match abs_child.style.inset.top {
      @types.Auto => true
      _ => false
    }
    let bottom_auto = match abs_child.style.inset.bottom {
      @types.Auto => true
      _ => false
    }
    if top_auto && bottom_auto {
      let abs_layout = children[idx]
      children[idx] = { ..abs_layout, y: static_y }
    }
    if left_auto && right_auto {
      let abs_layout = children[idx]
      children[idx] = { ..abs_layout, x: static_x }
    }
  }

  // Resolve absolute child positions against this inline element's content box
  // only when this inline box establishes a containing block.
  let mut node_has_inflow_block_desc = false
  let mut node_has_inflow_block_desc_computed = false
  if absolute_entries.length() > 0 &&
    inline_establishes_abs_containing_block(style) {
    node_has_inflow_block_desc = has_inflow_block_descendant(node)
    node_has_inflow_block_desc_computed = true
    let area_left = padding.left + border.left
    let area_top_adjust = if node_has_inflow_block_desc {
      -line_height_from_style(style)
    } else {
      0.0
    }
    let area_top = padding.top + border.top + area_top_adjust
    let area_width_raw = final_width -
      padding.horizontal_sum() -
      border.horizontal_sum()
    let area_height_raw = final_height -
      padding.vertical_sum() -
      border.vertical_sum()
    let area_width = if area_width_raw > 0.0 { area_width_raw } else { 0.0 }
    let area_height = if area_height_raw > 0.0 { area_height_raw } else { 0.0 }
    for entry in absolute_entries {
      let (idx, abs_child, static_x, static_y) = entry
      let abs_layout = children[idx]
      let child_style = abs_child.style
      let inset_left = resolve_inset_dimension(
        child_style.inset.left,
        area_width,
      )
      let inset_right = resolve_inset_dimension(
        child_style.inset.right,
        area_width,
      )
      let inset_top = resolve_inset_dimension(
        child_style.inset.top,
        area_height,
      )
      let inset_bottom = resolve_inset_dimension(
        child_style.inset.bottom,
        area_height,
      )
      let x = match (inset_left, inset_right) {
        (Some(l), _) => area_left + l
        (None, Some(r)) => area_left + area_width - r - abs_layout.width
        (None, None) => area_left + static_x
      }
      let y = match (inset_top, inset_bottom) {
        (Some(t), _) => area_top + t
        (None, Some(b)) => area_top + area_height - b - abs_layout.height
        (None, None) => area_top + static_y
      }
      children[idx] = { ..abs_layout, x, y }
    }
  }
  let mut has_zero_size_div_child = false
  for child_layout in children {
    if child_layout.id == "div" &&
      child_layout.width == 0.0 &&
      child_layout.height == 0.0 {
      has_zero_size_div_child = true
      break
    }
  }
  if has_zero_size_div_child {
    if not(node_has_inflow_block_desc_computed) {
      node_has_inflow_block_desc = has_inflow_block_descendant(node)
      node_has_inflow_block_desc_computed = true
    }
    if node_has_inflow_block_desc {
      for i = 0; i < children.length(); i = i + 1 {
        let child_layout = children[i]
        if child_layout.id == "div" &&
          child_layout.width == 0.0 &&
          child_layout.height == 0.0 {
          children[i] = { ..child_layout, width: available_width }
        }
      }
    }
  }
  if ruby_annotation_only_box && not(ruby_collapsed) {
    for i = 0; i < children.length(); i = i + 1 {
      let child_layout = children[i]
      if id_matches_tag(child_layout.id, "rt") ||
        id_matches_tag(child_layout.id, "rtc") {
        children[i] = {
          ..child_layout,
          y: child_layout.y - child_layout.height,
        }
      }
    }
  }

  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: final_width,
    height: final_height,
    margin: @types.Rect::zero(),
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Create a zero-sized layout for display:none nodes
fn create_zero_layout(node : @node.Node) -> @types.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout(node.children[i]))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Check if a node is inline-level (inline or inline-block)
pub fn is_inline_level(display : @types.Display) -> Bool {
  match display {
    @types.Inline
    | @types.InlineBlock
    | @types.InlineFlex
    | @types.InlineGrid => true
    _ => false
  }
}

///|
/// Check if children should establish an IFC
/// Returns true if all non-absolute children are inline-level
pub fn should_establish_ifc(children : Array[@node.Node]) -> Bool {
  if children.length() == 0 {
    return false
  }
  let mut has_inline = false
  for child in children {
    // Skip absolute positioned children
    if child.style.position == @types.Absolute {
      continue
    }
    // Skip display:none
    if child.style.display == @types.Display::None {
      continue
    }
    if child.id == "br" || child.id.has_prefix("#text") {
      has_inline = true
      continue
    }
    if is_inline_level(child.style.display) {
      has_inline = true
    } else {
      // Found a block-level child, no IFC
      return false
    }
  }
  has_inline
}

///|
pub fn actual_paint_layout_content_right(
  layout : @layout_types.Layout,
) -> Double {
  let mut right = layout.x + layout.width
  match layout.overflow_x {
    @types.Visible => {
      let scroll_right = layout.x + layout.scroll_width
      if scroll_right > right {
        right = scroll_right
      }
      for child in layout.children {
        let child_right = actual_paint_layout_content_right(child)
        if child_right > right {
          right = child_right
        }
      }
    }
    _ => ()
  }
  right
}

///|
pub fn actual_paint_layout_content_bottom(
  layout : @layout_types.Layout,
) -> Double {
  let mut bottom = layout.y + layout.height
  match layout.overflow_y {
    @types.Visible => {
      let scroll_bottom = layout.y + layout.scroll_height
      if scroll_bottom > bottom {
        bottom = scroll_bottom
      }
      for child in layout.children {
        let child_bottom = actual_paint_layout_content_bottom(child)
        if child_bottom > bottom {
          bottom = child_bottom
        }
      }
    }
    _ => ()
  }
  bottom
}

///|
pub fn actual_paint_document_dimensions_from_node_and_layout(
  node : @node.Node,
  layout : @layout_types.Layout,
  viewport_width : Int,
  viewport_height : Int,
) -> (Int, Int) {
  let width = actual_paint_node_layout_content_right(node, layout)
    .ceil()
    .to_int()
  let height = actual_paint_node_layout_content_bottom(node, layout)
    .ceil()
    .to_int()
  (width.max(viewport_width).max(1), height.max(viewport_height).max(1))
}

///|
pub fn should_use_font_aware_text_provider(font_family : String) -> Bool {
  let normalized = font_family.trim().to_lower()
  normalized.length() > 0 &&
  normalized != "inherit" &&
  normalized != "initial" &&
  normalized != "unset" &&
  normalized != "revert" &&
  normalized != "revert-layer"
}

///|
pub fn parse_text_metrics_quad(
  value : String,
) -> (Double, Double, Double, Double)? {
  let parts = value.split(",").collect()
  if parts.length() < 4 {
    return None
  }
  let min_width = @string.parse_double(parts[0]) catch { _ => return None }
  let max_width = @string.parse_double(parts[1]) catch { _ => return None }
  let min_height = @string.parse_double(parts[2]) catch { _ => return None }
  let max_height = @string.parse_double(parts[3]) catch { _ => return None }
  Some((min_width, max_width, min_height, max_height))
}

///|
pub fn resolve_text_intrinsic_size_from_provider_payload(
  payload : String,
  text : String,
  font_size : Double,
  line_height : Double,
) -> @layout_types.IntrinsicSize {
  match parse_text_metrics_quad(payload) {
    Some((min_width, max_width, min_height, max_height)) =>
      { min_width, max_width, min_height, max_height }
    None => fallback_text_intrinsic_size(text, font_size, line_height)
  }
}

///|
fn fallback_text_intrinsic_size(
  text : String,
  font_size : Double,
  line_height : Double,
) -> @layout_types.IntrinsicSize {
  let mut columns = 0
  for _ in text.iter() {
    columns = columns + 1
  }
  let cell_width = if font_size > 0.0 { font_size * 0.5 } else { 8.0 }
  let width = columns.to_double() * cell_width
  let height = if line_height > 0.0 {
    line_height
  } else if font_size > 0.0 {
    font_size
  } else {
    16.0
  }
  { min_width: width, max_width: width, min_height: height, max_height: height }
}

///|
pub fn parse_glyph_outline_commands_json(
  json_text : String,
) -> Array[@svg.PathCommand] {
  let commands : Array[@svg.PathCommand] = []
  let parsed = @json.parse(json_text) catch { _ => return commands }
  guard parsed is Array(items) else { return commands }
  for item in items {
    match parse_glyph_outline_command_json(item) {
      Some(command) => commands.push(command)
      None => ()
    }
  }
  commands
}

///|
fn parse_glyph_outline_command_json(item : Json) -> @svg.PathCommand? {
  guard item is Array(parts) else { return None }
  if parts.length() == 0 {
    return None
  }
  guard parts[0] is String(command) else { return None }
  match command {
    "M" => {
      let (x, y) = match parse_outline_xy(parts, 1, 2) {
        Some(value) => value
        None => return None
      }
      Some(@svg.MoveTo(x, y))
    }
    "L" => {
      let (x, y) = match parse_outline_xy(parts, 1, 2) {
        Some(value) => value
        None => return None
      }
      Some(@svg.LineTo(x, y))
    }
    "Q" => {
      let (cx, cy) = match parse_outline_xy(parts, 1, 2) {
        Some(value) => value
        None => return None
      }
      let (x, y) = match parse_outline_xy(parts, 3, 4) {
        Some(value) => value
        None => return None
      }
      Some(@svg.QuadraticCurveTo(cx, cy, x, y))
    }
    "C" => {
      let (cx1, cy1) = match parse_outline_xy(parts, 1, 2) {
        Some(value) => value
        None => return None
      }
      let (cx2, cy2) = match parse_outline_xy(parts, 3, 4) {
        Some(value) => value
        None => return None
      }
      let (x, y) = match parse_outline_xy(parts, 5, 6) {
        Some(value) => value
        None => return None
      }
      Some(@svg.CurveTo(cx1, cy1, cx2, cy2, x, y))
    }
    "Z" => Some(@svg.ClosePath)
    _ => None
  }
}

///|
fn parse_outline_xy(
  parts : Array[Json],
  x_index : Int,
  y_index : Int,
) -> (Double, Double)? {
  if parts.length() <= x_index || parts.length() <= y_index {
    return None
  }
  guard parts[x_index] is Number(x, ..) else { return None }
  guard parts[y_index] is Number(y, ..) else { return None }
  Some((x, y))
}

///|
pub fn can_use_actual_paint_for_screenshot_data(
  params : Map[String, Json],
) -> Bool {
  match params.get("backend") {
    Some(String("synthetic")) => return false
    _ => ()
  }
  match params.get("origin") {
    None | Some(String("viewport")) | Some(String("document")) => ()
    _ => return false
  }
  match params.get("clip") {
    None => ()
    _ => return false
  }
  match params.get("format") {
    None => true
    Some(Object(format)) =>
      match format.get("type") {
        None | Some(String("image/png")) => true
        _ => false
      }
    _ => false
  }
}

///|
pub fn normalize_capture_paint_data_options(
  params : Map[String, Json],
) -> Result[String, RenderingValidationError] {
  match params.get("html") {
    None | Some(String(_)) => ()
    Some(_) => return Err(InvalidArgument("html must be a string"))
  }
  match params.get("origin") {
    None | Some(String("viewport")) => Ok("viewport")
    Some(String(_)) =>
      Err(
        UnsupportedOperation(
          "capturePaintData currently supports only origin='viewport'",
        ),
      )
    Some(_) => Err(InvalidArgument("origin must be 'viewport'"))
  }
}

///|
pub fn normalize_capture_paint_tree_options(
  params : Map[String, Json],
) -> Result[String, RenderingValidationError] {
  match params.get("origin") {
    None | Some(String("viewport")) => Ok("viewport")
    Some(String("document")) => Ok("document")
    Some(String(_)) =>
      Err(InvalidArgument("origin must be 'viewport' or 'document'"))
    Some(_) => Err(InvalidArgument("origin must be a string"))
  }
}

///|
fn actual_paint_node_contributes_document_overflow(node : @node.Node) -> Bool {
  node.style.position != @types.Fixed
}

///|
fn actual_paint_node_subtree_has_fixed_positioned(node : @node.Node) -> Bool {
  if node.style.position == @types.Fixed {
    return true
  }
  for child in node.children {
    if actual_paint_node_subtree_has_fixed_positioned(child) {
      return true
    }
  }
  false
}

///|
fn actual_paint_node_layout_child(
  node : @node.Node,
  index : Int,
) -> @node.Node? {
  if index < node.children.length() {
    Some(node.children[index])
  } else {
    None
  }
}

///|
fn actual_paint_node_layout_content_right(
  node : @node.Node,
  layout : @layout_types.Layout,
) -> Double {
  if !actual_paint_node_contributes_document_overflow(node) {
    return 0.0
  }
  let mut right = layout.x + layout.width
  match layout.overflow_x {
    @types.Visible => {
      if !actual_paint_node_subtree_has_fixed_positioned(node) {
        let scroll_right = layout.x + layout.scroll_width
        if scroll_right > right {
          right = scroll_right
        }
      }
      for i, child_layout in layout.children {
        let child_right = match actual_paint_node_layout_child(node, i) {
          Some(child_node) =>
            actual_paint_node_layout_content_right(child_node, child_layout)
          None => actual_paint_layout_content_right(child_layout)
        }
        if child_right > right {
          right = child_right
        }
      }
    }
    _ => ()
  }
  right
}

///|
fn actual_paint_node_layout_content_bottom(
  node : @node.Node,
  layout : @layout_types.Layout,
) -> Double {
  if !actual_paint_node_contributes_document_overflow(node) {
    return 0.0
  }
  let collapsed_top_margin = if layout.y == 0.0 && layout.margin.top > 0.0 {
    layout.margin.top
  } else {
    0.0
  }
  let mut bottom = layout.y +
    collapsed_top_margin +
    layout.height +
    layout.margin.bottom
  match layout.overflow_y {
    @types.Visible => {
      if !actual_paint_node_subtree_has_fixed_positioned(node) {
        let scroll_bottom = layout.y + layout.scroll_height
        if scroll_bottom > bottom {
          bottom = scroll_bottom
        }
      }
      for i, child_layout in layout.children {
        let child_bottom = match actual_paint_node_layout_child(node, i) {
          Some(child_node) =>
            actual_paint_node_layout_content_bottom(child_node, child_layout)
          None => actual_paint_layout_content_bottom(child_layout)
        }
        if child_bottom > bottom {
          bottom = child_bottom
        }
      }
    }
    _ => ()
  }
  bottom
}

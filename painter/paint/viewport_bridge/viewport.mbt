// =============================================================================
// Paint Viewport Bridge Package - Viewport-aware layout/style to PaintNode conversion
// =============================================================================

///|
fn inherit_text_paint(
  parent : @model.PaintProperties,
  child : @model.PaintProperties,
) -> @model.PaintProperties {
  {
    ..child,
    is_bold: child.is_bold || parent.is_bold,
    text_decoration_underline: child.text_decoration_underline ||
    parent.text_decoration_underline,
    text_decoration_line_through: child.text_decoration_line_through ||
    parent.text_decoration_line_through,
    text_decoration_overline: child.text_decoration_overline ||
    parent.text_decoration_overline,
  }
}

///|
fn extract_tag_from_id(id : String) -> String {
  if id == "#text" {
    return "#text"
  }
  let mut end_pos : Int? = None
  for i, c in id {
    if c == '#' || c == '.' {
      end_pos = Some(i)
      break
    }
  }
  match end_pos {
    Some(pos) => id.unsafe_substring(start=0, end=pos)
    None => id
  }
}

///|
fn is_ignorable_whitespace_text_node(node : @layout.Node) -> Bool {
  if node.id != "#text" {
    return false
  }
  match node.text {
    Some(text) => text.trim().length() == 0
    None => false
  }
}

///|
fn generate_list_marker(parent_tag : String, child_index : Int) -> String? {
  match parent_tag {
    "ul" => Some("\u{2022}")
    "ol" => Some((child_index + 1).to_string() + ".")
    _ => None
  }
}

///|
fn should_apply_text_overflow_ellipsis(
  style : @style.Style,
  layout : @types.Layout,
) -> Bool {
  style.text_overflow == @style.TextOverflow::Ellipsis &&
  style.white_space == @style.WhiteSpace::Nowrap &&
  layout.width > 0.0 &&
  (layout.overflow_x != @types.Visible || layout.overflow_y != @types.Visible)
}

///|
fn resolve_text_overflow_char_width(style : @style.Style) -> Double {
  let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
  if style.font_family.to_lower().contains("ahem") {
    font_size
  } else {
    font_size * 0.5
  }
}

///|
fn truncate_text_with_ellipsis(
  text : String,
  max_width : Double,
  char_width : Double,
) -> String {
  if char_width <= 0.0 {
    return text
  }
  let max_chars = (max_width / char_width).to_int()
  if max_chars <= 0 {
    return ""
  }
  if text.length().to_double() * char_width <= max_width {
    return text
  }
  if max_chars <= 3 {
    return "..."
  }
  let keep_chars = max_chars - 3
  let mut result = ""
  let mut count = 0
  for c in text {
    if count >= keep_chars {
      break
    }
    result = result + c.to_string()
    count += 1
  }
  result + "..."
}

///|
fn clamp_to_available_width(width : Double, available_width : Double) -> Double {
  if width > available_width {
    available_width
  } else {
    width
  }
}

///|
fn apply_text_overflow_ellipsis_to_subtree(
  paint_node : @model.PaintNode,
  source_node : @layout.Node,
  available_width : Double,
) -> @model.PaintNode {
  if source_node.id == "#text" {
    match paint_node.text {
      Some(text) => {
        let truncated = truncate_text_with_ellipsis(
          text,
          available_width,
          resolve_text_overflow_char_width(source_node.style),
        )
        return {
          ..paint_node,
          width: clamp_to_available_width(paint_node.width, available_width),
          text: Some(truncated),
        }
      }
      None => return paint_node
    }
  }
  if paint_node.children.length() == 1 && source_node.children.length() == 1 {
    let updated_child = apply_text_overflow_ellipsis_to_subtree(
      paint_node.children[0],
      source_node.children[0],
      available_width,
    )
    return {
      ..paint_node,
      width: clamp_to_available_width(paint_node.width, available_width),
      children: [updated_child],
    }
  }
  paint_node
}

///|
priv struct ExtentNode {
  relative_left : Double
  relative_top : Double
  relative_right : Double
  relative_bottom : Double
  children : Array[ExtentNode]
}

///|
fn precompute_extent_tree(layout : @types.Layout) -> ExtentNode {
  let children : Array[ExtentNode] = Array::new(
    capacity=layout.children.length(),
  )
  let mut left = 0.0
  let mut top = 0.0
  let mut right = layout.width
  let mut bottom = layout.height
  for child in layout.children {
    let child_node = precompute_extent_tree(child)
    let child_left = child.x + child_node.relative_left
    let child_top = child.y + child_node.relative_top
    let child_right = child.x + child_node.relative_right
    let child_bottom = child.y + child_node.relative_bottom
    if child_left < left {
      left = child_left
    }
    if child_top < top {
      top = child_top
    }
    if child_right > right {
      right = child_right
    }
    if child_bottom > bottom {
      bottom = child_bottom
    }
    children.push(child_node)
  }
  {
    relative_left: left,
    relative_top: top,
    relative_right: right,
    relative_bottom: bottom,
    children,
  }
}

///|
priv struct CullRect {
  left : Double
  top : Double
  right : Double
  bottom : Double
}

///|
fn cull_rect_intersects(a : CullRect, b : CullRect) -> Bool {
  a.right > b.left && a.left < b.right && a.bottom > b.top && a.top < b.bottom
}

///|
fn cull_rect_intersection(a : CullRect, b : CullRect) -> CullRect? {
  let left = if a.left > b.left { a.left } else { b.left }
  let top = if a.top > b.top { a.top } else { b.top }
  let right = if a.right < b.right { a.right } else { b.right }
  let bottom = if a.bottom < b.bottom { a.bottom } else { b.bottom }
  if right > left && bottom > top {
    Some({ left, top, right, bottom })
  } else {
    None
  }
}

///|
fn layout_overflow_clips(layout : @types.Layout) -> Bool {
  match (layout.overflow_x, layout.overflow_y) {
    (@types.Visible, @types.Visible) => false
    _ => true
  }
}

///|
fn node_clip_rect(
  abs_x : Double,
  abs_y : Double,
  layout : @types.Layout,
  clip : @types.ClipRect,
) -> CullRect? {
  let overflow_clip = if layout_overflow_clips(layout) {
    Some({
      left: abs_x,
      top: abs_y,
      right: abs_x + layout.width,
      bottom: abs_y + layout.height,
    })
  } else {
    None
  }
  let legacy_clip = match clip {
    @types.ClipRect::Auto => None
    @types.ClipRect::Rect(top~, right~, bottom~, left~) =>
      Some({
        left: abs_x + left,
        top: abs_y + top,
        right: abs_x + right,
        bottom: abs_y + bottom,
      })
  }
  match (overflow_clip, legacy_clip) {
    (Some(a), Some(b)) => cull_rect_intersection(a, b)
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
fn subtree_rect(
  layout : @types.Layout,
  extent : ExtentNode,
  parent_x : Double,
  parent_y : Double,
) -> CullRect {
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  {
    left: abs_x + extent.relative_left,
    top: abs_y + extent.relative_top,
    right: abs_x + extent.relative_right,
    bottom: abs_y + extent.relative_bottom,
  }
}

///|
fn paint_node_rect(node : @model.PaintNode) -> CullRect {
  {
    left: node.x,
    top: node.y,
    right: node.x + node.width,
    bottom: node.y + node.height,
  }
}

///|
fn cull_rect_covers(cover : CullRect, target : CullRect) -> Bool {
  let eps = 0.001
  cover.left <= target.left + eps &&
  cover.top <= target.top + eps &&
  cover.right + eps >= target.right &&
  cover.bottom + eps >= target.bottom
}

///|
fn node_has_square_corners(node : @model.PaintNode) -> Bool {
  node.paint.border_top_left_radius <= 0.0 &&
  node.paint.border_top_right_radius <= 0.0 &&
  node.paint.border_bottom_right_radius <= 0.0 &&
  node.paint.border_bottom_left_radius <= 0.0
}

///|
fn node_has_no_clip_path(node : @model.PaintNode) -> Bool {
  match node.paint.clip_path {
    @style.ClipPath::None => true
    _ => false
  }
}

///|
fn node_accepts_pointer_events(node : @model.PaintNode) -> Bool {
  match node.paint.pointer_events {
    @style.PointerEvents::Auto => true
    @style.PointerEvents::None => false
  }
}

///|
fn node_paints_opaque_rect(node : @model.PaintNode) -> Bool {
  node.paint.opacity >= 1.0 &&
  node.paint.background_color.is_opaque() &&
  node.paint.box_shadows.length() == 0 &&
  node.visual_polygon.length() == 0 &&
  node_has_square_corners(node) &&
  node_has_no_clip_path(node) &&
  node_accepts_pointer_events(node) &&
  !node.has_legacy_clip() &&
  node.width > 0.0 &&
  node.height > 0.0
}

///|
fn node_can_be_pruned_when_covered(node : @model.PaintNode) -> Bool {
  node.children.length() == 0 &&
  node.paint.box_shadows.length() == 0 &&
  node.visual_polygon.length() == 0 &&
  node.width > 0.0 &&
  node.height > 0.0
}

///|
fn prune_fully_covered_children(
  children : Array[@model.PaintNode],
) -> Array[@model.PaintNode] {
  if children.length() <= 1 {
    return children
  }
  let pruned : Array[@model.PaintNode] = []
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let mut covered = false
    if node_can_be_pruned_when_covered(child) {
      let child_rect = paint_node_rect(child)
      for j = i + 1; j < children.length(); j = j + 1 {
        let cover = children[j]
        if cover.stacking_order >= child.stacking_order &&
          node_paints_opaque_rect(cover) &&
          cull_rect_covers(paint_node_rect(cover), child_rect) {
          covered = true
          break
        }
      }
    }
    if !covered {
      pruned.push(child)
    }
  }
  pruned
}

///|
pub fn from_node_and_layout_with_viewport(
  node : @layout.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> @model.PaintNode? {
  let wide = 1000000000.0
  from_node_and_layout_with_viewport_rect(
    node,
    layout,
    -wide,
    viewport_top,
    wide,
    viewport_bottom,
    0.0,
    parent_y,
  )
}

///|
pub fn from_node_and_layout_with_viewport_rect(
  node : @layout.Node,
  layout : @types.Layout,
  viewport_left : Double,
  viewport_top : Double,
  viewport_right : Double,
  viewport_bottom : Double,
  parent_x : Double,
  parent_y : Double,
) -> @model.PaintNode? {
  let extent_tree = precompute_extent_tree(layout)
  let viewport = {
    left: viewport_left,
    top: viewport_top,
    right: viewport_right,
    bottom: viewport_bottom,
  }
  from_node_and_layout_with_viewport_inner(
    node, layout, extent_tree, viewport, parent_x, parent_y,
  )
}

///|
fn from_node_and_layout_with_viewport_inner(
  node : @layout.Node,
  layout : @types.Layout,
  extent : ExtentNode,
  clip_rect : CullRect,
  parent_x : Double,
  parent_y : Double,
) -> @model.PaintNode? {
  if !cull_rect_intersects(
      subtree_rect(layout, extent, parent_x, parent_y),
      clip_rect,
    ) {
    return None
  }
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  let mut paint = @model.PaintProperties::from_style(node.style)
  paint = {
    ..paint,
    border_top_width: layout.border.top,
    border_right_width: layout.border.right,
    border_bottom_width: layout.border.bottom,
    border_left_width: layout.border.left,
  }
  let tag = extract_tag_from_id(node.id)
  let children : Array[@model.PaintNode] = []
  let child_clip = match node_clip_rect(abs_x, abs_y, layout, node.style.clip) {
    Some(node_clip) => cull_rect_intersection(clip_rect, node_clip)
    None => Some(clip_rect)
  }

  let extent_count = extent.children.length()
  let mut node_index = 0
  let mut layout_index = 0
  while node_index < node.children.length() &&
        layout_index < layout.children.length() {
    if is_ignorable_whitespace_text_node(node.children[node_index]) {
      node_index += 1
      continue
    }
    let child_node = node.children[node_index]
    let child_layout = layout.children[layout_index]
    let child_extent = if layout_index < extent_count {
      extent.children[layout_index]
    } else {
      {
        relative_left: 0.0,
        relative_top: 0.0,
        relative_right: child_layout.width,
        relative_bottom: child_layout.height,
        children: [],
      }
    }
    match child_clip {
      Some(active_clip) =>
        match
          from_node_and_layout_with_viewport_inner(
            child_node, child_layout, child_extent, active_clip, abs_x, abs_y,
          ) {
          Some(child) => {
            let mut current = {
              ..child,
              paint: inherit_text_paint(paint, child.paint),
            }
            let child_tag = extract_tag_from_id(child_node.id)
            if child_tag == "li" {
              match generate_list_marker(tag, layout_index) {
                Some(marker_text) => {
                  let marker_paint = {
                    ..current.paint,
                    font_size: current.paint.font_size,
                  }
                  let marker_node = @model.PaintNode::new(
                    "#list-marker",
                    "#text",
                    -current.paint.font_size * 1.2,
                    0.0,
                    current.paint.font_size * 1.2,
                    current.paint.font_size,
                    marker_paint,
                    [],
                    text=Some(marker_text),
                  )
                  current = {
                    ..current,
                    children: {
                      let new_children = current.children.copy()
                      new_children.push(marker_node)
                      new_children
                    },
                  }
                }
                None => ()
              }
            }
            if should_apply_text_overflow_ellipsis(node.style, layout) {
              current = apply_text_overflow_ellipsis_to_subtree(
                current,
                child_node,
                layout.width,
              )
            }
            children.push(current)
          }
          None => ()
        }
      None => ()
    }
    node_index += 1
    layout_index += 1
  }
  if tag == "img" {
    if paint.background_color.is_transparent() {
      paint = { ..paint, background_color: @types.Color::rgb(240, 240, 240) }
    }
    match layout.text {
      Some(alt) =>
        if children.is_empty() && alt.length() > 0 {
          let alt_paint = {
            ..@model.PaintProperties::default(),
            color: @types.Color::rgb(128, 128, 128),
            font_size: paint.font_size,
          }
          children.push(
            @model.PaintNode::new(
              "#text",
              "#text",
              0.0,
              0.0,
              layout.width,
              layout.height,
              alt_paint,
              [],
              text=Some(alt),
            ),
          )
        }
      None => ()
    }
  }
  let transform = node.style.transform
  let translate_x = transform.compute_translate_x(layout.width)
  let translate_y = transform.compute_translate_y(layout.height)
  let scaled_width = layout.width * transform.scale_x.abs()
  let scaled_height = layout.height * transform.scale_y.abs()
  let (paint_x, paint_y, paint_width, paint_height, visual_polygon) = visual_transform_bounds(
    layout.x + translate_x,
    layout.y + translate_y,
    scaled_width,
    scaled_height,
    transform,
  )
  let paint_children = prune_fully_covered_children(children)
  Some(
    @model.PaintNode::new(
      node.id,
      tag,
      paint_x,
      paint_y,
      paint_width,
      paint_height,
      paint,
      paint_children,
      text=layout.text,
      src=node.src,
      overflow_x=layout.overflow_x,
      overflow_y=layout.overflow_y,
      clip=node.style.clip,
      visual_polygon~,
    ),
  )
}

///|
fn visual_transform_bounds(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  transform : @style.Transform,
) -> (Double, Double, Double, Double, Array[(Double, Double)]) {
  if transform.has_skew() || transform.has_affine_matrix() {
    visual_affine_transform_bounds(x, y, width, height, transform)
  } else {
    match transform.quarter_turns() {
      0 | 2 => (x, y, width, height, [])
      1 | 3 =>
        (
          x + (width - height) / 2.0,
          y + (height - width) / 2.0,
          height,
          width,
          [],
        )
      _ => visual_affine_transform_bounds(x, y, width, height, transform)
    }
  }
}

///|
fn visual_affine_transform_bounds(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  transform : @style.Transform,
) -> (Double, Double, Double, Double, Array[(Double, Double)]) {
  if width <= 0.0 || height <= 0.0 {
    return (x, y, width, height, [])
  }
  let radians = transform.rotate_degrees * 3.14159265358979323846 / 180.0
  let cos_a = @math.cos(radians)
  let sin_a = @math.sin(radians)
  let skew_x = @math.tan(
    transform.skew_x_degrees * 3.14159265358979323846 / 180.0,
  )
  let skew_y = @math.tan(
    transform.skew_y_degrees * 3.14159265358979323846 / 180.0,
  )
  let matrix_a = if transform.has_matrix { transform.matrix_a } else { 1.0 }
  let matrix_b = if transform.has_matrix { transform.matrix_b } else { 0.0 }
  let matrix_c = if transform.has_matrix { transform.matrix_c } else { 0.0 }
  let matrix_d = if transform.has_matrix { transform.matrix_d } else { 1.0 }
  let matrix_e = if transform.has_matrix { transform.matrix_e } else { 0.0 }
  let matrix_f = if transform.has_matrix { transform.matrix_f } else { 0.0 }
  let center_x = x + width / 2.0
  let center_y = y + height / 2.0
  let points : Array[(Double, Double)] = [
    transform_point(
      x, y, center_x, center_y, cos_a, sin_a, skew_x, skew_y, matrix_a, matrix_b,
      matrix_c, matrix_d, matrix_e, matrix_f,
    ),
    transform_point(
      x + width,
      y,
      center_x,
      center_y,
      cos_a,
      sin_a,
      skew_x,
      skew_y,
      matrix_a,
      matrix_b,
      matrix_c,
      matrix_d,
      matrix_e,
      matrix_f,
    ),
    transform_point(
      x + width,
      y + height,
      center_x,
      center_y,
      cos_a,
      sin_a,
      skew_x,
      skew_y,
      matrix_a,
      matrix_b,
      matrix_c,
      matrix_d,
      matrix_e,
      matrix_f,
    ),
    transform_point(
      x,
      y + height,
      center_x,
      center_y,
      cos_a,
      sin_a,
      skew_x,
      skew_y,
      matrix_a,
      matrix_b,
      matrix_c,
      matrix_d,
      matrix_e,
      matrix_f,
    ),
  ]
  let (min_x, min_y, bbox_width, bbox_height) = polygon_bounds(points)
  let local_points : Array[(Double, Double)] = []
  for point in points {
    let (px, py) = point
    local_points.push(
      (snap_near_integer(px - min_x), snap_near_integer(py - min_y)),
    )
  }
  (
    snap_near_integer(min_x),
    snap_near_integer(min_y),
    snap_near_integer(bbox_width),
    snap_near_integer(bbox_height),
    local_points,
  )
}

///|
fn transform_point(
  x : Double,
  y : Double,
  center_x : Double,
  center_y : Double,
  cos_a : Double,
  sin_a : Double,
  skew_x : Double,
  skew_y : Double,
  matrix_a : Double,
  matrix_b : Double,
  matrix_c : Double,
  matrix_d : Double,
  matrix_e : Double,
  matrix_f : Double,
) -> (Double, Double) {
  let dx = x - center_x
  let dy = y - center_y
  let matrix_x = matrix_a * dx + matrix_c * dy + matrix_e
  let matrix_y = matrix_b * dx + matrix_d * dy + matrix_f
  let skewed_x = matrix_x + skew_x * matrix_y
  let skewed_y = skew_y * matrix_x + matrix_y
  (
    snap_near_integer(center_x + skewed_x * cos_a - skewed_y * sin_a),
    snap_near_integer(center_y + skewed_x * sin_a + skewed_y * cos_a),
  )
}

///|
fn polygon_bounds(
  points : Array[(Double, Double)],
) -> (Double, Double, Double, Double) {
  let (first_x, first_y) = points[0]
  let mut min_x = first_x
  let mut max_x = first_x
  let mut min_y = first_y
  let mut max_y = first_y
  for i in 1..<points.length() {
    let (px, py) = points[i]
    if px < min_x {
      min_x = px
    }
    if px > max_x {
      max_x = px
    }
    if py < min_y {
      min_y = py
    }
    if py > max_y {
      max_y = py
    }
  }
  (min_x, min_y, max_x - min_x, max_y - min_y)
}

///|
fn snap_near_integer(value : Double) -> Double {
  let rounded = value.round()
  if (value - rounded).abs() < 0.000001 {
    rounded
  } else {
    value
  }
}

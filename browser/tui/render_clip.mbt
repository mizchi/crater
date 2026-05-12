///|
/// Clip rectangle and clip-path helpers for TUI rendering.

///|
fn intersect_pixel_rects(
  a : (Double, Double, Double, Double),
  b : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double)? {
  let (ax, ay, aw, ah) = a
  let (bx, by, bw, bh) = b
  let left = max_double(ax, bx)
  let top = max_double(ay, by)
  let right = min_double(ax + aw, bx + bw)
  let bottom = min_double(ay + ah, by + bh)
  if right <= left || bottom <= top {
    None
  } else {
    Some((left, top, right - left, bottom - top))
  }
}

///|
fn get_local_clip_rect(
  node : @tui_paint_runtime.PaintNode,
  abs_x : Double,
  abs_y : Double,
) -> (Double, Double, Double, Double)? {
  let legacy_clip = match node.clip {
    @types.ClipRect::Rect(top~, right~, bottom~, left~) =>
      Some((abs_x + left, abs_y + top, right - left, bottom - top))
    @types.ClipRect::Auto =>
      match (node.overflow_x, node.overflow_y) {
        (@types.Visible, @types.Visible) => None
        _ => Some((abs_x, abs_y, node.width, node.height))
      }
  }
  let clip_path = match node.paint.clip_path {
    @style.ClipPath::None => None
    @style.ClipPath::Inset(top, right, bottom, left) => {
      let inset_top = resolve_clip_path_inset(top, node.height)
      let inset_right = resolve_clip_path_inset(right, node.width)
      let inset_bottom = resolve_clip_path_inset(bottom, node.height)
      let inset_left = resolve_clip_path_inset(left, node.width)
      let clip_left = abs_x + inset_left
      let clip_top = abs_y + inset_top
      let clip_right = abs_x + node.width - inset_right
      let clip_bottom = abs_y + node.height - inset_bottom
      if clip_right <= clip_left || clip_bottom <= clip_top {
        None
      } else {
        Some(
          (clip_left, clip_top, clip_right - clip_left, clip_bottom - clip_top),
        )
      }
    }
    @style.ClipPath::Rect(top, right, bottom, left) =>
      resolve_clip_path_rect(
        top,
        right,
        bottom,
        left,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
    @style.ClipPath::Xywh(x, y, width, height) =>
      resolve_clip_path_xywh(
        x,
        y,
        width,
        height,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
    @style.ClipPath::Circle(radius, center_x, center_y) => {
      let (cx, cy, r) = resolve_clip_path_circle(
        radius,
        center_x,
        center_y,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      if r <= 0.0 {
        None
      } else {
        Some((cx - r, cy - r, r * 2.0, r * 2.0))
      }
    }
    @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) => {
      let (cx, cy, rx, ry) = resolve_clip_path_ellipse(
        radius_x,
        radius_y,
        center_x,
        center_y,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      if rx <= 0.0 || ry <= 0.0 {
        None
      } else {
        Some((cx - rx, cy - ry, rx * 2.0, ry * 2.0))
      }
    }
    @style.ClipPath::Polygon(points) => {
      let resolved = resolve_clip_path_polygon(
        points,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      polygon_bounding_rect(resolved)
    }
  }
  match (legacy_clip, clip_path) {
    (Some(a), Some(b)) => intersect_pixel_rects(a, b)
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
fn combine_clip_rects(
  inherited : (Double, Double, Double, Double)?,
  local_clip : (Double, Double, Double, Double)?,
) -> (Double, Double, Double, Double)? {
  match (inherited, local_clip) {
    (Some(a), Some(b)) => intersect_pixel_rects(a, b)
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

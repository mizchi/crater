///|
/// Hit-test region collection helpers for TUI rendering.

///|
pub(all) struct HitRegion {
  col : Int
  row : Int
  width : Int
  height : Int
  pixel_x : Double
  pixel_y : Double
  pixel_width : Double
  pixel_height : Double
  shape_x : Double
  shape_y : Double
  shape_width : Double
  shape_height : Double
  radius_top_left : Double
  radius_top_right : Double
  radius_bottom_right : Double
  radius_bottom_left : Double
  scroll_y : Int
  visual_shape : HitClipShape
  clip_shape : HitClipShape
  source_id : String
}

///|
pub(all) enum HitClipShape {
  Rect
  Circle(Double, Double, Double) // center-x, center-y, radius
  Ellipse(Double, Double, Double, Double) // center-x, center-y, radius-x, radius-y
  Polygon(Array[(Double, Double)])
} derive(Debug, Eq)

///|
fn collect_hit_region(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  abs_x : Double,
  abs_y : Double,
  visible_rect : (Double, Double, Double, Double)?,
) -> Unit {
  match (extract_source_id(node.id), visible_rect) {
    (Some(source_id), Some((visible_x, visible_y, visible_w, visible_h))) =>
      if node.tag != "#text" &&
        node.paint.pointer_events != @style.PointerEvents::None &&
        visible_w > 0.0 &&
        visible_h > 0.0 {
        let radius_top_left = resolve_hit_radius(
          node.paint.border_top_left_radius,
          node.width,
          node.height,
        )
        let radius_top_right = resolve_hit_radius(
          node.paint.border_top_right_radius,
          node.width,
          node.height,
        )
        let radius_bottom_right = resolve_hit_radius(
          node.paint.border_bottom_right_radius,
          node.width,
          node.height,
        )
        let radius_bottom_left = resolve_hit_radius(
          node.paint.border_bottom_left_radius,
          node.width,
          node.height,
        )
        let visual_shape = if node.visual_polygon.is_empty() {
          HitClipShape::Rect
        } else {
          HitClipShape::Polygon(
            resolve_visual_polygon(node.visual_polygon, abs_x, abs_y),
          )
        }
        let clip_shape = resolve_hit_clip_shape(node, abs_x, abs_y)
        ctx.hit_regions.push({
          col: px_to_col(visible_x),
          row: px_to_row(visible_y) - ctx.scroll_y,
          width: px_to_col_width(visible_w),
          height: px_to_row_height(visible_h),
          pixel_x: visible_x,
          pixel_y: visible_y,
          pixel_width: visible_w,
          pixel_height: visible_h,
          shape_x: abs_x,
          shape_y: abs_y,
          shape_width: node.width,
          shape_height: node.height,
          radius_top_left,
          radius_top_right,
          radius_bottom_right,
          radius_bottom_left,
          scroll_y: ctx.scroll_y,
          visual_shape,
          clip_shape,
          source_id,
        })
      }
    _ => ()
  }
}

///|
pub fn find_hit_region_at(
  regions : Array[HitRegion],
  col : Int,
  row : Int,
) -> HitRegion? {
  if regions.is_empty() {
    return None
  }
  let mut i = regions.length() - 1
  while i >= 0 {
    let region = regions[i]
    if region.contains(col, row) {
      return Some(region)
    }
    i = i - 1
  }
  None
}

///|
fn extract_source_id(node_id : String) -> String? {
  match node_id.find("#") {
    Some(idx) =>
      if idx + 1 < node_id.length() {
        Some(node_id.unsafe_substring(start=idx + 1, end=node_id.length()))
      } else {
        None
      }
    None => None
  }
}

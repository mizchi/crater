///|
/// TUI paint tree traversal helpers.

///|
fn render_child_nodes(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  abs_x : Double,
  abs_y : Double,
  inside_link : Bool,
  child_link_source_id : String?,
  child_inside_pre : Bool,
  effective_clip : (Double, Double, Double, Double)?,
) -> Unit {
  let child_inside_link = inside_link || node.tag == "a"
  for child in node.children {
    render_paint_node(
      ctx,
      child,
      abs_x,
      abs_y,
      child_inside_link,
      current_link_source_id=child_link_source_id,
      inside_pre=child_inside_pre,
      clip_rect=effective_clip,
    )
  }
}

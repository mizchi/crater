///|
pub using @crater_js {type FlatLayoutNode, type FlatLayoutResult}

///|
pub using @types {
  type AlignItems,
  type CacheStats,
  type Display,
  type FlexDirection,
  type FlexWrap,
  type JustifyContent,
}

///|
pub fn compute_layout(html : String, width : UInt, height : UInt) -> String {
  @core.compute_layout(html, width, height)
}

///|
pub fn render_html(html : String, width : UInt, height : UInt) -> String {
  @renderer.render_html(html, width, height)
}

///|
pub fn render_html_to_json(
  html : String,
  width : UInt,
  height : UInt,
) -> String {
  @renderer.render_html_to_json(html, width, height)
}

///|
pub fn render_html_to_paint_tree(
  html : String,
  width : UInt,
  height : UInt,
) -> String {
  @renderer.render_html_to_paint_tree(html, width, height)
}

///|
pub fn create_tree(html : String, width : UInt, height : UInt) -> UInt {
  @incremental.create_tree(html, width, height)
}

///|
pub fn destroy_tree() -> Unit {
  @incremental.destroy_tree()
}

///|
pub fn compute_incremental() -> String {
  @incremental.compute_incremental()
}

///|
pub fn compute_incremental_structured() -> FlatLayoutResult {
  @incremental.compute()
}

///|
pub fn compute_full() -> String {
  @incremental.compute_full()
}

///|
pub fn compute_full_structured() -> FlatLayoutResult {
  @incremental.compute_full_structured()
}

///|
pub fn get_cache_stats() -> String {
  @incremental.get_cache_stats()
}

///|
pub fn mark_dirty(node_id : String) -> Bool {
  @incremental.mark_dirty(node_id)
}

///|
pub fn needs_layout() -> Bool {
  @incremental.needs_layout()
}

///|
pub fn reset_cache_stats() -> Unit {
  @incremental.reset_cache_stats()
}

///|
pub fn resize_viewport(width : UInt, height : UInt) -> Unit {
  @incremental.resize_viewport(width, height)
}

///|
pub fn update_style(node_id : String, css : String) -> Bool {
  @incremental.update_style(node_id, css)
}

///|
pub fn create_node(node_id : String) -> UInt {
  @yoga.create_node(node_id)
}

///|
pub fn add_child(parent_id : String, child_id : String) -> Bool {
  @yoga.add_child(parent_id, child_id)
}

///|
pub fn insert_child(
  parent_id : String,
  child_id : String,
  index : UInt,
) -> Bool {
  @yoga.insert_child(parent_id, child_id, index)
}

///|
pub fn remove_child(parent_id : String, index : UInt) -> Bool {
  @yoga.remove_child(parent_id, index)
}

///|
pub fn get_child_count(node_id : String) -> UInt {
  @yoga.get_child_count(node_id)
}

///|
pub fn calculate_layout(width : Double, height : Double) -> String {
  @yoga.calculate_layout(width, height)
}

///|
pub fn calculate_layout_structured(
  width : Double,
  height : Double,
) -> FlatLayoutResult {
  @yoga.calculate_layout_structured(width, height)
}

///|
pub fn set_width(node_id : String, width : Double) -> Bool {
  @yoga.set_width(node_id, width)
}

///|
pub fn set_width_percent(node_id : String, width : Double) -> Bool {
  @yoga.set_width_percent(node_id, width)
}

///|
pub fn set_width_auto(node_id : String) -> Bool {
  @yoga.set_width_auto(node_id)
}

///|
pub fn set_height(node_id : String, height : Double) -> Bool {
  @yoga.set_height(node_id, height)
}

///|
pub fn set_height_percent(node_id : String, height : Double) -> Bool {
  @yoga.set_height_percent(node_id, height)
}

///|
pub fn set_height_auto(node_id : String) -> Bool {
  @yoga.set_height_auto(node_id)
}

///|
pub fn set_flex_grow(node_id : String, grow : Double) -> Bool {
  @yoga.set_flex_grow(node_id, grow)
}

///|
pub fn set_flex_shrink(node_id : String, shrink : Double) -> Bool {
  @yoga.set_flex_shrink(node_id, shrink)
}

///|
pub fn set_flex_basis(node_id : String, basis : Double) -> Bool {
  @yoga.set_flex_basis(node_id, basis)
}

///|
pub fn set_flex_direction(node_id : String, direction : FlexDirection) -> Bool {
  @yoga.set_flex_direction(node_id, direction)
}

///|
pub fn set_flex_wrap(node_id : String, wrap : FlexWrap) -> Bool {
  @yoga.set_flex_wrap(node_id, wrap)
}

///|
pub fn set_justify_content(node_id : String, justify : JustifyContent) -> Bool {
  @yoga.set_justify_content(node_id, justify)
}

///|
pub fn set_align_items(node_id : String, align : AlignItems) -> Bool {
  @yoga.set_align_items(node_id, align)
}

///|
pub fn set_display(node_id : String, display : Display) -> Bool {
  @yoga.set_display(node_id, display)
}

///|
pub fn set_margin(node_id : String, margin : Double) -> Bool {
  @yoga.set_margin(node_id, margin)
}

///|
pub fn set_padding(node_id : String, padding : Double) -> Bool {
  @yoga.set_padding(node_id, padding)
}

///|
pub fn set_gap(node_id : String, gap : Double) -> Bool {
  @yoga.set_gap(node_id, gap)
}

///|
pub fn get_computed_left(node_id : String) -> Double {
  @yoga.get_computed_left(node_id)
}

///|
pub fn get_computed_top(node_id : String) -> Double {
  @yoga.get_computed_top(node_id)
}

///|
pub fn get_computed_width(node_id : String) -> Double {
  @yoga.get_computed_width(node_id)
}

///|
pub fn get_computed_height(node_id : String) -> Double {
  @yoga.get_computed_height(node_id)
}

///|
pub fn has_new_layout(node_id : String) -> Bool {
  @yoga.has_new_layout(node_id)
}

///|
pub fn mark_layout_seen(node_id : String) -> Bool {
  @yoga.mark_layout_seen(node_id)
}

///|
pub fn get_aria_snapshot(html : String) -> String {
  @accessibility.get_aria_snapshot(html)
}

///|
pub fn get_aria_snapshot_json(html : String) -> String {
  @accessibility.get_aria_snapshot_json(html)
}

///|
pub fn get_accessibility_tree(html : String) -> String {
  @accessibility.get_accessibility_tree(html)
}

///|
pub fn extract_main_content(html : String) -> String {
  @accessibility.extract_main_content(html)
}

///|
pub fn extract_main_content_with_layout(
  html : String,
  width : Int,
  height : Int,
) -> String {
  @accessibility.extract_main_content_with_layout(html, width, height)
}

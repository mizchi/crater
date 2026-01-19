///|
/// Yoga-compatible API for LayoutNode and LayoutTree
/// Provides a familiar interface for users coming from Yoga/Litho/React Native

// =============================================================================
// LayoutNode Extensions - Style Setters (auto-dirty)
// =============================================================================

///|
/// Set width in pixels
pub fn LayoutNode::set_width(self : LayoutNode, value : Double) -> LayoutNode {
  if not(self.style.width.eq_length(value)) {
    self.style.width = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set width as percentage (0.0-1.0)
pub fn LayoutNode::set_width_percent(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.width.eq_percent(value)) {
    self.style.width = @types.Percent(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set width to auto
pub fn LayoutNode::set_width_auto(self : LayoutNode) -> LayoutNode {
  match self.style.width {
    @types.Auto => ()
    _ => {
      self.style.width = @types.Auto
      self.mark_dirty()
    }
  }
  self
}

///|
/// Set height in pixels
pub fn LayoutNode::set_height(self : LayoutNode, value : Double) -> LayoutNode {
  if not(self.style.height.eq_length(value)) {
    self.style.height = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set height as percentage (0.0-1.0)
pub fn LayoutNode::set_height_percent(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.height.eq_percent(value)) {
    self.style.height = @types.Percent(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set height to auto
pub fn LayoutNode::set_height_auto(self : LayoutNode) -> LayoutNode {
  match self.style.height {
    @types.Auto => ()
    _ => {
      self.style.height = @types.Auto
      self.mark_dirty()
    }
  }
  self
}

///|
/// Set min-width in pixels
pub fn LayoutNode::set_min_width(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.min_width.eq_length(value)) {
    self.style.min_width = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set max-width in pixels
pub fn LayoutNode::set_max_width(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.max_width.eq_length(value)) {
    self.style.max_width = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set min-height in pixels
pub fn LayoutNode::set_min_height(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.min_height.eq_length(value)) {
    self.style.min_height = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set max-height in pixels
pub fn LayoutNode::set_max_height(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.max_height.eq_length(value)) {
    self.style.max_height = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set flex direction
pub fn LayoutNode::set_flex_direction(
  self : LayoutNode,
  dir : @types.FlexDirection,
) -> LayoutNode {
  if self.style.flex_direction != dir {
    self.style.flex_direction = dir
    self.mark_dirty()
  }
  self
}

///|
/// Set flex wrap
pub fn LayoutNode::set_flex_wrap(
  self : LayoutNode,
  wrap : @types.FlexWrap,
) -> LayoutNode {
  if self.style.flex_wrap != wrap {
    self.style.flex_wrap = wrap
    self.mark_dirty()
  }
  self
}

///|
/// Set flex grow
pub fn LayoutNode::set_flex_grow(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if (self.style.flex_grow - value).abs() > 0.0001 {
    self.style.flex_grow = value
    self.mark_dirty()
  }
  self
}

///|
/// Set flex shrink
pub fn LayoutNode::set_flex_shrink(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if (self.style.flex_shrink - value).abs() > 0.0001 {
    self.style.flex_shrink = value
    self.mark_dirty()
  }
  self
}

///|
/// Set flex basis in pixels
pub fn LayoutNode::set_flex_basis(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.flex_basis.eq_length(value)) {
    self.style.flex_basis = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set flex basis to auto
pub fn LayoutNode::set_flex_basis_auto(self : LayoutNode) -> LayoutNode {
  match self.style.flex_basis {
    @types.Auto => ()
    _ => {
      self.style.flex_basis = @types.Auto
      self.mark_dirty()
    }
  }
  self
}

///|
/// Set justify content
pub fn LayoutNode::set_justify_content(
  self : LayoutNode,
  value : @types.Alignment,
) -> LayoutNode {
  if self.style.justify_content != value {
    self.style.justify_content = value
    self.mark_dirty()
  }
  self
}

///|
/// Set align items
pub fn LayoutNode::set_align_items(
  self : LayoutNode,
  value : @types.Alignment,
) -> LayoutNode {
  if self.style.align_items != value {
    self.style.align_items = value
    self.mark_dirty()
  }
  self
}

///|
/// Set align self
pub fn LayoutNode::set_align_self(
  self : LayoutNode,
  value : @types.AlignSelf,
) -> LayoutNode {
  if self.style.align_self != value {
    self.style.align_self = value
    self.mark_dirty()
  }
  self
}

///|
/// Set align content
pub fn LayoutNode::set_align_content(
  self : LayoutNode,
  value : @types.Alignment,
) -> LayoutNode {
  if self.style.align_content != value {
    self.style.align_content = value
    self.mark_dirty()
  }
  self
}

///|
/// Set display type
pub fn LayoutNode::set_display(
  self : LayoutNode,
  value : @types.Display,
) -> LayoutNode {
  if self.style.display != value {
    self.style.display = value
    self.mark_dirty()
  }
  self
}

///|
/// Set position type
pub fn LayoutNode::set_position_type(
  self : LayoutNode,
  value : @types.Position,
) -> LayoutNode {
  if self.style.position != value {
    self.style.position = value
    self.mark_dirty()
  }
  self
}

///|
/// Set row gap in pixels
pub fn LayoutNode::set_row_gap(self : LayoutNode, value : Double) -> LayoutNode {
  if not(self.style.row_gap.eq_length(value)) {
    self.style.row_gap = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set column gap in pixels
pub fn LayoutNode::set_column_gap(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  if not(self.style.column_gap.eq_length(value)) {
    self.style.column_gap = @types.Length(value)
    self.mark_dirty()
  }
  self
}

///|
/// Set both row and column gap
pub fn LayoutNode::set_gap(self : LayoutNode, value : Double) -> LayoutNode {
  self.set_row_gap(value).set_column_gap(value)
}

// =============================================================================
// Grid Container Setters
// =============================================================================

///|
/// Set grid template columns
pub fn LayoutNode::set_grid_template_columns(
  self : LayoutNode,
  tracks : Array[@types.TrackSizingFunction],
) -> LayoutNode {
  self.style.grid_template_columns = tracks
  self.mark_dirty()
  self
}

///|
/// Set grid template rows
pub fn LayoutNode::set_grid_template_rows(
  self : LayoutNode,
  tracks : Array[@types.TrackSizingFunction],
) -> LayoutNode {
  self.style.grid_template_rows = tracks
  self.mark_dirty()
  self
}

///|
/// Set grid auto columns
pub fn LayoutNode::set_grid_auto_columns(
  self : LayoutNode,
  tracks : Array[@types.TrackSizingFunction],
) -> LayoutNode {
  self.style.grid_auto_columns = tracks
  self.mark_dirty()
  self
}

///|
/// Set grid auto rows
pub fn LayoutNode::set_grid_auto_rows(
  self : LayoutNode,
  tracks : Array[@types.TrackSizingFunction],
) -> LayoutNode {
  self.style.grid_auto_rows = tracks
  self.mark_dirty()
  self
}

///|
/// Set grid auto flow
pub fn LayoutNode::set_grid_auto_flow(
  self : LayoutNode,
  flow : @types.GridAutoFlow,
) -> LayoutNode {
  if self.style.grid_auto_flow != flow {
    self.style.grid_auto_flow = flow
    self.mark_dirty()
  }
  self
}

///|
/// Set grid template areas
pub fn LayoutNode::set_grid_template_areas(
  self : LayoutNode,
  areas : Array[String],
) -> LayoutNode {
  self.style.grid_template_areas = areas
  self.mark_dirty()
  self
}

// =============================================================================
// Grid Item Setters
// =============================================================================

///|
/// Set grid row placement
pub fn LayoutNode::set_grid_row(
  self : LayoutNode,
  start : @types.GridPlacement,
  end : @types.GridPlacement,
) -> LayoutNode {
  self.style.grid_row = { start, end }
  self.mark_dirty()
  self
}

///|
/// Set grid column placement
pub fn LayoutNode::set_grid_column(
  self : LayoutNode,
  start : @types.GridPlacement,
  end : @types.GridPlacement,
) -> LayoutNode {
  self.style.grid_column = { start, end }
  self.mark_dirty()
  self
}

///|
/// Set grid area by name
pub fn LayoutNode::set_grid_area(
  self : LayoutNode,
  area : String?,
) -> LayoutNode {
  self.style.grid_area = area
  self.mark_dirty()
  self
}

///|
/// Set justify items (grid container)
pub fn LayoutNode::set_justify_items(
  self : LayoutNode,
  value : @types.Alignment,
) -> LayoutNode {
  if self.style.justify_items != value {
    self.style.justify_items = value
    self.mark_dirty()
  }
  self
}

///|
/// Set justify self (grid item)
pub fn LayoutNode::set_justify_self(
  self : LayoutNode,
  value : @types.AlignSelf,
) -> LayoutNode {
  if self.style.justify_self != value {
    self.style.justify_self = value
    self.mark_dirty()
  }
  self
}

// =============================================================================
// Margin Setters
// =============================================================================

///|
/// Set all margins
pub fn LayoutNode::set_margin(self : LayoutNode, value : Double) -> LayoutNode {
  self.style.margin = @types.Rect::all(@types.Length(value))
  self.mark_dirty()
  self
}

///|
/// Set margin top
pub fn LayoutNode::set_margin_top(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let m = self.style.margin
  self.style.margin = {
    top: @types.Length(value),
    right: m.right,
    bottom: m.bottom,
    left: m.left,
  }
  self.mark_dirty()
  self
}

///|
/// Set margin right
pub fn LayoutNode::set_margin_right(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let m = self.style.margin
  self.style.margin = {
    top: m.top,
    right: @types.Length(value),
    bottom: m.bottom,
    left: m.left,
  }
  self.mark_dirty()
  self
}

///|
/// Set margin bottom
pub fn LayoutNode::set_margin_bottom(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let m = self.style.margin
  self.style.margin = {
    top: m.top,
    right: m.right,
    bottom: @types.Length(value),
    left: m.left,
  }
  self.mark_dirty()
  self
}

///|
/// Set margin left
pub fn LayoutNode::set_margin_left(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let m = self.style.margin
  self.style.margin = {
    top: m.top,
    right: m.right,
    bottom: m.bottom,
    left: @types.Length(value),
  }
  self.mark_dirty()
  self
}

// =============================================================================
// Padding Setters
// =============================================================================

///|
/// Set all padding
pub fn LayoutNode::set_padding(self : LayoutNode, value : Double) -> LayoutNode {
  self.style.padding = @types.Rect::all(@types.Length(value))
  self.mark_dirty()
  self
}

///|
/// Set padding top
pub fn LayoutNode::set_padding_top(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let p = self.style.padding
  self.style.padding = {
    top: @types.Length(value),
    right: p.right,
    bottom: p.bottom,
    left: p.left,
  }
  self.mark_dirty()
  self
}

///|
/// Set padding right
pub fn LayoutNode::set_padding_right(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let p = self.style.padding
  self.style.padding = {
    top: p.top,
    right: @types.Length(value),
    bottom: p.bottom,
    left: p.left,
  }
  self.mark_dirty()
  self
}

///|
/// Set padding bottom
pub fn LayoutNode::set_padding_bottom(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let p = self.style.padding
  self.style.padding = {
    top: p.top,
    right: p.right,
    bottom: @types.Length(value),
    left: p.left,
  }
  self.mark_dirty()
  self
}

///|
/// Set padding left
pub fn LayoutNode::set_padding_left(
  self : LayoutNode,
  value : Double,
) -> LayoutNode {
  let p = self.style.padding
  self.style.padding = {
    top: p.top,
    right: p.right,
    bottom: p.bottom,
    left: @types.Length(value),
  }
  self.mark_dirty()
  self
}

// =============================================================================
// Border Setters
// =============================================================================

///|
/// Set all border widths
pub fn LayoutNode::set_border(self : LayoutNode, value : Double) -> LayoutNode {
  self.style.border = @types.Rect::all(@types.Length(value))
  self.mark_dirty()
  self
}

// =============================================================================
// Child Management
// =============================================================================

///|
/// Get number of children
pub fn LayoutNode::get_child_count(self : LayoutNode) -> Int {
  self.children.length()
}

///|
/// Get child at index
pub fn LayoutNode::get_child(self : LayoutNode, index : Int) -> LayoutNode? {
  if index >= 0 && index < self.children.length() {
    Some(self.children[index])
  } else {
    None
  }
}

///|
/// Insert child at index
pub fn LayoutNode::insert_child(
  self : LayoutNode,
  child : LayoutNode,
  index : Int,
) -> LayoutNode {
  let idx = if index < 0 {
    0
  } else if index > self.children.length() {
    self.children.length()
  } else {
    index
  }
  self.children.insert(idx, child)
  self.mark_dirty()
  self
}

///|
/// Add child at end
pub fn LayoutNode::add_child(
  self : LayoutNode,
  child : LayoutNode,
) -> LayoutNode {
  self.children.push(child)
  self.mark_dirty()
  self
}

///|
/// Remove child at index
pub fn LayoutNode::remove_child_at(
  self : LayoutNode,
  index : Int,
) -> LayoutNode? {
  if index >= 0 && index < self.children.length() {
    let removed = self.children.remove(index)
    self.mark_dirty()
    Some(removed)
  } else {
    None
  }
}

///|
/// Remove all children
pub fn LayoutNode::remove_all_children(self : LayoutNode) -> Unit {
  if self.children.length() > 0 {
    self.children.clear()
    self.mark_dirty()
  }
}

// =============================================================================
// LayoutTree - Yoga-like API
// =============================================================================

///|
/// Calculate layout (Yoga-compatible name)
/// Returns the root layout and stores computed layouts on each node
pub fn LayoutTree::calculate_layout(
  self : LayoutTree,
  width : Double,
  height : Double,
) -> @types.Layout {
  // Update viewport if changed
  if (self.viewport_width - width).abs() > 0.001 ||
    (self.viewport_height - height).abs() > 0.001 {
    self.resize_viewport(width, height)
  }
  // Compute layout
  let layout = self.compute_incremental()
  // Store computed layouts on nodes
  store_computed_layouts(self.root, layout)
  layout
}

///|
/// Store computed layout results on nodes recursively
fn store_computed_layouts(node : LayoutNode, layout : @types.Layout) -> Unit {
  // Store this node's computed layout
  node.computed_x = layout.x
  node.computed_y = layout.y
  node.computed_width = layout.width
  node.computed_height = layout.height
  node.has_new_layout = true

  // Recurse to children
  for i, child in node.children {
    if i < layout.children.length() {
      store_computed_layouts(child, layout.children[i])
    }
  }
}

// =============================================================================
// Layout Result Getters
// =============================================================================

///|
/// Get computed X position (relative to parent)
pub fn LayoutNode::get_layout_x(self : LayoutNode) -> Double {
  self.computed_x
}

///|
/// Get computed Y position (relative to parent)
pub fn LayoutNode::get_layout_y(self : LayoutNode) -> Double {
  self.computed_y
}

///|
/// Get computed width
pub fn LayoutNode::get_layout_width(self : LayoutNode) -> Double {
  self.computed_width
}

///|
/// Get computed height
pub fn LayoutNode::get_layout_height(self : LayoutNode) -> Double {
  self.computed_height
}

///|
/// Check if node has new layout since last mark_layout_seen
pub fn LayoutNode::get_has_new_layout(self : LayoutNode) -> Bool {
  self.has_new_layout
}

///|
/// Mark that layout has been read (for incremental updates)
pub fn LayoutNode::mark_layout_seen(self : LayoutNode) -> Unit {
  self.has_new_layout = false
}

///|
/// Check if node is dirty
pub fn LayoutNode::is_dirty(self : LayoutNode) -> Bool {
  self.dirty
}

// =============================================================================
// Factory Methods
// =============================================================================

///|
/// Create a new node with default style (Yoga-compatible)
pub fn LayoutNode::create() -> LayoutNode {
  LayoutNode::new("", @style.Style::default(), [])
}

///|
/// Create a new node with ID
pub fn LayoutNode::create_with_id(id : String) -> LayoutNode {
  LayoutNode::new(id, @style.Style::default(), [])
}

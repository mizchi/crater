///|
/// Validation issue for the TUI-oriented core layout subset.
pub(all) struct CoreIssue {
  node_id : String
  property : String
  detail : String
}

///|
/// Host-provided layout compute function.
/// Core stays independent from concrete layout package wiring.
pub(all) struct LayoutComputeFn(
  (@node.Node, @types.LayoutContext) -> @types.Layout
)

///|
pub fn LayoutComputeFn::run(
  self : LayoutComputeFn,
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  match self {
    LayoutComputeFn(f) => f(node, ctx)
  }
}

///|
/// Result for checked core layout computation.
pub(all) struct CoreComputeResult {
  layout : @types.Layout?
  issues : Array[CoreIssue]
}

///|
pub fn is_tui_subset(node : @node.Node) -> Bool {
  validate_tui_subset(node).length() == 0
}

///|
/// Validate whether a node tree is within the predictable TUI subset.
pub fn validate_tui_subset(node : @node.Node) -> Array[CoreIssue] {
  let issues : Array[CoreIssue] = []
  validate_tui_subset_impl(node, issues)
  issues
}

///|
/// Compute only when the tree satisfies core subset constraints.
pub fn compute_if_supported(
  node : @node.Node,
  viewport : @types.Size[Double],
  compute : LayoutComputeFn,
) -> CoreComputeResult {
  let issues = validate_tui_subset(node)
  if issues.length() > 0 {
    return { layout: None, issues }
  }
  let ctx : @types.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @types.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
    stretch_width: false,
    stretch_height: false,
  }
  { layout: Some(compute.run(node, ctx)), issues: [] }
}

///|
fn validate_tui_subset_impl(
  node : @node.Node,
  issues : Array[CoreIssue],
) -> Unit {
  validate_style(node.id, node.style, issues)
  for child in node.children {
    validate_tui_subset_impl(child, issues)
  }
}

///|
fn validate_style(
  node_id : String,
  style : @style.Style,
  issues : Array[CoreIssue],
) -> Unit {
  if not(is_supported_display(style.display)) {
    add_issue(issues, node_id, "display", "unsupported display in core subset")
  }
  if style.position != @types.Position::Static {
    add_issue(issues, node_id, "position", "only position: static is supported")
  }
  if style.float != @types.Float::None {
    add_issue(issues, node_id, "float", "float layout is outside core subset")
  }
  if style.clear != @types.Clear::None {
    add_issue(issues, node_id, "clear", "clear is outside core subset")
  }
  if not(is_supported_flex_direction(style.flex_direction)) {
    add_issue(
      issues, node_id, "flex_direction", "only row/column are supported",
    )
  }
  if style.flex_wrap != @types.FlexWrap::NoWrap {
    add_issue(issues, node_id, "flex_wrap", "flex-wrap is outside core subset")
  }

  validate_dimension(node_id, "width", style.width, issues)
  validate_dimension(node_id, "height", style.height, issues)
  validate_dimension(node_id, "min_width", style.min_width, issues)
  validate_dimension(node_id, "min_height", style.min_height, issues)
  validate_dimension(node_id, "max_width", style.max_width, issues)
  validate_dimension(node_id, "max_height", style.max_height, issues)
  validate_dimension(node_id, "flex_basis", style.flex_basis, issues)
  validate_dimension(node_id, "row_gap", style.row_gap, issues)
  validate_dimension(node_id, "column_gap", style.column_gap, issues)
  validate_rect_dimension(node_id, "margin", style.margin, issues)
  validate_rect_dimension(node_id, "padding", style.padding, issues)
  validate_rect_dimension(node_id, "border", style.border, issues)
  validate_rect_dimension(node_id, "inset", style.inset, issues)

  if not(is_supported_alignment(style.justify_content)) {
    add_issue(
      issues, node_id, "justify_content", "unsupported alignment in core subset",
    )
  }
  if not(is_supported_alignment(style.align_items)) {
    add_issue(
      issues, node_id, "align_items", "unsupported alignment in core subset",
    )
  }
  if not(is_supported_alignment(style.align_content)) {
    add_issue(
      issues, node_id, "align_content", "unsupported alignment in core subset",
    )
  }
  if not(is_supported_alignment(style.justify_items)) {
    add_issue(
      issues, node_id, "justify_items", "unsupported alignment in core subset",
    )
  }
  if not(is_supported_align_self(style.align_self)) {
    add_issue(
      issues, node_id, "align_self", "unsupported align-self in core subset",
    )
  }
  if not(is_supported_align_self(style.justify_self)) {
    add_issue(
      issues, node_id, "justify_self", "unsupported justify-self in core subset",
    )
  }

  validate_track_list(
    node_id,
    "grid_template_columns",
    style.grid_template_columns,
    issues,
  )
  validate_track_list(
    node_id,
    "grid_template_rows",
    style.grid_template_rows,
    issues,
  )
  validate_track_list(
    node_id,
    "grid_auto_columns",
    style.grid_auto_columns,
    issues,
  )
  validate_track_list(node_id, "grid_auto_rows", style.grid_auto_rows, issues)

  if style.display == @types.Display::Grid &&
    (
      style.grid_template_columns.length() == 0 ||
      style.grid_template_rows.length() == 0
    ) {
    add_issue(
      issues, node_id, "grid_template", "grid requires explicit rows and columns in core subset",
    )
  }

  if not(is_supported_grid_line(style.grid_column)) {
    add_issue(
      issues, node_id, "grid_column", "grid line must use positive line/span values",
    )
  }
  if not(is_supported_grid_line(style.grid_row)) {
    add_issue(
      issues, node_id, "grid_row", "grid line must use positive line/span values",
    )
  }

  if style.writing_mode != @style.WritingMode::HorizontalTb {
    add_issue(
      issues, node_id, "writing_mode", "vertical writing mode is outside core subset",
    )
  }
  if style.direction != @style.Direction::Ltr {
    add_issue(
      issues, node_id, "direction", "rtl direction is outside core subset",
    )
  }
  if not(style.transform.is_none()) {
    add_issue(issues, node_id, "transform", "transform is outside core subset")
  }
  if style.zoom != 1.0 {
    add_issue(issues, node_id, "zoom", "zoom is outside core subset")
  }
  if style.contain.has_containment() {
    add_issue(issues, node_id, "contain", "containment is outside core subset")
  }
}

///|
fn validate_dimension(
  node_id : String,
  property : String,
  dim : @types.Dimension,
  issues : Array[CoreIssue],
) -> Unit {
  if not(is_supported_dimension(dim)) {
    add_issue(
      issues, node_id, property, "only auto/length/percent dimensions are supported",
    )
  }
}

///|
fn validate_rect_dimension(
  node_id : String,
  property : String,
  rect : @types.Rect[@types.Dimension],
  issues : Array[CoreIssue],
) -> Unit {
  validate_dimension(node_id, property, rect.top, issues)
  validate_dimension(node_id, property, rect.right, issues)
  validate_dimension(node_id, property, rect.bottom, issues)
  validate_dimension(node_id, property, rect.left, issues)
}

///|
fn validate_track_list(
  node_id : String,
  property : String,
  tracks : Array[@types.TrackSizingFunction],
  issues : Array[CoreIssue],
) -> Unit {
  for track in tracks {
    if not(is_supported_track(track)) {
      add_issue(
        issues, node_id, property, "track sizing must be length/percent/fr/auto",
      )
    }
  }
}

///|
fn add_issue(
  issues : Array[CoreIssue],
  node_id : String,
  property : String,
  detail : String,
) -> Unit {
  issues.push({ node_id, property, detail })
}

///|
fn is_supported_display(display : @types.Display) -> Bool {
  match display {
    @types.Display::Block
    | @types.Display::Inline
    | @types.Display::InlineBlock
    | @types.Display::Flex
    | @types.Display::Grid
    | @types.Display::None => true
    _ => false
  }
}

///|
fn is_supported_flex_direction(direction : @types.FlexDirection) -> Bool {
  match direction {
    @types.FlexDirection::Row | @types.FlexDirection::Column => true
    _ => false
  }
}

///|
fn is_supported_dimension(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Dimension::Auto
    | @types.Dimension::Length(_)
    | @types.Dimension::Percent(_) => true
    _ => false
  }
}

///|
fn is_supported_alignment(alignment : @types.Alignment) -> Bool {
  match alignment {
    @types.Alignment::Start
    | @types.Alignment::End
    | @types.Alignment::FlexStart
    | @types.Alignment::FlexEnd
    | @types.Alignment::Center
    | @types.Alignment::SpaceBetween
    | @types.Alignment::SpaceAround
    | @types.Alignment::SpaceEvenly
    | @types.Alignment::Stretch => true
    @types.Alignment::Baseline => false
  }
}

///|
fn is_supported_align_self(align : @types.AlignSelf) -> Bool {
  match align {
    @types.AlignSelf::Auto
    | @types.AlignSelf::Start
    | @types.AlignSelf::End
    | @types.AlignSelf::Center
    | @types.AlignSelf::Stretch => true
    @types.AlignSelf::Baseline => false
  }
}

///|
fn is_supported_track(track : @types.TrackSizingFunction) -> Bool {
  match track {
    @types.TrackSizingFunction::Length(_)
    | @types.TrackSizingFunction::Percent(_)
    | @types.TrackSizingFunction::Fr(_)
    | @types.TrackSizingFunction::Auto => true
    _ => false
  }
}

///|
fn is_supported_grid_line(line : @types.GridLine) -> Bool {
  is_supported_grid_placement(line.start) &&
  is_supported_grid_placement(line.end)
}

///|
fn is_supported_grid_placement(placement : @types.GridPlacement) -> Bool {
  match placement {
    @types.GridPlacement::Auto => true
    @types.GridPlacement::Line(v) | @types.GridPlacement::Span(v) => v > 0
  }
}

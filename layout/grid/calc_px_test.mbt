///|
/// Regression tests: a grid container's min/max width/height constraints
/// expressed with `calc()` (or `min/max/clamp`) must include the absolute (px)
/// term, not just the percentage. Previously the `Calc(_, p)` / `MathFn` arms
/// in `compute_grid_layout_internal` dropped px, so `min-width: calc(50% + 100px)`
/// resolved as 50% only.

///|
test "grid_min_width_calc_includes_px" {
  // Auto-width grid with a single 40px column, min-width: calc(50% + 100px)
  // against available 800 -> min(used) = 400 + 100 = 500 (was 400 with px drop).
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Auto,
    height: @types.Length(40.0),
    min_width: @types.Calc(100.0, 0.5),
    grid_template_columns: [@types.TrackSizingFunction::Length(40.0)],
    grid_template_rows: [@types.TrackSizingFunction::Length(40.0)],
  }
  let root = @node.Node::new("root", root_style, [
    @node.Node::leaf("cell", default_style),
  ])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())
  inspect(layout.width, content="500")
}

///|
test "grid_max_width_calc_includes_px" {
  // Auto-width grid with a wide 700px column clamped by
  // max-width: calc(25% + 30px) against available 800 -> 200 + 30 = 230
  // (was 200 with px drop).
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Auto,
    height: @types.Length(40.0),
    max_width: @types.Calc(30.0, 0.25),
    grid_template_columns: [@types.TrackSizingFunction::Length(700.0)],
    grid_template_rows: [@types.TrackSizingFunction::Length(40.0)],
  }
  let root = @node.Node::new("root", root_style, [
    @node.Node::leaf("cell", default_style),
  ])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())
  inspect(layout.width, content="230")
}

///|
/// Regression: max-width must not shrink a grid below its min-content. A fixed
/// 700px track keeps its size and the item overflows the clamped container,
/// rather than being squeezed down to the container content box.
test "grid_max_width_does_not_shrink_fixed_track" {
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Auto,
    height: @types.Length(40.0),
    max_width: @types.Calc(30.0, 0.25),
    grid_template_columns: [@types.TrackSizingFunction::Length(700.0)],
    grid_template_rows: [@types.TrackSizingFunction::Length(40.0)],
  }
  let root = @node.Node::new("root", root_style, [
    @node.Node::leaf("cell", default_style),
  ])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())
  // Container clamped to max-width: 25% * 800 + 30 = 230.
  inspect(layout.width, content="230")
  // Item keeps the fixed 700px track and overflows (not shrunk to 230).
  inspect(layout.children[0].width, content="700")
}

///|
// css 0.5.3 added GridPlacement::Named; items can be placed by named grid line
// (`grid-column: sidebar-start/sidebar-end`) or by the implicit-area shorthand
// (`grid-column: sidebar` -> sidebar-start/sidebar-end). Resolved against the
// template's declared line names.
test "grid named-line placement" {
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(1000.0),
    height: @types.Length(100.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(240.0),
      @types.TrackSizingFunction::Length(760.0),
    ],
    // Line names declared by `[sidebar-start] 240px [sidebar-end content-start]
    // 760px [content-end]` — index i holds the names at grid line i.
    grid_template_column_line_names: [
      ["sidebar-start"],
      ["sidebar-end", "content-start"],
      ["content-end"],
    ],
  }
  let side = @node.Node::leaf("side", {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::Named("sidebar"),
      end: @types.GridPlacement::Named("sidebar"),
    },
    height: @types.Length(20.0),
  })
  let root = @node.Node::new("root", root_style, [side])
  let layout = compute_grid_layout(root, 1000.0, 600.0, default_dispatch())
  // The named item lands in the 240px sidebar column at x=0.
  inspect(layout.children[0].width, content="240")
  inspect(layout.children[0].x, content="0")
}

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

///|
// css 0.5.9 carries the line names declared inside repeat() in the third field
// of Repeat. expand_track_templates expands them in lockstep with the tracks so
// `repeat(3, [col] 100px)` yields a "col" line before every repetition; an item
// placed by `grid-column: col 2 / col 3` (GridPlacement::NamedLine) lands on the
// 2nd/3rd "col" line — track index 1, x=100, width=100.
test "grid repeat() internal line names place by NamedLine" {
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(1000.0),
    height: @types.Length(100.0),
    grid_template_columns: [
      @types.Repeat(
        @types.Count(3),
        [@types.SingleTrackSizing::Length(100.0)],
        [["col"], []],
      ),
    ],
    // Top-level line names: the repeat counts as one track (two empty lines).
    grid_template_column_line_names: [[], []],
  }
  let item = @node.Node::leaf("item", {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::NamedLine(2, "col"),
      end: @types.GridPlacement::NamedLine(3, "col"),
    },
    height: @types.Length(20.0),
  })
  let root = @node.Node::new("root", root_style, [item])
  let layout = compute_grid_layout(root, 1000.0, 600.0, default_dispatch())
  inspect(layout.children[0].x, content="100")
  inspect(layout.children[0].width, content="100")
}

///|
// A named line declared *after* a repeat() must stay aligned with the expanded
// track count: `[s] 200px [m] repeat(2, 100px) [e]` puts "e" on the final line
// (x=400). An item at `grid-column: m / e` spans from x=200 to x=400.
test "grid named line after repeat stays aligned" {
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(1000.0),
    height: @types.Length(100.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(200.0),
      @types.Repeat(
        @types.Count(2),
        [@types.SingleTrackSizing::Length(100.0)],
        [[], []],
      ),
    ],
    // [s] 200px [m] repeat(...) [e] — the repeat occupies one top-level slot.
    grid_template_column_line_names: [["s"], ["m"], ["e"]],
  }
  let item = @node.Node::leaf("item", {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::Named("m"),
      end: @types.GridPlacement::Named("e"),
    },
    height: @types.Length(20.0),
  })
  let root = @node.Node::new("root", root_style, [item])
  let layout = compute_grid_layout(root, 1000.0, 600.0, default_dispatch())
  inspect(layout.children[0].x, content="200")
  inspect(layout.children[0].width, content="200")
}

///|
// `grid-area: <name>` where the name is not a grid-template-areas area resolves
// to named lines (`<name>` / `<name>` on both axes, with the implicit
// `<name>-start` / `<name>-end` expansion). css parses this into
// `style.grid_area = Some(name)`; the grid engine must fall back to named-line
// placement instead of auto-placing the item.
test "grid-area name falls back to named-line placement" {
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
    // [sidebar-start] 240px [sidebar-end content-start] 760px [content-end]
    grid_template_column_line_names: [
      ["sidebar-start"],
      ["sidebar-end", "content-start"],
      ["content-end"],
    ],
    grid_template_rows: [@types.TrackSizingFunction::Length(40.0)],
  }
  let side = @node.Node::leaf("side", {
    ..default_style,
    grid_area: Some("sidebar"),
    height: @types.Length(20.0),
  })
  let content = @node.Node::leaf("content", {
    ..default_style,
    grid_area: Some("content"),
    height: @types.Length(20.0),
  })
  let root = @node.Node::new("root", root_style, [side, content])
  let layout = compute_grid_layout(root, 1000.0, 600.0, default_dispatch())
  // side -> sidebar column (x=0, w=240); content -> content column (x=240, w=760)
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].width, content="240")
  inspect(layout.children[1].x, content="240")
  inspect(layout.children[1].width, content="760")
}

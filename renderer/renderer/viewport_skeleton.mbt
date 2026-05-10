///|
// Viewport skeleton fast-path state and helpers.
//
// Large documents can switch below-fold nodes to lightweight skeleton nodes
// while the renderer builds the visible viewport.

///|
/// Viewport culling: estimated cumulative Y position during build_node.
/// Elements estimated below viewport_cutoff use skeleton mode (fast path).
let viewport_estimated_y : Ref[Double] = { val: 0.0 }

///|
let viewport_cutoff : Ref[Double] = { val: 1.0e10 }

///|
let viewport_skeleton_count : Ref[Int] = { val: 0 }

///|
let viewport_full_node_count : Ref[Int] = { val: 0 }

///|
let viewport_full_node_cutoff : Ref[Int] = { val: 300 }

///|
let viewport_skeleton_enabled : Ref[Bool] = { val: true }

///|
let empty_indexed_stylesheets : Ref[Array[@css.IndexedStylesheet]] = { val: [] }

///|
fn should_use_viewport_skeleton() -> Bool {
  viewport_skeleton_enabled.val &&
  (
    viewport_estimated_y.val > viewport_cutoff.val ||
    viewport_full_node_count.val > viewport_full_node_cutoff.val
  )
}

///|
fn parse_skeleton_px_length(value : String) -> Double? {
  let lower = value.trim().to_string().to_lower()
  if lower.is_empty() || lower == "auto" {
    return None
  }
  let raw = if lower.has_suffix("px") {
    lower.unsafe_substring(start=0, end=lower.length() - 2).trim().to_string()
  } else {
    lower
  }
  let parsed = @string.parse_double(raw) catch { _ => return None }
  if parsed >= 0.0 {
    Some(parsed)
  } else {
    None
  }
}

///|
fn apply_skeleton_inline_style_hints(
  style : @style.Style,
  inline_css : String,
) -> @style.Style {
  let result = apply_skeleton_inline_display_hint(style, inline_css)
  apply_skeleton_inline_height_hint(result, inline_css)
}

///|
fn apply_skeleton_inline_display_hint(
  style : @style.Style,
  inline_css : String,
) -> @style.Style {
  let result = style
  match get_cached_inline_style_display(inline_css) {
    Some(@types.Display::None) => result.display = @types.Display::None
    Some(_) | None => ()
  }
  result
}

///|
fn apply_skeleton_inline_height_hint(
  style : @style.Style,
  inline_css : String,
) -> @style.Style {
  let result = style
  for declaration in parse_inline_declarations_cached(inline_css) {
    let (prop, value) = declaration
    if prop == "height" {
      match parse_skeleton_px_length(value) {
        Some(height) => result.height = @types.Length(height)
        None => ()
      }
    }
  }
  result
}

///|
fn viewport_skeleton_advance(style : @style.Style) -> Double {
  match style.height {
    @types.Length(height) => height
    _ => style.line_height
  }
}

///|
fn skeleton_parent_allows_explicit_size_hints(
  parent_style : @style.Style?,
) -> Bool {
  match parent_style {
    Some(style) =>
      match (style.overflow_x, style.overflow_y) {
        (@types.Scroll | @types.Auto, _) | (_, @types.Scroll | @types.Auto) =>
          true
        _ => false
      }
    None => false
  }
}

///|
fn should_collapse_viewport_skeleton_subtree(style : @style.Style) -> Bool {
  match style.display {
    @types.Display::None | @types.Contents => false
    _ =>
      match style.height {
        @types.Length(_) => true
        _ => false
      }
  }
}

///|
/// Advance the viewport culling heuristic only for in-flow block containers.
/// Counting floated descendants as vertical progress causes small tables with
/// many float-based fixtures to enter skeleton mode too early.
fn should_advance_viewport_estimate(style : @style.Style) -> Bool {
  let is_in_flow = match style.position {
    @types.Absolute | @types.Fixed => false
    _ =>
      match style.float {
        @types.Float::Left | @types.Float::Right => false
        @types.Float::None => true
      }
  }
  if !is_in_flow {
    return false
  }
  match style.display {
    @types.Block | @types.Flex | @types.Grid | @types.Table => true
    _ => false
  }
}

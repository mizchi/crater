///|
test "viewport skeleton keeps explicit inline height and display none hints" {
  let style = @style.Style::default()
  let hinted = apply_skeleton_inline_style_hints(
    style, "height: 64px; display: none; align-items: center",
  )
  inspect(hinted.height, content="Length(64)")
  inspect(hinted.display, content="None")
}

///|
test "viewport skeleton collapses definite height subtrees" {
  let style = @style.Style::default()
  style.height = @types.Length(64.0)
  inspect(should_collapse_viewport_skeleton_subtree(style), content="true")
  style.display = @types.Contents
  inspect(should_collapse_viewport_skeleton_subtree(style), content="false")
}

///|
test "viewport skeleton explicit size hints are limited to scroll containers" {
  let visible_parent = @style.Style::default()
  inspect(
    skeleton_parent_allows_explicit_size_hints(Some(visible_parent)),
    content="false",
  )
  let scroll_parent = @style.Style::default()
  scroll_parent.overflow_y = @types.Auto
  inspect(
    skeleton_parent_allows_explicit_size_hints(Some(scroll_parent)),
    content="true",
  )
}

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

///|
fn count_nodes_with_id_prefix(node : @node.Node, prefix : String) -> Int {
  let mut count = if node.id.has_prefix(prefix) { 1 } else { 0 }
  for child in node.children {
    count += count_nodes_with_id_prefix(child, prefix)
  }
  count
}

///|
fn many_image_document(count : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!doctype html><html><body style='margin:0'>")
  for i in 0..<count {
    buf.write_string(
      "<div style='height:12px'><img src='data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==' style='width:10px;height:10px' alt='" +
      i.to_string() +
      "'></div>",
    )
  }
  buf.write_string("</body></html>")
  buf.to_string()
}

///|
test "full document render disables viewport skeleton culling" {
  let html = many_image_document(360)
  let ctx = RenderContext::default()
  let previous_cutoff = viewport_full_node_cutoff.val
  viewport_full_node_cutoff.val = 0
  ignore(render_to_node_and_layout(html, ctx))
  let normal_skeletons = viewport_skeleton_count.val
  let (full_node, _) = render_to_node_and_layout_full_document(html, ctx)
  let full_skeletons = viewport_skeleton_count.val
  viewport_full_node_cutoff.val = previous_cutoff

  let full_images = count_nodes_with_id_prefix(full_node, "img")
  assert_true(normal_skeletons > 0)
  assert_eq(full_skeletons, 0)
  assert_eq(full_images, 360)
}

///|
test "viewport skeleton keeps dense above fold content before y cutoff" {
  let html = many_image_document(120)
  let ctx = RenderContext::default()
  ignore(render_to_node_and_layout(html, ctx))
  assert_eq(viewport_skeleton_count.val, 0)
}

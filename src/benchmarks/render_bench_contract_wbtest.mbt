///|
fn node_measure_exists(node : @node.Node) -> Bool {
  match node.measure {
    Some(_) => true
    None => false
  }
}

///|
fn node_shapes_equal(left : @node.Node, right : @node.Node) -> Bool {
  if left.id != right.id ||
    left.text != right.text ||
    left.src != right.src ||
    left.style.display != right.style.display ||
    left.style.position != right.style.position ||
    left.style.font_weight != right.style.font_weight ||
    left.style.text_decoration_underline !=
    right.style.text_decoration_underline ||
    node_measure_exists(left) != node_measure_exists(right) ||
    left.children.length() != right.children.length() {
    return false
  }
  for i = 0; i < left.children.length(); i = i + 1 {
    if !node_shapes_equal(left.children[i], right.children[i]) {
      return false
    }
  }
  true
}

///|
test "large 2k5 node build split preserves render tree shape" {
  let ctx = large_2k5_node_build_bench_ctx()
  let external_css = large_2k5_node_build_bench_external_css()
  let expected = @renderer.render_to_node_with_document(
    large_2k5_node_build_bench_doc(),
    ctx,
    external_css,
  )
  let prepared = @renderer.prepare_render_document(
    large_2k5_node_build_bench_doc(),
    ctx,
    external_css,
  )
  let actual = @renderer.build_render_root_node(
    large_2k5_node_build_bench_doc(),
    ctx,
    prepared,
  )
  assert_true(node_shapes_equal(actual, expected))
}

///|
test "static snapshot benchmark fixtures are renderable and trimmed" {
  let full = static_snapshot_full_reference_html()
  let trimmed = static_snapshot_trimmed_viewport_html()
  assert_true(full.length() > 60000)
  assert_true(trimmed.length() > 8000)
  assert_true(trimmed.length() * 4 < full.length())
  let _ = @renderer.render_to_node_and_layout(
    trimmed,
    static_snapshot_context(),
  )
}

///|
test "mdn static snapshot benchmark fixture uses viewport trim" {
  let full = static_snapshot_mdn_full_html()
  let trimmed = static_snapshot_mdn_trimmed_html()
  assert_true(full.length() > 100000)
  assert_true(trimmed.length() > 10000)
  assert_true(trimmed.length() < full.length())
  assert_true(trimmed.contains("crater-vrt-truncated-static-html"))
  let _ = @html.parse_document(trimmed)
}

///|
test "static snapshot scale fixtures are renderable" {
  let long_text = static_snapshot_long_paragraph_html(500)
  let links = static_snapshot_inline_links_html(100)
  let blocks = static_snapshot_block_paragraphs_html(100)
  assert_true(long_text.length() > 5000)
  assert_true(links.length() > 3000)
  assert_true(blocks.length() > 6000)
  let _ = @renderer.render_to_node(long_text, static_snapshot_context())
  let _ = @renderer.render_to_node(links, static_snapshot_context())
  let _ = @renderer.render_to_node(blocks, static_snapshot_context())
}

///|
test "pathological whitespace node fixture is renderable" {
  let node = static_snapshot_pathological_whitespace_nodes(10)
  assert_eq(node.children.length(), 10)
  let layout_ctx = default_layout_ctx(static_snapshot_context())
  let _ = @tree.compute_layout_in_context(node, layout_ctx)
}

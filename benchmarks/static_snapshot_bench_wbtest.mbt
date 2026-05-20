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
fn synthetic_main_trim_fixture() -> String {
  let before_main = StringBuilder::new()
  for i = 0; i < 260; i = i + 1 {
    before_main.write_string("<div>preface ")
    before_main.write_string(i.to_string())
    before_main.write_string("</div>")
  }
  let main = StringBuilder::new()
  for i = 0; i < 260; i = i + 1 {
    main.write_string("<p>main paragraph ")
    main.write_string(i.to_string())
    main.write_string(" keeps enough content for first viewport sizing.</p>")
  }
  "<!DOCTYPE html><html><body>" +
  before_main.to_string() +
  "<main>" +
  main.to_string() +
  "</main></body></html>"
}

///|
test "static snapshot viewport trim keeps body and main excerpts" {
  let full = synthetic_main_trim_fixture()
  let trimmed = js_trim_static_html_for_viewport(full, 1000, 4000)
  assert_true(full.length() > 10000)
  assert_true(trimmed.length() > 5000)
  assert_true(trimmed.length() < full.length())
  assert_true(trimmed.contains("crater-vrt-skipped-static-html"))
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

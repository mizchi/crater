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

///|
test "actual paint document dimensions ignore fixed node overflow" {
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff;height:420px'><main style='height:420px;background:#ffffff'></main><div style='position:fixed;left:0;top:2500px;width:80px;height:20px;background:#000000'></div></body></html>"
  let ctx = @browser_helpers.create_render_context(320, 240, false)
  let (node, layout) = @renderer.render_to_node_and_layout_full_document(
    html, ctx,
  )
  let (width, height) = @rendering.actual_paint_document_dimensions_from_node_and_layout(
    node, layout, 320, 240,
  )
  assert_eq(width, 320)
  assert_eq(height, 420)
}

///|
test "actual paint document dimensions keep collapsed top margin overflow" {
  let html = "<!DOCTYPE html><html><body style='margin:0'><div style='margin-top:2000px'>foo</div></body></html>"
  let ctx = @browser_helpers.create_render_context(1024, 768, false)
  let (node, layout) = @renderer.render_to_node_and_layout_full_document(
    html, ctx,
  )
  let (_, height) = @rendering.actual_paint_document_dimensions_from_node_and_layout(
    node, layout, 1024, 768,
  )
  assert_true(height > 768)
}

///|
test "font aware text provider is used for generic and named families" {
  assert_true(should_use_font_aware_text_provider("serif"))
  assert_true(should_use_font_aware_text_provider("sans-serif"))
  assert_true(should_use_font_aware_text_provider("monospace"))
  assert_true(should_use_font_aware_text_provider("Times New Roman"))
  assert_true(should_use_font_aware_text_provider("\"Georgia\", serif"))
}

///|
test "font aware text provider skips empty and inherited keywords" {
  assert_false(should_use_font_aware_text_provider(""))
  assert_false(should_use_font_aware_text_provider("   "))
  assert_false(should_use_font_aware_text_provider("inherit"))
  assert_false(should_use_font_aware_text_provider("initial"))
  assert_false(should_use_font_aware_text_provider("unset"))
  assert_false(should_use_font_aware_text_provider("revert"))
  assert_false(should_use_font_aware_text_provider("revert-layer"))
}

///|
fn actual_paint_test_layout(
  id : String,
  x? : Double = 0.0,
  y? : Double = 0.0,
  width~ : Double,
  height~ : Double,
  overflow_x? : @types.Overflow = @types.Visible,
  overflow_y? : @types.Overflow = @types.Visible,
  scroll_width? : Double = 0.0,
  scroll_height? : Double = 0.0,
  children? : Array[@types.Layout] = [],
) -> @types.Layout {
  {
    id,
    x,
    y,
    width,
    height,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    overflow_x,
    overflow_y,
    scroll_width,
    scroll_height,
    children,
    text: None,
  }
}

///|
fn actual_paint_test_document_dimensions_from_layout(
  layout : @types.Layout,
  viewport_width : Int,
  viewport_height : Int,
) -> (Int, Int) {
  let width = actual_paint_layout_content_right(layout).ceil().to_int()
  let height = actual_paint_layout_content_bottom(layout).ceil().to_int()
  (width.max(viewport_width).max(1), height.max(viewport_height).max(1))
}

///|
test "actual paint document width keeps visible horizontal overflow" {
  let root = actual_paint_test_layout(
    "body",
    width=320.0,
    height=180.0,
    scroll_width=320.0,
    scroll_height=180.0,
    children=[
      actual_paint_test_layout(
        "div.wide",
        width=800.0,
        height=20.0,
        scroll_width=800.0,
        scroll_height=20.0,
      ),
    ],
  )
  let (width, height) = actual_paint_test_document_dimensions_from_layout(
    root, 320, 180,
  )
  assert_eq(width, 800)
  ignore(height)
}

///|
test "actual paint document width ignores clipped descendant overflow" {
  let root = actual_paint_test_layout(
    "body",
    width=320.0,
    height=180.0,
    scroll_width=320.0,
    scroll_height=180.0,
    children=[
      actual_paint_test_layout(
        "div.announcer",
        x=-1.0,
        y=-1.0,
        width=1.0,
        height=1.0,
        overflow_x=@types.Hidden,
        overflow_y=@types.Hidden,
        scroll_width=6320.0,
        scroll_height=64.0,
        children=[
          actual_paint_test_layout(
            "#text",
            width=6320.0,
            height=16.0,
            scroll_width=6320.0,
            scroll_height=16.0,
          ),
        ],
      ),
    ],
  )
  let (width, height) = actual_paint_test_document_dimensions_from_layout(
    root, 320, 180,
  )
  assert_eq(width, 320)
  ignore(height)
}

///|
test "actual paint document dimensions ignore fixed node overflow" {
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff;height:420px'><main style='height:420px;background:#ffffff'></main><div style='position:fixed;left:0;top:2500px;width:80px;height:20px;background:#000000'></div></body></html>"
  let ctx = @browser_contract.create_render_context(320, 240, false)
  let (node, layout) = @renderer.render_to_node_and_layout_full_document(
    html, ctx,
  )
  let (width, height) = actual_paint_document_dimensions_from_node_and_layout(
    node, layout, 320, 240,
  )
  assert_eq(width, 320)
  assert_eq(height, 420)
}

///|
test "actual paint document dimensions keep collapsed top margin overflow" {
  let html = "<!DOCTYPE html><html><body style='margin:0'><div style='margin-top:2000px'>foo</div></body></html>"
  let ctx = @browser_contract.create_render_context(1024, 768, false)
  let (node, layout) = @renderer.render_to_node_and_layout_full_document(
    html, ctx,
  )
  let (_, height) = actual_paint_document_dimensions_from_node_and_layout(
    node, layout, 1024, 768,
  )
  assert_true(height > 768)
}

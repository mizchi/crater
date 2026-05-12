///|
// Public render API contract tests split from renderer_test.mbt.

///|
test "layout_to_json serializes box model fields without changing schema" {
  let child : @types.Layout = {
    id: "child",
    x: 5.0,
    y: 6.0,
    width: 7.0,
    height: 8.0,
    margin: @types.Rect::all(0.0),
    padding: @types.Rect::all(1.0),
    border: @types.Rect::all(2.0),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 7.0,
    scroll_height: 8.0,
    children: [],
    text: None,
  }
  let layout : @types.Layout = {
    id: "root",
    x: 1.0,
    y: 2.0,
    width: 3.0,
    height: 4.0,
    margin: @types.Rect::all(0.0),
    padding: @types.Rect::all(0.0),
    border: @types.Rect::all(0.0),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 3.0,
    scroll_height: 4.0,
    children: [child],
    text: None,
  }
  assert_eq(
    @renderer.layout_to_json(layout),
    "{\"id\":\"root\",\"x\":1,\"y\":2,\"width\":3,\"height\":4,\"margin\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"padding\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"border\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"children\":[{\"id\":\"child\",\"x\":5,\"y\":6,\"width\":7,\"height\":8,\"margin\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"padding\":{\"top\":1,\"right\":1,\"bottom\":1,\"left\":1},\"border\":{\"top\":2,\"right\":2,\"bottom\":2,\"left\":2},\"children\":[]}]}",
  )
}

///|
test "render_to_node_and_layout_with_external_css is stable across repeated calls" {
  let html =
    #|<div id="target" class="card"><span>hello</span></div>
  let ctx = @renderer.RenderContext::default()
  let external_css = [
    ".card { display: flex; gap: 8px; padding: 12px; border: 1px solid black; }",
    "#target span { display: inline-block; width: 40px; height: 20px; }",
  ]
  let (_, layout1) = @renderer.render_to_node_and_layout_with_external_css(
    html, ctx, external_css,
  )
  let (_, layout2) = @renderer.render_to_node_and_layout_with_external_css(
    html, ctx, external_css,
  )
  assert_eq(
    @renderer.layout_to_json(layout1),
    @renderer.layout_to_json(layout2),
  )
}

///|
test "prepared external css renders same layout as css array path" {
  let html =
    #|<!doctype html>
    #|<html><head><style>.local { height: 18px; }</style></head>
    #|<body><div id="target" class="card local"><span>hello</span></div></body></html>
  let ctx = @renderer.RenderContext::default()
  let external_css = [
    ".card { display: flex; gap: 8px; padding: 12px; border: 1px solid black; }",
    "#target span { display: inline-block; width: 40px; height: 20px; }",
  ]
  let doc = @html.parse_document(html)
  let prepared_external_css = @renderer.prepare_external_css(external_css)
  let (_, expected) = @renderer.render_to_node_and_layout_with_document(
    doc, ctx, external_css,
  )
  let (_, actual) = @renderer.render_to_node_and_layout_with_prepared_external_css(
    doc, ctx, prepared_external_css,
  )
  assert_eq(
    @renderer.layout_to_json(actual),
    @renderer.layout_to_json(expected),
  )
}

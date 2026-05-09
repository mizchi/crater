///|
test "vrt package renders paint tree json" {
  let html =
    #|<!DOCTYPE html><body><div style="width: 100px; height: 50px;">hello</div></body>
  let json = render_html_to_paint_tree_json(
    html,
    @types.Size::new(320.0, 200.0),
  )
  assert_true(json.contains("\"id\":\"div\""))
}

///|
test "vrt package renders batch variants" {
  let html =
    #|<html><body><div class="box" style="width: 100px; height: 50px; background: red;">hello</div></body></html>
  let viewport = @types.Size::new(800.0, 600.0)
  let variants : Array[RenderVariant] = [
    { id: "baseline", mutations: [] },
    {
      id: "wider",
      mutations: [
        {
          selector: ".box",
          property: "width",
          action: CssMutationAction::Override("200px"),
        },
      ],
    },
  ]
  let results = render_html_batch_variants(html, viewport, variants)
  assert_eq(results.length(), 2)
  assert_eq(results[0].id, "baseline")
  assert_eq(results[1].id, "wider")
}

///|
test "vrt prepared page matches direct paint tree rendering" {
  let html =
    #|<html><body><section class="box"><h1>Prepared</h1><p>cached css and document</p></section></body></html>
  let viewport = @types.Size::new(640.0, 480.0)
  let css = prepare_external_css([
    ".box { width: 240px; height: 120px; padding: 16px; background: #ffffff; }",
    ".box h1 { margin: 0 0 8px; font-size: 24px; }",
  ])
  let prepared = prepare_vrt_page_with_prepared_external_css(
    html, viewport, css,
  )
  let expected = render_html_to_paint_tree_with_prepared_external_css(
    html, viewport, css,
  ).to_json_string()
  let actual = render_prepared_vrt_page_to_paint_tree(prepared).to_json_string()
  assert_eq(actual, expected)
}

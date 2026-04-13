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

///|
test "render_html_batch_variants baseline" {
  let html =
    #|<html><body><div style="width: 100px; height: 50px; background: red;">hello</div></body></html>
  let viewport = @types.Size::new(800.0, 600.0)
  let variants : Array[RenderVariant] = [{ id: "baseline", mutations: [] }]
  let results = render_html_batch_variants(html, viewport, variants)
  assert_eq(results.length(), 1)
  assert_eq(results[0].id, "baseline")
}

///|
test "render_html_batch_variants with override" {
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
test "render_html_batch_variants with remove" {
  let html =
    #|<html><body><div class="box" style="width: 100px; height: 50px; padding: 10px;">hello</div></body></html>
  let viewport = @types.Size::new(800.0, 600.0)
  let variants : Array[RenderVariant] = [
    { id: "baseline", mutations: [] },
    {
      id: "no-padding",
      mutations: [
        {
          selector: ".box",
          property: "padding",
          action: CssMutationAction::Remove,
        },
      ],
    },
  ]
  let results = render_html_batch_variants(html, viewport, variants)
  assert_eq(results.length(), 2)
  assert_eq(results[0].id, "baseline")
  assert_eq(results[1].id, "no-padding")
}

///|
test "create_render_context sets light scheme by default flag" {
  let ctx = create_render_context(320, 240, false)
  inspect(ctx.viewport_width, content="320")
  inspect(ctx.viewport_height, content="240")
  match ctx.color_scheme {
    @media.Light => ()
    _ => assert_true(false)
  }
}

///|
test "create_render_context sets dark scheme when enabled" {
  let ctx = create_render_context(320, 240, true)
  match ctx.color_scheme {
    @media.Dark => ()
    _ => assert_true(false)
  }
}

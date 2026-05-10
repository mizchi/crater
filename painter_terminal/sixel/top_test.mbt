///|
test "to_sixel basic output" {
  let fb = Framebuffer::new(4, 6)
  fb.fill_rect(0, 0, 4, 6, 1)
  let result = to_sixel(fb)
  inspect(result.has_prefix("\u001bPq"), content="true")
  inspect(result.has_suffix("\u001b\\"), content="true")
}

///|
test "to_sixel_dynamic preserves deterministic mixed color rows" {
  let fb = Framebuffer::new(2, 6)
  let palette = DynamicPalette::new()
  palette.colors.push(Color::blue())
  palette.colors.push(Color::red())
  fb.fill_rect(0, 0, 1, 6, 1)
  fb.fill_rect(1, 0, 1, 6, 2)
  let result = to_sixel_dynamic(fb, palette)
  assert_eq(
    result, "\u001bPq#0;2;100;100;100#1;2;25;52;95#2;2;91;26;20#1~?$#2?~$-\u001b\\",
  )
}

///|
test "to_sixel_dynamic compresses repeated columns with repeat introducer" {
  let fb = Framebuffer::new(4, 6)
  let palette = DynamicPalette::new()
  palette.colors.push(Color::blue())
  fb.fill_rect(0, 0, 4, 6, 1)
  let result = to_sixel_dynamic(fb, palette)
  assert_eq(result, "\u001bPq#0;2;100;100;100#1;2;25;52;95#1!4~$-\u001b\\")
}

///|
test "render_layout simple" {
  let layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 100.0,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: [],
    text: None,
  }
  let sixel = render_layout(layout, 100, 100)
  inspect(sixel.has_prefix("\u001bPq"), content="true")
  inspect(sixel.has_suffix("\u001b\\"), content="true")
}

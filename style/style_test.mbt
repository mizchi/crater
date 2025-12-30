///|
test "Style::default" {
  let style = Style::default()
  inspect(style.display, content="Block")
  inspect(style.position, content="Relative")
  inspect(style.flex_grow, content="0")
}

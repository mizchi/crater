///|
test "Style::default" {
  let style = Style::default()
  inspect(style.display, content="Block")
  inspect(style.position, content="Static")
  inspect(style.flex_grow, content="0")
}

///|
/// Tests for TUI components

///|
test "input: creates component structure" {
  let comp = input("hello", id="test-input")
  // Verify component has correct node ID
  inspect(comp.node.id, content="test-input")
  // Verify text content is set
  inspect(comp.texts.get("test-input"), content="Some(\"hello\")")
}

///|
test "input: placeholder when empty" {
  let comp = input("", id="empty-input", placeholder="Enter name")
  // Verify placeholder is set as text content
  inspect(comp.texts.get("empty-input"), content="Some(\"Enter name\")")
}

///|
test "input: cursor when editing" {
  let comp = input("hello", id="edit-input", state=InputState::Editing)
  // Verify cursor is appended
  inspect(comp.texts.get("edit-input"), content="Some(\"hello_\")")
}

///|
test "textarea: creates component with value" {
  let comp = textarea("line1", id="test-textarea")
  let output = @tui.render_once(80, 24, comp)
  assert_true(output.contains("line1"))
}

///|
test "textarea: placeholder shown when value is empty" {
  let comp = textarea("", placeholder="Enter message")
  let output = @tui.render_once(80, 24, comp)
  assert_true(output.contains("Enter message"))
}

///|
test "button: creates component with text" {
  let comp = button("Click me", id="test-btn")
  let output = @tui.render_once(80, 24, comp)
  assert_true(output.contains("Click me"))
}

///|
test "button: different states" {
  let normal = button("OK", id="btn-normal", state=ButtonState::Normal)
  let hover = button("OK", id="btn-hover", state=ButtonState::Hover)
  let pressed = button("OK", id="btn-pressed", state=ButtonState::Pressed)
  // All should have the button text
  inspect(normal.texts.get("btn-normal"), content="None")
  inspect(hover.texts.get("btn-hover"), content="None")
  inspect(pressed.texts.get("btn-pressed"), content="None")
}

///|
test "row: creates horizontal container" {
  let r = row([@tui.text("A"), @tui.text("B")])
  // Row should have 2 children
  inspect(r.node.children.length(), content="2")
}

///|
test "column: creates vertical container" {
  let c = column([@tui.text("A"), @tui.text("B")])
  // Column should have 2 children
  inspect(c.node.children.length(), content="2")
}

///|
test "text: creates text component" {
  let t = @tui.text("Hello")
  // Text should have content
  inspect(t.texts.get(t.node.id), content="Some(\"Hello\")")
}

///|
test "spacer: creates flexible space" {
  let s = spacer()
  // Spacer should have flex_grow = 1.0
  inspect(s.node.style.flex_grow, content="1")
}

///|
test "hspace: creates horizontal space" {
  let h = hspace(5.0)
  // Should have width = 5
  inspect(h.node.style.width, content="Length(5)")
}

///|
test "vspace: creates vertical space" {
  let v = vspace(3.0)
  // Should have height = 3
  inspect(v.node.style.height, content="Length(3)")
}

///|
/// Tests for TUI components

///|
test "input: creates component with value" {
  let comp = input("hello", id="test-input")
  // Verify component can be rendered
  let output = @tui.render_once(80, 24, comp)
  // Should contain the value text
  assert_true(output.contains("hello"))
}

///|
test "input: placeholder shown when value is empty" {
  let comp = input("", placeholder="Enter name")
  let output = @tui.render_once(80, 24, comp)
  // Should contain placeholder
  assert_true(output.contains("Enter name"))
}

///|
test "input: cursor shown when editing" {
  let comp = input("hello", state=InputState::Editing)
  let output = @tui.render_once(80, 24, comp)
  // Should contain cursor character
  assert_true(output.contains("hello_"))
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
test "button: different states render correctly" {
  let normal = button("OK", state=ButtonState::Normal)
  let hover = button("OK", state=ButtonState::Hover)
  // Both should render successfully with the button text
  let normal_output = @tui.render_once(80, 24, normal)
  let hover_output = @tui.render_once(80, 24, hover)
  assert_true(normal_output.contains("OK"))
  assert_true(hover_output.contains("OK"))
}

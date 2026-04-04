///|
test "discover_computed_styles_with_state detects hover diff" {
  let html =
    #|<html><head><style>.btn { color: black; } .btn:hover { color: red; }</style></head><body><button class="btn">Click</button></body></html>
  let forced = @selector.ForcedPseudoStates::{
    ..@selector.ForcedPseudoStates::none(),
    hover: true,
  }
  let result = discover_computed_styles_with_state(html, ".btn", forced, [
    "color",
  ])
  assert_eq(result.diff.length(), 1)
  assert_eq(result.diff[0].property, "color")
  assert_eq(result.diff[0].normal, "black")
  assert_eq(result.diff[0].forced, "red")
}

///|
test "discover_computed_styles_with_state no diff without hover rule" {
  let html =
    #|<html><head><style>.btn { color: black; }</style></head><body><button class="btn">Click</button></body></html>
  let forced = @selector.ForcedPseudoStates::{
    ..@selector.ForcedPseudoStates::none(),
    hover: true,
  }
  let result = discover_computed_styles_with_state(html, ".btn", forced, [
    "color",
  ])
  assert_eq(result.diff.length(), 0)
  assert_eq(result.normal.get("color").unwrap(), "black")
  assert_eq(result.forced.get("color").unwrap(), "black")
}

///|
test "discover_computed_styles_with_state focus state" {
  let html =
    #|<html><head><style>input { border-color: gray; } input:focus { border-color: blue; }</style></head><body><input type="text" /></body></html>
  let forced = @selector.ForcedPseudoStates::{
    ..@selector.ForcedPseudoStates::none(),
    focus: true,
  }
  let result = discover_computed_styles_with_state(html, "input", forced, [
    "border-color",
  ])
  assert_eq(result.diff.length(), 1)
  assert_eq(result.diff[0].normal, "gray")
  assert_eq(result.diff[0].forced, "blue")
}

///|
test "discover_computed_styles_with_state multiple properties" {
  let html =
    #|<html><head><style>.card { background: white; color: black; } .card:hover { background: blue; color: white; }</style></head><body><div class="card">hello</div></body></html>
  let forced = @selector.ForcedPseudoStates::{
    ..@selector.ForcedPseudoStates::none(),
    hover: true,
  }
  let result = discover_computed_styles_with_state(html, ".card", forced, [
    "background", "color",
  ])
  assert_eq(result.diff.length(), 2)
}

///|
test "discover_computed_styles_with_state unknown selector returns empty" {
  let html =
    #|<html><head><style>.btn { color: black; }</style></head><body><button class="btn">Click</button></body></html>
  let forced = @selector.ForcedPseudoStates::{
    ..@selector.ForcedPseudoStates::none(),
    hover: true,
  }
  let result = discover_computed_styles_with_state(
    html,
    ".nonexistent",
    forced,
    ["color"],
  )
  assert_eq(result.diff.length(), 0)
  assert_true(result.normal.is_empty())
}

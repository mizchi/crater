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

///|
test "discover_all_computed_styles returns selector keyed styles for all elements" {
  let html =
    #|<html><body><div id="card" style="display:flex">card</div><span id="badge" style="color:rgb(255, 0, 0)">badge</span></body></html>
  let result = discover_all_computed_styles(html, ["display", "color"])
  let card_styles = result.get("div#card").unwrap()
  let badge_styles = result.get("span#badge").unwrap()
  assert_eq(card_styles.get("display").unwrap(), "flex")
  assert_eq(badge_styles.get("color").unwrap(), "rgb(255, 0, 0)")
}

///|
test "discover_all_computed_styles resolves :state from internal render attribute" {
  let html =
    #|<html><head><style>x-panel { color: black; } x-panel:state(open) { color: red; }</style></head><body><x-panel id="panel" data-crater-custom-states="open">hello</x-panel></body></html>
  let result = discover_all_computed_styles(html, ["color"])
  let panel_styles = result.get("x-panel#panel").unwrap()
  assert_eq(panel_styles.get("color").unwrap(), "red")
}

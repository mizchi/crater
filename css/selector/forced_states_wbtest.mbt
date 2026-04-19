///|
fn must_parse(css : String) -> ComplexSelector {
  parse_selector_text(css).unwrap()
}

///|
test "matches_complex_with_forced_states hover" {
  let selector = must_parse(".btn:hover")
  let element = Element::new("button").add_class("btn")
  assert_false(matches_complex(element, selector))
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), hover: true }
  assert_true(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "matches_complex_with_forced_states focus" {
  let selector = must_parse("input:focus")
  let element = Element::new("input")
  assert_false(matches_complex(element, selector))
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), focus: true }
  assert_true(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "matches_complex_with_forced_states does not match wrong pseudo" {
  let selector = must_parse(".btn:hover")
  let element = Element::new("button").add_class("btn")
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), focus: true }
  assert_false(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "matches_complex_with_forced_states hover and focus combined" {
  let selector = must_parse(".btn:hover:focus")
  let element = Element::new("button").add_class("btn")
  let hover_only = ForcedPseudoStates::{
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(
    matches_complex_with_forced_states(element, selector, hover_only),
  )
  let both = ForcedPseudoStates::{
    ..ForcedPseudoStates::none(),
    hover: true,
    focus: true,
  }
  assert_true(matches_complex_with_forced_states(element, selector, both))
}

///|
test "matches_complex_with_forced_states with parent selector" {
  let selector = must_parse(".container .btn:hover")
  let parent = Element::new("div").add_class("container")
  let element = Element::new("button").add_class("btn").set_parent(parent)
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), hover: true }
  assert_true(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "ForcedPseudoStates none is empty" {
  assert_true(ForcedPseudoStates::none().is_empty())
  assert_false(
    ForcedPseudoStates::{ ..ForcedPseudoStates::none(), hover: true }.is_empty(),
  )
}

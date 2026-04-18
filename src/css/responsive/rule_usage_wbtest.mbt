///|
test "discover_css_rule_usage reports unmatched and overridden rules" {
  let html = "<style>.unused { color: red; } .card { color: red; } div.card { color: blue; } .chip { padding: 4px; }</style><div id='card' class='card'>A</div><div id='chip' class='chip'>B</div>"
  let result = discover_css_rule_usage(html)
  assert_eq(result.length(), 4)

  let unused = result[0]
  assert_eq(unused.selector, ".unused")
  assert_eq(unused.matched, false)
  assert_eq(unused.elements, 0)
  assert_eq(unused.overridden, false)
  match unused.overridden_by {
    None => ()
    Some(_) => assert_true(false)
  }

  let overridden = result[1]
  assert_eq(overridden.selector, ".card")
  assert_eq(overridden.matched, true)
  assert_eq(overridden.elements, 1)
  assert_eq(overridden.overridden, true)
  match overridden.overridden_by {
    Some(value) => assert_eq(value, "div.card")
    None => assert_true(false)
  }

  let effective = result[2]
  assert_eq(effective.selector, "div.card")
  assert_eq(effective.matched, true)
  assert_eq(effective.elements, 1)
  assert_eq(effective.overridden, false)
  match effective.overridden_by {
    None => ()
    Some(_) => assert_true(false)
  }

  let chip = result[3]
  assert_eq(chip.selector, ".chip")
  assert_eq(chip.matched, true)
  assert_eq(chip.elements, 1)
  assert_eq(chip.overridden, false)
  match chip.overridden_by {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "discover_css_effective_property_sources reports winning selectors per element" {
  let html = "<style>.card { color: red; padding: 8px; } div.card { color: blue; } .chip { padding: 4px; }</style><div id='card' class='card' style='margin: 2px'>A</div><div id='chip' class='chip'>B</div>"
  let result = discover_css_effective_property_sources(html)

  let card = result.get("div#card").unwrap()
  assert_eq(card.get("color").unwrap(), "div.card")
  assert_eq(card.get("padding").unwrap(), ".card")
  assert_eq(card.get("margin").unwrap(), "<inline style>")

  let chip = result.get("div#chip").unwrap()
  assert_eq(chip.get("padding").unwrap(), ".chip")
}

///|
test "discover_css_rule_usage marks inherited and initial no-op rules" {
  let html = "<style>.wrapper { color: red; } .child { color: red; } .box { margin: 0; }</style><div class='wrapper'><span class='child'>A</span></div><div class='box'>B</div>"
  let result = discover_css_rule_usage(html)
  assert_eq(result.length(), 3)

  let wrapper = result[0]
  assert_eq(wrapper.selector, ".wrapper")
  assert_eq(wrapper.no_effect, false)

  let child = result[1]
  assert_eq(child.selector, ".child")
  assert_eq(child.matched, true)
  assert_eq(child.overridden, false)
  assert_eq(child.no_effect, true)
  match child.no_effect_reason {
    Some(value) => assert_eq(value, "same_as_inherited")
    None => assert_true(false)
  }

  let box = result[2]
  assert_eq(box.selector, ".box")
  assert_eq(box.matched, true)
  assert_eq(box.overridden, false)
  assert_eq(box.no_effect, true)
  match box.no_effect_reason {
    Some(value) => assert_eq(value, "same_as_initial")
    None => assert_true(false)
  }
}

///|
test "discover_css_rule_usage marks winning rules that match fallback values as no-op" {
  let html = "<style>.card { color: red; } div.card { color: red; }</style><div class='card'>A</div>"
  let result = discover_css_rule_usage(html)
  assert_eq(result.length(), 2)

  let base = result[0]
  assert_eq(base.selector, ".card")
  assert_eq(base.overridden, true)
  match base.overridden_by {
    Some(value) => assert_eq(value, "div.card")
    None => assert_true(false)
  }

  let duplicate = result[1]
  assert_eq(duplicate.selector, "div.card")
  assert_eq(duplicate.matched, true)
  assert_eq(duplicate.overridden, false)
  assert_eq(duplicate.no_effect, true)
  match duplicate.no_effect_reason {
    Some(value) => assert_eq(value, "same_as_fallback")
    None => assert_true(false)
  }
}

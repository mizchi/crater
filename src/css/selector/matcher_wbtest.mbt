///|
test "match type selector" {
  let elem = Element::new("div")
  let result = matches_selector_text(elem, "div")
  inspect(result, content="true")
}

///|
test "match type selector - no match" {
  let elem = Element::new("div")
  let result = matches_selector_text(elem, "span")
  inspect(result, content="false")
}

///|
test "match class selector" {
  let elem = Element::new("div").add_class("foo")
  let result = matches_selector_text(elem, ".foo")
  inspect(result, content="true")
}

///|
test "match class selector - no match" {
  let elem = Element::new("div").add_class("foo")
  let result = matches_selector_text(elem, ".bar")
  inspect(result, content="false")
}

///|
test "match id selector" {
  let elem = Element::new("div").set_id("main")
  let result = matches_selector_text(elem, "#main")
  inspect(result, content="true")
}

///|
test "match id selector - no match" {
  let elem = Element::new("div").set_id("main")
  let result = matches_selector_text(elem, "#other")
  inspect(result, content="false")
}

///|
test "match universal selector" {
  let elem = Element::new("div")
  let result = matches_selector_text(elem, "*")
  inspect(result, content="true")
}

///|
test "match compound selector" {
  let elem = Element::new("div").add_class("foo").set_id("bar")
  let result = matches_selector_text(elem, "div.foo#bar")
  inspect(result, content="true")
}

///|
test "match compound selector - partial match fails" {
  let elem = Element::new("div").add_class("foo")
  let result = matches_selector_text(elem, "div.foo#bar")
  inspect(result, content="false")
}

///|
test "match attribute exists" {
  let elem = Element::new("input").set_attribute("disabled", "")
  let result = matches_selector_text(elem, "[disabled]")
  inspect(result, content="true")
}

///|
test "match attribute exact" {
  let elem = Element::new("input").set_attribute("type", "button")
  let result = matches_selector_text(elem, "[type=button]")
  inspect(result, content="true")
}

///|
test "match attribute exact - no match" {
  let elem = Element::new("input").set_attribute("type", "text")
  let result = matches_selector_text(elem, "[type=button]")
  inspect(result, content="false")
}

///|
test "match first-child" {
  let elem = Element::new("div").set_sibling_info(1, 3)
  let result = matches_selector_text(elem, ":first-child")
  inspect(result, content="true")
}

///|
test "match first-child - no match" {
  let elem = Element::new("div").set_sibling_info(2, 3)
  let result = matches_selector_text(elem, ":first-child")
  inspect(result, content="false")
}

///|
test "match last-child" {
  let elem = Element::new("div").set_sibling_info(3, 3)
  let result = matches_selector_text(elem, ":last-child")
  inspect(result, content="true")
}

///|
test "match last-child - no match" {
  let elem = Element::new("div").set_sibling_info(2, 3)
  let result = matches_selector_text(elem, ":last-child")
  inspect(result, content="false")
}

///|
test "match nth-child 2n+1 (odd)" {
  // 1st, 3rd, 5th... should match
  let elem1 = Element::new("div").set_sibling_info(1, 5)
  let elem3 = Element::new("div").set_sibling_info(3, 5)
  let elem2 = Element::new("div").set_sibling_info(2, 5)
  inspect(matches_selector_text(elem1, ":nth-child(2n+1)"), content="true")
  inspect(matches_selector_text(elem3, ":nth-child(2n+1)"), content="true")
  inspect(matches_selector_text(elem2, ":nth-child(2n+1)"), content="false")
}

///|
test "match nth-child even" {
  // 2nd, 4th... should match
  let elem2 = Element::new("div").set_sibling_info(2, 5)
  let elem4 = Element::new("div").set_sibling_info(4, 5)
  let elem1 = Element::new("div").set_sibling_info(1, 5)
  inspect(matches_selector_text(elem2, ":nth-child(even)"), content="true")
  inspect(matches_selector_text(elem4, ":nth-child(even)"), content="true")
  inspect(matches_selector_text(elem1, ":nth-child(even)"), content="false")
}

///|
test "match root" {
  let root = Element::new("html")
  let child = Element::new("body").set_parent(root)
  inspect(matches_selector_text(root, ":root"), content="true")
  inspect(matches_selector_text(child, ":root"), content="false")
}

///|
test "match empty" {
  let empty_elem = Element::new("div")
  let non_empty = { ..Element::new("div"), children: [Element::new("span")] }
  inspect(matches_selector_text(empty_elem, ":empty"), content="true")
  inspect(matches_selector_text(non_empty, ":empty"), content="false")
}

///|
test "match child combinator" {
  let parent = Element::new("div").add_class("parent")
  let child = Element::new("p").set_parent(parent)
  let result = matches_selector_text(child, "div.parent > p")
  inspect(result, content="true")
}

///|
test "match child combinator - no match (not direct child)" {
  let grandparent = Element::new("div").add_class("parent")
  let parent = Element::new("span").set_parent(grandparent)
  let child = Element::new("p").set_parent(parent)

  // p is not a direct child of div.parent
  let result = matches_selector_text(child, "div.parent > p")
  inspect(result, content="false")
}

///|
test "match descendant combinator" {
  let grandparent = Element::new("div").add_class("parent")
  let parent = Element::new("span").set_parent(grandparent)
  let child = Element::new("p").set_parent(parent)

  // p is a descendant of div.parent
  let result = matches_selector_text(child, "div.parent p")
  inspect(result, content="true")
}

///|
test "match next-sibling combinator" {
  let first = Element::new("h1")
  let second = { ..Element::new("p"), prev_sibling: Some(first) }
  let result = matches_selector_text(second, "h1 + p")
  inspect(result, content="true")
}

///|
test "match :not pseudo-class" {
  let div = Element::new("div")
  let span = Element::new("span")
  inspect(matches_selector_text(div, ":not(span)"), content="true")
  inspect(matches_selector_text(span, ":not(span)"), content="false")
}

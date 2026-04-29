///|
/// Test helper: check if an element matches a CSS selector string
fn matches_selector_text(element : Element, css : String) -> Bool {
  match parse_selector_text(css) {
    Some(sel) => matches_complex(element, sel)
    None => false
  }
}

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

///|
test "match :not with class - .foo:not(.bar) matches element with foo but not bar" {
  let elem_foo = Element::new("div").add_class("foo")
  inspect(matches_selector_text(elem_foo, ".foo:not(.bar)"), content="true")
}

///|
test "match :not with class - .foo:not(.bar) does NOT match element with foo and bar" {
  let elem_foo_bar = Element::new("div").add_class("foo").add_class("bar")
  inspect(
    matches_selector_text(elem_foo_bar, ".foo:not(.bar)"),
    content="false",
  )
}

///|
test "match :state pseudo-class" {
  let open_elem = Element::new("x-panel").add_custom_state("open")
  let closed_elem = Element::new("x-panel")
  inspect(matches_selector_text(open_elem, ":state(open)"), content="true")
  inspect(
    matches_selector_text(open_elem, "x-panel:state(open)"),
    content="true",
  )
  inspect(matches_selector_text(closed_elem, ":state(open)"), content="false")
}

///|
test "static link pseudo classes do not match visited links" {
  let link = Element::new("a").set_attribute("href", "https://example.com")
  inspect(matches_selector_text(link, "a:link"), content="true")
  inspect(matches_selector_text(link, "a:any-link"), content="true")
  inspect(matches_selector_text(link, "a:visited"), content="false")
}

///|
test "match :not with class - body:not(.hidden) div matches div under body without hidden class" {
  let body = Element::new("body")
  let div = Element::new("div").set_parent(body)
  inspect(matches_selector_text(div, "body:not(.hidden) div"), content="true")
}

///|
test "match :not with class - body:not(.hidden) div does NOT match when body has hidden class" {
  let body = Element::new("body").add_class("hidden")
  let div = Element::new("div").set_parent(body)
  inspect(matches_selector_text(div, "body:not(.hidden) div"), content="false")
}

///|
test "match :not with class - Wikipedia-style body:not(.vector-sticky-header-visible)" {
  let body_without = Element::new("body")
  let div1 = Element::new("div")
    .add_class("vector-column-start")
    .set_parent(body_without)
  inspect(
    matches_selector_text(
      div1, "body:not(.vector-sticky-header-visible) .vector-column-start",
    ),
    content="true",
  )
  let body_with = Element::new("body").add_class("vector-sticky-header-visible")
  let div2 = Element::new("div")
    .add_class("vector-column-start")
    .set_parent(body_with)
  inspect(
    matches_selector_text(
      div2, "body:not(.vector-sticky-header-visible) .vector-column-start",
    ),
    content="false",
  )
}

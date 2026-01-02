///|
test "cascade precedence - author normal" {
  let prec = cascade_precedence(Author, Normal)
  inspect(prec, content="3")
}

///|
test "cascade precedence - author important" {
  let prec = cascade_precedence(Author, Important)
  inspect(prec, content="4")
}

///|
test "cascade precedence - important beats normal" {
  let prec_normal = cascade_precedence(Author, Normal)
  let prec_important = cascade_precedence(Author, Important)
  assert_true(prec_important > prec_normal)
}

///|
test "cascade precedence - user-agent important highest" {
  let prec_ua_important = cascade_precedence(UserAgent, Important)
  let prec_user_important = cascade_precedence(User, Important)
  let prec_author_important = cascade_precedence(Author, Important)
  assert_true(prec_ua_important > prec_user_important)
  assert_true(prec_user_important > prec_author_important)
}

///|
test "compare declarations - same origin, different specificity" {
  let decl_low : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 1 }, // type selector
    source_order: 0,
  }
  let decl_high : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 }, // class selector
    source_order: 0,
  }
  // Higher specificity wins
  assert_true(compare_declarations(decl_high, decl_low) > 0)
}

///|
test "compare declarations - same specificity, different source order" {
  let decl_first : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 },
    source_order: 1,
  }
  let decl_second : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 },
    source_order: 2,
  }
  // Later source order wins
  assert_true(compare_declarations(decl_second, decl_first) > 0)
}

///|
test "compare declarations - important beats normal" {
  let decl_normal : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 1, b: 0, c: 0 }, // ID selector
    source_order: 10,
  }
  let decl_important : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Important,
    specificity: { a: 0, b: 0, c: 1 }, // type selector
    source_order: 1,
  }
  // Important beats even higher specificity and later source order
  assert_true(compare_declarations(decl_important, decl_normal) > 0)
}

///|
test "cascade - single declaration" {
  let decl = Declaration::new("width", "100px")
  let result = cascade([decl])
  inspect(result.get_value("width"), content="Some(\"100px\")")
}

///|
test "cascade - later declaration wins" {
  let decl1 : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 },
    source_order: 1,
  }
  let decl2 : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 },
    source_order: 2,
  }
  let result = cascade([decl1, decl2])
  inspect(result.get_value("width"), content="Some(\"200px\")")
}

///|
test "cascade - higher specificity wins" {
  let decl_type : Declaration = {
    property: "color",
    value: Value("red"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 1 },
    source_order: 2,
  }
  let decl_class : Declaration = {
    property: "color",
    value: Value("blue"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 },
    source_order: 1,
  }
  let result = cascade([decl_type, decl_class])
  // Class wins over type even though type is later
  inspect(result.get_value("color"), content="Some(\"blue\")")
}

///|
test "cascade - important wins" {
  let decl_normal : Declaration = {
    property: "display",
    value: Value("block"),
    origin: Author,
    importance: Normal,
    specificity: { a: 1, b: 0, c: 0 },
    source_order: 10,
  }
  let decl_important : Declaration = {
    property: "display",
    value: Value("flex"),
    origin: Author,
    importance: Important,
    specificity: { a: 0, b: 0, c: 1 },
    source_order: 1,
  }
  let result = cascade([decl_normal, decl_important])
  inspect(result.get_value("display"), content="Some(\"flex\")")
}

///|
test "cascade - multiple properties" {
  let decl1 = Declaration::new("width", "100px")
  let decl2 = Declaration::new("height", "50px")
  let decl3 : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0 },
    source_order: 1,
  }
  let result = cascade([decl1, decl2, decl3])
  inspect(result.get_value("width"), content="Some(\"200px\")")
  inspect(result.get_value("height"), content="Some(\"50px\")")
}

///|
test "cascaded values - has property" {
  let decl = Declaration::new("margin", "10px")
  let result = cascade([decl])
  inspect(result.has("margin"), content="true")
  inspect(result.has("padding"), content="false")
}

///|
test "cascaded values - properties list" {
  let decl1 = Declaration::new("width", "100px")
  let decl2 = Declaration::new("height", "50px")
  let result = cascade([decl1, decl2])
  let props = result.properties()
  inspect(props.length(), content="2")
}

///|
test "declaration from inline" {
  let decl = Declaration::from_inline("width", "100px", Normal)
  inspect(decl.origin, content="Author")
  // Inline has high specificity
  assert_true(decl.specificity.a >= 1)
}

///|
test "collect declarations - inline beats rules" {
  let rule_match : RuleMatch = {
    specificity: { a: 1, b: 0, c: 0 }, // ID selector
    declarations: [Declaration::new("width", "100px")],
    source_order: 1,
  }
  let inline = [Declaration::from_inline("width", "200px", Normal)]
  let collected = collect_declarations([rule_match], inline)
  let result = cascade(collected)

  // Inline should win
  inspect(result.get_value("width"), content="Some(\"200px\")")
}

///|
test "stylesheet match and cascade" {
  // Create a simple stylesheet
  let stylesheet = Stylesheet::new(Author)

  // Parse a selector
  let sel = @selector.parse_selector_text("div.foo")
  match sel {
    Some(selector) =>
      stylesheet.add_rule("div.foo", selector, [
        Declaration::new("width", "100px"),
      ])
    None => fail("failed to parse selector")
  }

  // Create an element that matches
  let element = @selector.Element::new("div").add_class("foo")

  // Match and cascade
  let result = cascade_element(element, [stylesheet], [])
  inspect(result.get_value("width"), content="Some(\"100px\")")
}

///|
test "stylesheet - non-matching element" {
  let stylesheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div.bar")
  match sel {
    Some(selector) =>
      stylesheet.add_rule("div.bar", selector, [
        Declaration::new("width", "100px"),
      ])
    None => fail("failed to parse selector")
  }

  // Create an element that doesn't match
  let element = @selector.Element::new("div").add_class("foo")
  let result = cascade_element(element, [stylesheet], [])
  inspect(result.has("width"), content="false")
}

///|
test "multiple stylesheets" {
  let ua_stylesheet = Stylesheet::new(UserAgent)
  let author_stylesheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div")
  match sel {
    Some(selector) => {
      // UA sets width: 0
      ua_stylesheet.add_rule("div", selector, [Declaration::new("width", "0")])
      // Author sets width: 100px
      author_stylesheet.add_rule("div", selector, [
        Declaration::new("width", "100px"),
      ])
    }
    None => fail("failed to parse selector")
  }
  let element = @selector.Element::new("div")
  let result = cascade_element(element, [ua_stylesheet, author_stylesheet], [])

  // Author beats UA
  inspect(result.get_value("width"), content="Some(\"100px\")")
}

///|
test "parse type selector" {
  let sel = parse_selector_text("div")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  inspect(s.head.type_selector.is_some(), content="true")
  match s.head.type_selector {
    Some(Type(name)) => inspect(name, content="div")
    _ => fail("expected type selector")
  }
}

///|
test "parse class selector" {
  let sel = parse_selector_text(".foo")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  inspect(s.head.subclasses.length(), content="1")
  match s.head.subclasses[0] {
    Class(name) => inspect(name, content="foo")
    _ => fail("expected class selector")
  }
}

///|
test "parse id selector" {
  let sel = parse_selector_text("#bar")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  inspect(s.head.subclasses.length(), content="1")
  match s.head.subclasses[0] {
    Id(name) => inspect(name, content="bar")
    _ => fail("expected id selector")
  }
}

///|
test "parse universal selector" {
  let sel = parse_selector_text("*")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.type_selector {
    Some(Universal) => ()
    _ => fail("expected universal selector")
  }
}

///|
test "parse compound selector" {
  let sel = parse_selector_text("div.foo#bar")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  // Type selector
  match s.head.type_selector {
    Some(Type(name)) => inspect(name, content="div")
    _ => fail("expected type selector")
  }
  // Subclasses: class and id
  inspect(s.head.subclasses.length(), content="2")
  match s.head.subclasses[0] {
    Class(name) => inspect(name, content="foo")
    _ => fail("expected class selector")
  }
  match s.head.subclasses[1] {
    Id(name) => inspect(name, content="bar")
    _ => fail("expected id selector")
  }
}

///|
test "parse descendant combinator" {
  let sel = parse_selector_text("div p")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  // head should be 'p'
  match s.head.type_selector {
    Some(Type(name)) => inspect(name, content="p")
    _ => fail("expected type selector p")
  }
  // tail should have one step with 'div' and Descendant combinator
  inspect(s.tail.length(), content="1")
  match s.tail[0].combinator {
    Descendant => ()
    _ => fail("expected descendant combinator")
  }
  match s.tail[0].selector.type_selector {
    Some(Type(name)) => inspect(name, content="div")
    _ => fail("expected type selector div")
  }
}

///|
test "parse child combinator" {
  let sel = parse_selector_text("div > p")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.tail[0].combinator {
    Child => ()
    _ => fail("expected child combinator")
  }
}

///|
test "parse adjacent sibling combinator" {
  let sel = parse_selector_text("div + p")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.tail[0].combinator {
    NextSibling => ()
    _ => fail("expected next-sibling combinator")
  }
}

///|
test "parse general sibling combinator" {
  let sel = parse_selector_text("div ~ p")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.tail[0].combinator {
    SubsequentSibling => ()
    _ => fail("expected subsequent-sibling combinator")
  }
}

///|
test "parse attribute exists selector" {
  let sel = parse_selector_text("[disabled]")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.subclasses[0] {
    Attribute(attr) => {
      inspect(attr.name, content="disabled")
      match attr.match_type {
        Exists => ()
        _ => fail("expected Exists match type")
      }
    }
    _ => fail("expected attribute selector")
  }
}

///|
test "parse attribute exact match" {
  let sel = parse_selector_text("[type=button]")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.subclasses[0] {
    Attribute(attr) => {
      inspect(attr.name, content="type")
      match attr.match_type {
        Exact(v) => inspect(v, content="button")
        _ => fail("expected Exact match type")
      }
    }
    _ => fail("expected attribute selector")
  }
}

///|
test "parse pseudo-class first-child" {
  let sel = parse_selector_text(":first-child")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.subclasses[0] {
    PseudoClass(FirstChild) => ()
    _ => fail("expected :first-child pseudo-class")
  }
}

///|
test "parse pseudo-class nth-child" {
  let sel = parse_selector_text(":nth-child(2n+1)")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.subclasses[0] {
    PseudoClass(NthChild(expr)) => {
      inspect(expr.a, content="2")
      inspect(expr.b, content="1")
    }
    _ => fail("expected :nth-child pseudo-class")
  }
}

///|
test "parse pseudo-class nth-child odd" {
  let sel = parse_selector_text(":nth-child(odd)")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.subclasses[0] {
    PseudoClass(NthChild(expr)) => {
      inspect(expr.a, content="2")
      inspect(expr.b, content="1")
    }
    _ => fail("expected :nth-child pseudo-class")
  }
}

///|
test "parse pseudo-element before" {
  let sel = parse_selector_text("::before")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  match s.head.subclasses[0] {
    PseudoElement(Before) => ()
    _ => fail("expected ::before pseudo-element")
  }
}

///|
test "parse selector list" {
  let list = parse_selector_list_text("div, .foo, #bar")
  inspect(list.is_some(), content="true")
  let l = list.unwrap()
  inspect(l.selectors.length(), content="3")
}

///|
test "parse complex selector chain" {
  let sel = parse_selector_text("nav > ul li a:hover")
  inspect(sel.is_some(), content="true")
  let s = sel.unwrap()
  // head should be 'a:hover'
  match s.head.type_selector {
    Some(Type(name)) => inspect(name, content="a")
    _ => fail("expected type selector a")
  }
  // Should have :hover pseudo-class
  inspect(s.head.subclasses.length(), content="1")
  match s.head.subclasses[0] {
    PseudoClass(Hover) => ()
    _ => fail("expected :hover pseudo-class")
  }
  // tail should have 3 steps: nav > ul, ul li (implicit descendant)
  inspect(s.tail.length(), content="3")
}

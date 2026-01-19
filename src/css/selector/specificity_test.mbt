///|
test "specificity - type selector" {
  let sel = parse_selector_text("div")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="0")
      inspect(spec.c, content="1")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - class selector" {
  let sel = parse_selector_text(".foo")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="1")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - id selector" {
  let sel = parse_selector_text("#bar")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="1")
      inspect(spec.b, content="0")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - compound selector" {
  // div.foo#bar = (1, 1, 1)
  let sel = parse_selector_text("div.foo#bar")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="1")
      inspect(spec.b, content="1")
      inspect(spec.c, content="1")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - complex selector" {
  // nav ul li a = (0, 0, 4)
  let sel = parse_selector_text("nav ul li a")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="0")
      inspect(spec.c, content="4")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - mixed selector" {
  // #main .content p = (1, 1, 1)
  let sel = parse_selector_text("#main .content p")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="1")
      inspect(spec.b, content="1")
      inspect(spec.c, content="1")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - universal selector" {
  // * = (0, 0, 0)
  let sel = parse_selector_text("*")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="0")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - attribute selector" {
  // [type=button] = (0, 1, 0)
  let sel = parse_selector_text("[type=button]")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="1")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - pseudo-class" {
  // :first-child = (0, 1, 0)
  let sel = parse_selector_text(":first-child")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="1")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - pseudo-element" {
  // ::before = (0, 0, 1)
  let sel = parse_selector_text("::before")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="0")
      inspect(spec.c, content="1")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity comparison" {
  let spec1 : Specificity = { a: 1, b: 0, c: 0 }
  let spec2 : Specificity = { a: 0, b: 10, c: 10 }
  // ID selector beats any number of classes/types
  assert_true(spec1.compare_to(spec2) > 0)
}

///|
test "specificity addition" {
  let spec1 : Specificity = { a: 1, b: 2, c: 3 }
  let spec2 : Specificity = { a: 0, b: 1, c: 1 }
  let sum = spec1.add(spec2)
  inspect(sum.a, content="1")
  inspect(sum.b, content="3")
  inspect(sum.c, content="4")
}

///|
test "specificity - :where() has zero specificity" {
  // :where(.foo) = (0, 0, 0)
  let sel = parse_selector_text(":where(.foo)")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="0")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - :where() with multiple classes" {
  // :where(.foo.bar.baz) = (0, 0, 0) - still zero
  let sel = parse_selector_text(":where(.foo.bar.baz)")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="0")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - :not() takes argument specificity" {
  // :not(.foo) = (0, 1, 0) - takes the class specificity
  let sel = parse_selector_text(":not(.foo)")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="1")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - :not() with ID" {
  // :not(#main) = (1, 0, 0)
  let sel = parse_selector_text(":not(#main)")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="1")
      inspect(spec.b, content="0")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - combined :not() with element" {
  // div:not(.hidden) = (0, 1, 1) - type + :not's class
  let sel = parse_selector_text("div:not(.hidden)")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="1")
      inspect(spec.c, content="1")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - :is() takes highest argument" {
  // :is(.foo, #bar) = (1, 0, 0) - takes the highest (ID)
  let sel = parse_selector_text(":is(.foo, #bar)")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="1")
      inspect(spec.b, content="0")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - chained pseudo-classes" {
  // :first-child:last-child = (0, 2, 0)
  let sel = parse_selector_text(":first-child:last-child")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="0")
      inspect(spec.b, content="2")
      inspect(spec.c, content="0")
    }
    None => fail("failed to parse")
  }
}

///|
test "specificity - complex real-world selector" {
  // #header .nav-item:first-child a:hover = (1, 3, 1)
  // #header = 1,0,0
  // .nav-item = 0,1,0
  // :first-child = 0,1,0
  // a = 0,0,1
  // :hover = 0,1,0
  // Total: 1,3,1
  let sel = parse_selector_text("#header .nav-item:first-child a:hover")
  match sel {
    Some(s) => {
      let spec = complex_specificity(s)
      inspect(spec.a, content="1")
      inspect(spec.b, content="3")
      inspect(spec.c, content="1")
    }
    None => fail("failed to parse")
  }
}

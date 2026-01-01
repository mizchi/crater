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

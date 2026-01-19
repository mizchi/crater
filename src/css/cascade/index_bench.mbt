// =============================================================================
// Selector Index Benchmarks
// =============================================================================
// Compare indexed vs non-indexed selector matching

///|
fn create_test_stylesheet(num_rules : Int) -> Stylesheet {
  let stylesheet = Stylesheet::new(Author)
  // Create various selector patterns using helper functions
  for i = 0; i < num_rules; i = i + 1 {
    let idx = i % 6
    let selector = match idx {
      0 => {
        // ID selector: #item-N
        let compound = @selector.CompoundSelector::from_id(
          "item-" + i.to_string(),
        )
        @selector.ComplexSelector::simple(compound)
      }
      1 | 2 => {
        // Class selector: .class-N
        let compound = @selector.CompoundSelector::from_class(
          "class-" + (i % 50).to_string(),
        )
        @selector.ComplexSelector::simple(compound)
      }
      3 | 4 => {
        // Tag selector: div
        let compound = @selector.CompoundSelector::from_type("div")
        @selector.ComplexSelector::simple(compound)
      }
      _ => {
        // Universal: *
        let compound = @selector.CompoundSelector::universal()
        @selector.ComplexSelector::simple(compound)
      }
    }
    let decls : Array[Declaration] = [
      {
        property: "color",
        value: Value("red"),
        origin: Author,
        importance: Normal,
        specificity: { a: 0, b: 0, c: 0 },
        source_order: 0,
      },
    ]
    stylesheet.add_rule(selector.to_string(), selector, decls)
  }
  stylesheet
}

///|
fn create_test_element(
  id : String,
  classes : Array[String],
) -> @selector.Element {
  let mut elem = @selector.Element::new("div")
  elem = elem.set_id(id)
  for cls in classes {
    elem = elem.add_class(cls)
  }
  elem
}

///|
test "bench_selector_match_non_indexed_100" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(100)
  let elem = create_test_element("item-5", ["class-10", "container"])
  b.bench(name="match_non_idx_100", fn() {
    b.keep(stylesheet.match_element(elem))
  })
}

///|
test "bench_selector_match_indexed_100" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(100)
  let indexed = IndexedStylesheet::new(stylesheet)
  let elem = create_test_element("item-5", ["class-10", "container"])
  b.bench(name="match_indexed_100", fn() { b.keep(indexed.match_element(elem)) })
}

///|
test "bench_selector_match_non_indexed_500" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(500)
  let elem = create_test_element("item-25", ["class-20", "container"])
  b.bench(name="match_non_idx_500", fn() {
    b.keep(stylesheet.match_element(elem))
  })
}

///|
test "bench_selector_match_indexed_500" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(500)
  let indexed = IndexedStylesheet::new(stylesheet)
  let elem = create_test_element("item-25", ["class-20", "container"])
  b.bench(name="match_indexed_500", fn() { b.keep(indexed.match_element(elem)) })
}

///|
test "bench_selector_match_non_indexed_1000" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(1000)
  let elem = create_test_element("item-100", ["class-30", "container", "active"])
  b.bench(name="match_non_idx_1k", fn() {
    b.keep(stylesheet.match_element(elem))
  })
}

///|
test "bench_selector_match_indexed_1000" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(1000)
  let indexed = IndexedStylesheet::new(stylesheet)
  let elem = create_test_element("item-100", ["class-30", "container", "active"])
  b.bench(name="match_indexed_1k", fn() { b.keep(indexed.match_element(elem)) })
}

///|
test "bench_cascade_multiple_elements_non_indexed" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(200)
  let stylesheets = [stylesheet]
  let elements : Array[@selector.Element] = []
  for i = 0; i < 100; i = i + 1 {
    elements.push(
      create_test_element("item-" + i.to_string(), [
        "class-" + (i % 50).to_string(),
      ]),
    )
  }
  b.bench(name="cascade_non_idx", fn() {
    for elem in elements {
      b.keep(cascade_element(elem, stylesheets, []))
    }
  })
}

///|
test "bench_cascade_multiple_elements_indexed" (b : @bench.T) {
  let stylesheet = create_test_stylesheet(200)
  let indexed = IndexedStylesheet::new(stylesheet)
  let stylesheets = [indexed]
  let elements : Array[@selector.Element] = []
  for i = 0; i < 100; i = i + 1 {
    elements.push(
      create_test_element("item-" + i.to_string(), [
        "class-" + (i % 50).to_string(),
      ]),
    )
  }
  b.bench(name="cascade_indexed", fn() {
    for elem in elements {
      b.keep(cascade_element_indexed(elem, stylesheets, [], None))
    }
  })
}

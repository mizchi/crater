///|
test "css compatibility package parses and computes styles" {
  let result = parse_stylesheet_with_diagnostics(
    ".card { display: flex; mystery-prop: 1; }",
  )
  let summary = result.diagnostics.get_summary()
  inspect(summary.supported, content="1")
  inspect(summary.unknown, content="1")

  let element = Element::with_classes("div", ["card"])
  let stylesheet = parse_stylesheet(".card { display: flex; padding: 8px; }")
  let cascaded = cascade_element(element, [stylesheet], [])
  let computed = compute_style(cascaded, ComputeContext::new())
  inspect(computed.display.to_string(), content="Flex")
}

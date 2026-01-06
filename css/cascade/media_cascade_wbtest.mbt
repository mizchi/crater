///|
test "hamburger_width_cascade_with_media_query" {
  let css =
    #|._hamburger { display: none; position: absolute; width: 20px; height: 20px; }
    #|@media (max-width: 50rem) { ._hamburger { display: block; position: relative; } }

  // Parse stylesheet
  let result = @parser.parse_stylesheet_with_diagnostics(css)
  let stylesheet = result.stylesheet

  // Create a mock element matching ._hamburger
  let element = @selector.Element::with_classes("div", ["_hamburger"])

  // Mobile environment (375px viewport)
  let env = @media.MediaEnvironment::new(375.0, 600.0)

  // Cascade with media query
  let cascaded = cascade_element_with_media(
    element,
    [stylesheet],
    [],
    Some(env),
  )

  // Check that width is still from base rule
  inspect(cascaded.get_value("width"), content="Some(\"20px\")")
  inspect(cascaded.get_value("display"), content="Some(\"block\")")
  inspect(cascaded.get_value("position"), content="Some(\"relative\")")
}

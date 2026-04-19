///|
test "prefers_color_scheme_dark_cascade" {
  let css =
    #|body { color: #333; background: white; }
    #|@media (prefers-color-scheme: dark) { body { color: #fff; background: #1a1a1a; } }

  // Parse stylesheet
  let result = @parser.parse_stylesheet_with_diagnostics(css)
  let stylesheet = result.stylesheet

  // Create a mock body element
  let element = @selector.Element::new("body")

  // Light mode environment
  let light_env = @media.MediaEnvironment::with_color_scheme(
    375.0,
    600.0,
    @media.ColorScheme::Light,
  )
  let cascaded_light = cascade_element_with_media(
    element,
    [stylesheet],
    [],
    Some(light_env),
  )
  inspect(cascaded_light.get_value("color"), content="Some(\"#333\")")
  inspect(cascaded_light.get_value("background"), content="Some(\"white\")")

  // Dark mode environment
  let dark_env = @media.MediaEnvironment::with_color_scheme(
    375.0,
    600.0,
    @media.ColorScheme::Dark,
  )
  let cascaded_dark = cascade_element_with_media(
    element,
    [stylesheet],
    [],
    Some(dark_env),
  )
  // In dark mode, media query should match and override
  inspect(cascaded_dark.get_value("color"), content="Some(\"#fff\")")
  inspect(cascaded_dark.get_value("background"), content="Some(\"#1a1a1a\")")
}

///|
test "prefers_color_scheme_with_css_variables" {
  // Typical dark mode pattern with CSS variables
  let css =
    #|:root { --text-color: #333; --bg-color: white; }
    #|@media (prefers-color-scheme: dark) { :root { --text-color: #fff; --bg-color: #1a1a1a; } }
    #|body { color: var(--text-color); background: var(--bg-color); }

  // Parse stylesheet
  let result = @parser.parse_stylesheet_with_diagnostics(css)
  let stylesheet = result.stylesheet

  // Create :root element
  let root_element = @selector.Element::new("html")

  // Dark mode environment
  let dark_env = @media.MediaEnvironment::with_color_scheme(
    375.0,
    600.0,
    @media.ColorScheme::Dark,
  )
  let cascaded_root = cascade_element_with_media(
    root_element,
    [stylesheet],
    [],
    Some(dark_env),
  )
  // In dark mode, CSS variables should be dark values
  inspect(cascaded_root.get_value("--text-color"), content="Some(\"#fff\")")
  inspect(cascaded_root.get_value("--bg-color"), content="Some(\"#1a1a1a\")")
}

///|
test "prefers_color_scheme_dark_text_color" {
  // Test that text color changes in dark mode via CSS variables
  let css =
    #|:root { --text-color: #333; }
    #|@media (prefers-color-scheme: dark) { :root { --text-color: #eee; } }
    #|p { color: var(--text-color); }

  // Parse stylesheet
  let result = @parser.parse_stylesheet_with_diagnostics(css)
  let stylesheet = result.stylesheet

  // Create :root and p elements
  let root_element = @selector.Element::new("html")
  let p_element = @selector.Element::new("p")

  // Light mode environment
  let light_env = @media.MediaEnvironment::with_color_scheme(
    375.0,
    600.0,
    @media.ColorScheme::Light,
  )
  let cascaded_root_light = cascade_element_with_media(
    root_element,
    [stylesheet],
    [],
    Some(light_env),
  )
  inspect(
    cascaded_root_light.get_value("--text-color"),
    content="Some(\"#333\")",
  )

  // Dark mode environment
  let dark_env = @media.MediaEnvironment::with_color_scheme(
    375.0,
    600.0,
    @media.ColorScheme::Dark,
  )
  let cascaded_root_dark = cascade_element_with_media(
    root_element,
    [stylesheet],
    [],
    Some(dark_env),
  )
  // In dark mode, CSS variable should have dark value
  inspect(
    cascaded_root_dark.get_value("--text-color"),
    content="Some(\"#eee\")",
  )

  // Cascade p element (will get var(--text-color) which needs resolution)
  let cascaded_p = cascade_element_with_media(
    p_element,
    [stylesheet],
    [],
    Some(dark_env),
  )
  // p element gets color: var(--text-color) - resolution happens later
  inspect(cascaded_p.get_value("color"), content="Some(\"var(--text-color)\")")
}

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

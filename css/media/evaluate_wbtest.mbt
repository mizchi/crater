///|
test "media_query_max_width_evaluation" {
  // Test max-width: 50rem (800px)
  // At 375px viewport, should match
  let env_mobile = MediaEnvironment::new(375.0, 600.0)
  // At 1024px viewport, should not match
  let env_desktop = MediaEnvironment::new(1024.0, 768.0)

  // Create max-width: 800px query
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: Some(MediaType::Screen),
    conditions: [MediaFeature::MaxWidth(MediaValue::Dimension(800.0, "px"))],
  }

  // Mobile should match max-width: 800px
  inspect(mq.evaluate(env_mobile), content="true")
  // Desktop should not match max-width: 800px
  inspect(mq.evaluate(env_desktop), content="false")
}

///|
test "media_query_min_width_evaluation" {
  let env_mobile = MediaEnvironment::new(375.0, 600.0)
  let env_desktop = MediaEnvironment::new(1024.0, 768.0)

  // Create min-width: 768px query
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MinWidth(MediaValue::Dimension(768.0, "px"))],
  }

  // Mobile should NOT match min-width: 768px
  inspect(mq.evaluate(env_mobile), content="false")
  // Desktop should match min-width: 768px
  inspect(mq.evaluate(env_desktop), content="true")
}

///|
test "media_query_prefers_color_scheme_light" {
  // Test prefers-color-scheme: light
  let env_light = MediaEnvironment::with_color_scheme(375.0, 600.0, Light)
  let env_dark = MediaEnvironment::with_color_scheme(375.0, 600.0, Dark)
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::PrefersColorScheme("light")],
  }

  // Light mode should match prefers-color-scheme: light
  inspect(mq.evaluate(env_light), content="true")
  // Dark mode should NOT match prefers-color-scheme: light
  inspect(mq.evaluate(env_dark), content="false")
}

///|
test "media_query_prefers_color_scheme_dark" {
  // Test prefers-color-scheme: dark
  let env_light = MediaEnvironment::with_color_scheme(375.0, 600.0, Light)
  let env_dark = MediaEnvironment::with_color_scheme(375.0, 600.0, Dark)
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::PrefersColorScheme("dark")],
  }

  // Light mode should NOT match prefers-color-scheme: dark
  inspect(mq.evaluate(env_light), content="false")
  // Dark mode should match prefers-color-scheme: dark
  inspect(mq.evaluate(env_dark), content="true")
}

///|
test "media_query_parse_and_evaluate_prefers_color_scheme" {
  // End-to-end test: parse media query string and evaluate
  let env_light = MediaEnvironment::with_color_scheme(375.0, 600.0, Light)
  let env_dark = MediaEnvironment::with_color_scheme(375.0, 600.0, Dark)
  let mq_dark = parse_media_query_list("(prefers-color-scheme: dark)")
  let mq_light = parse_media_query_list("(prefers-color-scheme: light)")

  // Dark mode query
  inspect(mq_dark.evaluate(env_light), content="false")
  inspect(mq_dark.evaluate(env_dark), content="true")

  // Light mode query
  inspect(mq_light.evaluate(env_light), content="true")
  inspect(mq_light.evaluate(env_dark), content="false")
}

///|
test "media_query_list_or_semantics" {
  let env = MediaEnvironment::new(375.0, 600.0)

  // Query list with OR semantics: screen, (min-width: 1000px)
  let mq_list : MediaQueryList = {
    queries: [
      {
        negated: false,
        only: false,
        media_type: Some(MediaType::Screen),
        conditions: [],
      },
      {
        negated: false,
        only: false,
        media_type: None,
        conditions: [
          MediaFeature::MinWidth(MediaValue::Dimension(1000.0, "px")),
        ],
      },
    ],
  }

  // First query (screen) matches, so whole list matches
  inspect(mq_list.evaluate(env), content="true")
}

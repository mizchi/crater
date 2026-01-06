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

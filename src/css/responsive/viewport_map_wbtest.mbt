///|
test "discover_css_rule_viewport_map with max-width rule" {
  let html = "<style>@media (max-width: 640px) { .stats { grid-template-columns: 1fr; } }</style>"
  let result = discover_css_rule_viewport_map(html, [375, 640, 768, 1024, 1280])
  assert_eq(result.rules.length(), 1)
  let rule = result.rules[0]
  assert_eq(rule.selector, ".stats")
  assert_eq(rule.properties, ["grid-template-columns"])
  assert_eq(rule.active_at_widths, [375, 640])
  assert_eq(rule.inactive_at_widths, [768, 1024, 1280])
}

///|
test "discover_css_rule_viewport_map with min-width rule" {
  let html = "<style>@media (min-width: 768px) { .sidebar { display: block; } }</style>"
  let result = discover_css_rule_viewport_map(html, [375, 640, 768, 1024])
  assert_eq(result.rules.length(), 1)
  let rule = result.rules[0]
  assert_eq(rule.selector, ".sidebar")
  assert_eq(rule.active_at_widths, [768, 1024])
  assert_eq(rule.inactive_at_widths, [375, 640])
}

///|
test "discover_css_rule_viewport_map merges properties for same selector+media" {
  let html = "<style>@media (max-width: 640px) { .card { display: block; padding: 8px; } }</style>"
  let result = discover_css_rule_viewport_map(html, [375, 768])
  assert_eq(result.rules.length(), 1)
  let rule = result.rules[0]
  assert_eq(rule.properties.length(), 2)
  assert_true(rule.properties.contains("display"))
  assert_true(rule.properties.contains("padding"))
}

///|
test "discover_css_rule_viewport_map ignores non-media rules" {
  let html = "<style>.card { display: block; } @media (max-width: 640px) { .card { display: none; } }</style>"
  let result = discover_css_rule_viewport_map(html, [375, 768])
  assert_eq(result.rules.length(), 1)
  assert_eq(result.rules[0].selector, ".card")
  assert_eq(result.rules[0].properties, ["display"])
}

///|
test "discover_css_rule_viewport_map with multiple media rules" {
  let html = "<style>@media (max-width: 640px) { .a { display: none; } } @media (min-width: 1024px) { .b { width: 100%; } }</style>"
  let result = discover_css_rule_viewport_map(html, [375, 640, 768, 1024, 1280])
  assert_eq(result.rules.length(), 2)
}

///|
test "discover_required_test_viewports from max-width" {
  let html = "<style>@media (max-width: 640px) { .stats { display: none; } }</style>"
  let result = discover_required_test_viewports(html)
  assert_true(result.viewports.length() >= 1)
  // Should include 640 and 641
  let widths : Array[Int] = []
  for v in result.viewports {
    widths.push(v.width)
  }
  assert_true(widths.contains(640))
  assert_true(widths.contains(641))
}

///|
test "discover_required_test_viewports from min-width" {
  let html = "<style>@media (min-width: 768px) { .sidebar { display: block; } }</style>"
  let result = discover_required_test_viewports(html)
  let widths : Array[Int] = []
  for v in result.viewports {
    widths.push(v.width)
  }
  assert_true(widths.contains(768))
  assert_true(widths.contains(767))
}

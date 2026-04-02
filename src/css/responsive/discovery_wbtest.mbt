///|
test "discover responsive breakpoints from min-width rules" {
  let html = "<style>@media (min-width: 768px) { .card { display: block; } }</style>"
  let result = discover_responsive_breakpoints(html)
  let breakpoint = result.breakpoints[0]
  assert_eq(result.breakpoints.length(), 1)
  assert_eq(breakpoint.axis, "width")
  assert_eq(breakpoint.op, "ge")
  assert_eq(breakpoint.value_px, 768)
  assert_eq(breakpoint.rule_count, 1)
  assert_eq(result.diagnostics.stylesheet_count, 1)
  assert_eq(result.diagnostics.rule_count, 1)
}

///|
test "discover responsive breakpoints normalizes em units" {
  let html = "<style>@media (max-width: 48em) { .card { display: block; } }</style>"
  let result = discover_responsive_breakpoints(html)
  let breakpoint = result.breakpoints[0]
  assert_eq(result.breakpoints.length(), 1)
  assert_eq(breakpoint.op, "le")
  assert_eq(breakpoint.value_px, 768)
}

///|
test "discover responsive breakpoints supports width range syntax" {
  let html = "<style>@media (width > 600px) { .card { display: block; } }</style>"
  let result = discover_responsive_breakpoints(html)
  let breakpoint = result.breakpoints[0]
  assert_eq(result.breakpoints.length(), 1)
  assert_eq(breakpoint.op, "gt")
  assert_eq(breakpoint.value_px, 600)
}

///|
test "discover responsive breakpoints preserves non-width guards" {
  let html = "<style>@media (min-width: 768px) and (orientation: landscape) { .card { display: block; } }</style>"
  let result = discover_responsive_breakpoints(html)
  let breakpoint = result.breakpoints[0]
  assert_eq(result.breakpoints.length(), 1)
  assert_eq(breakpoint.guards.length(), 1)
  assert_eq(breakpoint.guards[0], "orientation:landscape")
  assert_true(breakpoint.normalized.contains("(orientation:landscape)"))
}

///|
test "discover responsive breakpoints ignores print queries" {
  let html = "<style>@media print and (min-width: 768px) { .card { display: block; } }</style>"
  let result = discover_responsive_breakpoints(html)
  assert_eq(result.breakpoints.length(), 0)
  assert_eq(result.diagnostics.ignored_queries.length(), 1)
  assert_true(result.diagnostics.ignored_queries[0].contains("print"))
}

///|
test "discover responsive breakpoints merges duplicate rules" {
  let html = "<style>@media (min-width: 768px) { .card { display: block; } }</style><style>@media (min-width: 768px) { .layout { display: grid; } }</style>"
  let result = discover_responsive_breakpoints(html)
  let breakpoint = result.breakpoints[0]
  assert_eq(result.breakpoints.length(), 1)
  assert_eq(breakpoint.rule_count, 2)
  assert_eq(result.diagnostics.stylesheet_count, 2)
  assert_eq(result.diagnostics.rule_count, 2)
}

///|
test "discover responsive breakpoints reports external stylesheet links" {
  let html = "<link rel='stylesheet' href='/base.css'><style>@media (min-width: 768px) { .card { display: block; } }</style>"
  let result = discover_responsive_breakpoints(html)
  assert_eq(result.diagnostics.external_stylesheet_links.length(), 1)
  assert_eq(result.diagnostics.external_stylesheet_links[0], "/base.css")
}

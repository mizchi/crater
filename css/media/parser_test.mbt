///|
test "parse simple media type - screen" {
  let mq = parse_media_query_list("screen")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.negated, content="false")
  inspect(q.only, content="false")
  inspect(q.media_type, content="Some(Screen)")
  inspect(q.conditions.length(), content="0")
}

///|
test "parse simple media type - print" {
  let mq = parse_media_query_list("print")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.media_type, content="Some(Print)")
}

///|
test "parse simple media type - all" {
  let mq = parse_media_query_list("all")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.media_type, content="Some(All)")
}

///|
test "parse not modifier" {
  let mq = parse_media_query_list("not screen")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.negated, content="true")
  inspect(q.media_type, content="Some(Screen)")
}

///|
test "parse only modifier" {
  let mq = parse_media_query_list("only screen")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.only, content="true")
  inspect(q.media_type, content="Some(Screen)")
}

///|
test "parse min-width feature" {
  let mq = parse_media_query_list("(min-width: 768px)")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.conditions.length(), content="1")
  inspect(q.conditions[0], content="MinWidth(Dimension(768, \"px\"))")
}

///|
test "parse max-width feature" {
  let mq = parse_media_query_list("(max-width: 1024px)")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.conditions.length(), content="1")
  inspect(q.conditions[0], content="MaxWidth(Dimension(1024, \"px\"))")
}

///|
test "parse screen and min-width" {
  let mq = parse_media_query_list("screen and (min-width: 768px)")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.media_type, content="Some(Screen)")
  inspect(q.conditions.length(), content="1")
  inspect(q.conditions[0], content="MinWidth(Dimension(768, \"px\"))")
}

///|
test "parse multiple conditions" {
  let mq = parse_media_query_list(
    "screen and (min-width: 768px) and (max-width: 1024px)",
  )
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.media_type, content="Some(Screen)")
  inspect(q.conditions.length(), content="2")
  inspect(q.conditions[0], content="MinWidth(Dimension(768, \"px\"))")
  inspect(q.conditions[1], content="MaxWidth(Dimension(1024, \"px\"))")
}

///|
test "parse comma-separated queries" {
  let mq = parse_media_query_list("screen, print")
  inspect(mq.queries.length(), content="2")
  inspect(mq.queries[0].media_type, content="Some(Screen)")
  inspect(mq.queries[1].media_type, content="Some(Print)")
}

///|
test "parse complex comma-separated queries" {
  let mq = parse_media_query_list(
    "screen and (min-width: 768px), print and (color)",
  )
  inspect(mq.queries.length(), content="2")
  let q0 = mq.queries[0]
  inspect(q0.media_type, content="Some(Screen)")
  inspect(q0.conditions.length(), content="1")
  let q1 = mq.queries[1]
  inspect(q1.media_type, content="Some(Print)")
  inspect(q1.conditions.length(), content="1")
}

///|
test "parse boolean feature - color" {
  let mq = parse_media_query_list("(color)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="Color")
}

///|
test "parse boolean feature - hover" {
  let mq = parse_media_query_list("(hover)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="Hover")
}

///|
test "parse orientation feature" {
  let mq = parse_media_query_list("(orientation: landscape)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="Orientation(\"landscape\")")
}

///|
test "parse orientation portrait" {
  let mq = parse_media_query_list("(orientation: portrait)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="Orientation(\"portrait\")")
}

///|
test "parse prefers-color-scheme dark" {
  let mq = parse_media_query_list("(prefers-color-scheme: dark)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="PrefersColorScheme(\"dark\")")
}

///|
test "parse prefers-color-scheme light" {
  let mq = parse_media_query_list("(prefers-color-scheme: light)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="PrefersColorScheme(\"light\")")
}

///|
test "parse prefers-reduced-motion" {
  let mq = parse_media_query_list("(prefers-reduced-motion: reduce)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="PrefersReducedMotion(\"reduce\")",
  )
}

///|
test "parse aspect-ratio" {
  let mq = parse_media_query_list("(aspect-ratio: 16/9)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="AspectRatio(Some(Ratio(16, 9)))",
  )
}

///|
test "parse min-aspect-ratio" {
  let mq = parse_media_query_list("(min-aspect-ratio: 4/3)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="MinAspectRatio(Ratio(4, 3))")
}

///|
test "parse resolution" {
  let mq = parse_media_query_list("(min-resolution: 2dppx)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="MinResolution(Dimension(2, \"dppx\"))",
  )
}

///|
test "parse height feature" {
  let mq = parse_media_query_list("(min-height: 600px)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="MinHeight(Dimension(600, \"px\"))",
  )
}

///|
test "parse range syntax - width greater than" {
  let mq = parse_media_query_list("(width >= 768px)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="WidthRange(Ge, Dimension(768, \"px\"))",
  )
}

///|
test "parse range syntax - width less than" {
  let mq = parse_media_query_list("(width < 1024px)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="WidthRange(Lt, Dimension(1024, \"px\"))",
  )
}

///|
test "parse range syntax - height" {
  let mq = parse_media_query_list("(height <= 800px)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="HeightRange(Le, Dimension(800, \"px\"))",
  )
}

///|
test "parse display-mode" {
  let mq = parse_media_query_list("(display-mode: fullscreen)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="DisplayMode(\"fullscreen\")")
}

///|
test "parse empty query list" {
  let mq = parse_media_query_list("")
  inspect(mq.queries.length(), content="0")
}

///|
test "parse whitespace-only query" {
  let mq = parse_media_query_list("   ")
  inspect(mq.queries.length(), content="0")
}

///|
test "parse custom feature" {
  let mq = parse_media_query_list("(unknown-feature: value)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="Custom(\"unknown-feature\", Some(Ident(\"value\")))",
  )
}

///|
test "parse only screen with features" {
  let mq = parse_media_query_list("only screen and (color)")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.only, content="true")
  inspect(q.media_type, content="Some(Screen)")
  inspect(q.conditions.length(), content="1")
}

///|
test "parse not print with features" {
  let mq = parse_media_query_list("not print and (monochrome)")
  inspect(mq.queries.length(), content="1")
  let q = mq.queries[0]
  inspect(q.negated, content="true")
  inspect(q.media_type, content="Some(Print)")
  inspect(q.conditions.length(), content="1")
  inspect(q.conditions[0], content="Monochrome")
}

///|
test "parse pointer feature" {
  let mq = parse_media_query_list("(pointer)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="Pointer")
}

///|
test "parse grid feature" {
  let mq = parse_media_query_list("(grid)")
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions[0], content="Grid")
}

///|
test "parse em units" {
  let mq = parse_media_query_list("(min-width: 48em)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="MinWidth(Dimension(48, \"em\"))",
  )
}

///|
test "parse rem units" {
  let mq = parse_media_query_list("(min-width: 30rem)")
  inspect(mq.queries.length(), content="1")
  inspect(
    mq.queries[0].conditions[0],
    content="MinWidth(Dimension(30, \"rem\"))",
  )
}

///|
test "MediaQueryList is_empty" {
  let mq = parse_media_query_list("")
  inspect(mq.is_empty(), content="true")
  let mq2 = parse_media_query_list("screen")
  inspect(mq2.is_empty(), content="false")
}

///|
test "MediaQueryList length" {
  let mq = parse_media_query_list("screen, print, all")
  inspect(mq.length(), content="3")
}

///|
test "MediaQuery default" {
  let q = MediaQuery::default()
  inspect(q.negated, content="false")
  inspect(q.only, content="false")
  inspect(q.media_type, content="None")
  inspect(q.conditions.length(), content="0")
}

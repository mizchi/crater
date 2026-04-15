///|
/// Responsive breakpoint discovery from inline stylesheets.

///|
pub struct ResponsiveBreakpoint {
  axis : String
  op : String
  value_px : Int
  raw : String
  normalized : String
  guards : Array[String]
  rule_count : Int
} derive(Eq, Debug)

///|
pub struct BreakpointDiscoveryDiagnostics {
  stylesheet_count : Int
  rule_count : Int
  external_stylesheet_links : Array[String]
  ignored_queries : Array[String]
  unsupported_queries : Array[String]
} derive(Eq, Debug)

///|
pub struct BreakpointDiscoveryResult {
  breakpoints : Array[ResponsiveBreakpoint]
  diagnostics : BreakpointDiscoveryDiagnostics
} derive(Eq, Debug)

///|
pub impl Show for ResponsiveBreakpoint with output(self, logger) {
  logger.write_string("{axis: ")
  logger.write_string(self.axis.to_string())
  logger.write_string(", op: ")
  logger.write_string(self.op.to_string())
  logger.write_string(", value_px: ")
  logger.write_string(self.value_px.to_string())
  logger.write_string(", raw: ")
  logger.write_string(self.raw.to_string())
  logger.write_string(", normalized: ")
  logger.write_string(self.normalized.to_string())
  logger.write_string(", guards: ")
  logger.write_string(self.guards.to_string())
  logger.write_string(", rule_count: ")
  logger.write_string(self.rule_count.to_string())
  logger.write_string("}")
}

///|
pub impl Show for BreakpointDiscoveryDiagnostics with output(self, logger) {
  logger.write_string("{stylesheet_count: ")
  logger.write_string(self.stylesheet_count.to_string())
  logger.write_string(", rule_count: ")
  logger.write_string(self.rule_count.to_string())
  logger.write_string(", external_stylesheet_links: ")
  logger.write_string(self.external_stylesheet_links.to_string())
  logger.write_string(", ignored_queries: ")
  logger.write_string(self.ignored_queries.to_string())
  logger.write_string(", unsupported_queries: ")
  logger.write_string(self.unsupported_queries.to_string())
  logger.write_string("}")
}

///|
pub impl Show for BreakpointDiscoveryResult with output(self, logger) {
  logger.write_string("{breakpoints: ")
  logger.write_string(self.breakpoints.to_string())
  logger.write_string(", diagnostics: ")
  logger.write_string(self.diagnostics.to_string())
  logger.write_string("}")
}

///|
priv struct BreakpointCandidate {
  op : String
  value_px : Int
}

///|
pub fn discover_responsive_breakpoints(
  html : String,
) -> BreakpointDiscoveryResult {
  let doc = @html.parse_document(html)
  let aggregated : Map[String, ResponsiveBreakpoint] = {}
  let ignored_queries : Array[String] = []
  let unsupported_queries : Array[String] = []
  let external_stylesheet_links : Array[String] = []
  let mut rule_count = 0

  for href in doc.stylesheet_links {
    external_stylesheet_links.push(href)
  }

  for css_text in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css_text)
    rule_count += stylesheet.rules.length()
    for rule in stylesheet.rules {
      match rule.media_query {
        Some(media_query) =>
          collect_media_query_list(
            media_query, aggregated, ignored_queries, unsupported_queries,
          )
        None => ()
      }
    }
  }

  let breakpoints : Array[ResponsiveBreakpoint] = []
  aggregated.each(fn(_key, breakpoint) { breakpoints.push(breakpoint) })
  breakpoints.sort_by(compare_breakpoints)

  {
    breakpoints,
    diagnostics: {
      stylesheet_count: doc.stylesheets.length(),
      rule_count,
      external_stylesheet_links,
      ignored_queries,
      unsupported_queries,
    },
  }
}

///|
fn collect_media_query_list(
  media_query : @media.MediaQueryList,
  aggregated : Map[String, ResponsiveBreakpoint],
  ignored_queries : Array[String],
  unsupported_queries : Array[String],
) -> Unit {
  for query in media_query.queries {
    collect_media_query(query, aggregated, ignored_queries, unsupported_queries)
  }
}

///|
fn collect_media_query(
  query : @media.MediaQuery,
  aggregated : Map[String, ResponsiveBreakpoint],
  ignored_queries : Array[String],
  unsupported_queries : Array[String],
) -> Unit {
  let raw_query = describe_query(query)
  if query.negated {
    push_unique(unsupported_queries, raw_query)
    return
  }

  match query.media_type {
    Some(@media.MediaType::Print) | Some(@media.MediaType::Speech) => {
      push_unique(ignored_queries, raw_query)
      return
    }
    Some(@media.MediaType::All) | Some(@media.MediaType::Screen) | None => ()
  }

  let guards : Array[String] = []
  let candidates : Array[BreakpointCandidate] = []
  let mut has_width = false
  let mut has_unsupported_feature = false

  for feature in query.conditions {
    match classify_feature(feature) {
      FeatureClassification::Breakpoint(candidate) => {
        has_width = true
        candidates.push(candidate)
      }
      FeatureClassification::Guard(guard_text) => guards.push(guard_text)
      FeatureClassification::Unsupported => has_unsupported_feature = true
    }
  }

  if !has_width {
    if query.conditions.is_empty() {
      push_unique(ignored_queries, raw_query)
    } else {
      push_unique(unsupported_queries, raw_query)
    }
    return
  }

  if has_unsupported_feature {
    push_unique(unsupported_queries, raw_query)
    return
  }

  let normalized_guards = normalize_guards(guards)
  for candidate in candidates {
    let key = breakpoint_key(candidate, normalized_guards)
    let normalized = describe_breakpoint(
      candidate.op,
      candidate.value_px,
      normalized_guards,
    )
    match aggregated.get(key) {
      Some(existing) =>
        aggregated.set(key, { ..existing, rule_count: existing.rule_count + 1 })
      None =>
        aggregated.set(key, {
          axis: "width",
          op: candidate.op,
          value_px: candidate.value_px,
          raw: raw_query,
          normalized,
          guards: normalized_guards,
          rule_count: 1,
        })
    }
  }
}

///|
priv enum FeatureClassification {
  Breakpoint(BreakpointCandidate)
  Guard(String)
  Unsupported
}

///|
fn classify_feature(feature : @media.MediaFeature) -> FeatureClassification {
  match feature {
    @media.MediaFeature::MinWidth(value) =>
      match media_value_to_px(value) {
        Some(value_px) =>
          FeatureClassification::Breakpoint({ op: "ge", value_px })
        None => FeatureClassification::Unsupported
      }
    @media.MediaFeature::MaxWidth(value) =>
      match media_value_to_px(value) {
        Some(value_px) =>
          FeatureClassification::Breakpoint({ op: "le", value_px })
        None => FeatureClassification::Unsupported
      }
    @media.MediaFeature::WidthRange(@media.RangeOp::Eq, _) =>
      FeatureClassification::Unsupported
    @media.MediaFeature::WidthRange(op, value) =>
      match media_value_to_px(value) {
        Some(value_px) =>
          FeatureClassification::Breakpoint({ op: range_op_label(op), value_px })
        None => FeatureClassification::Unsupported
      }
    @media.MediaFeature::Width(_) => FeatureClassification::Unsupported
    @media.MediaFeature::Custom(_, _) => FeatureClassification::Unsupported
    _ => FeatureClassification::Guard(describe_feature(feature))
  }
}

///|
fn media_value_to_px(value : @media.MediaValue) -> Int? {
  match value {
    @media.MediaValue::Dimension(number, unit) =>
      match unit.to_lower() {
        "px" => Some(number.to_int())
        "em" | "rem" => Some((number * 16.0).to_int())
        _ => None
      }
    _ => None
  }
}

///|
fn normalize_guards(guards : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = {}
  let normalized : Array[String] = []
  for guard_text in guards {
    if !seen.contains(guard_text) {
      seen.set(guard_text, true)
      normalized.push(guard_text)
    }
  }
  normalized.sort_by(fn(left, right) { left.compare(right) })
  normalized
}

///|
fn breakpoint_key(
  candidate : BreakpointCandidate,
  guards : Array[String],
) -> String {
  candidate.op + ":" + candidate.value_px.to_string() + ":" + guards.join("|")
}

///|
fn compare_breakpoints(
  left : ResponsiveBreakpoint,
  right : ResponsiveBreakpoint,
) -> Int {
  let value_compare = left.value_px.compare(right.value_px)
  if value_compare != 0 {
    return value_compare
  }
  let op_compare = op_rank(left.op).compare(op_rank(right.op))
  if op_compare != 0 {
    return op_compare
  }
  left.guards.join("|").compare(right.guards.join("|"))
}

///|
fn op_rank(op : String) -> Int {
  match op {
    "lt" => 0
    "le" => 1
    "ge" => 2
    "gt" => 3
    "eq" => 4
    _ => 5
  }
}

///|
fn op_symbol(op : String) -> String {
  match op {
    "lt" => "<"
    "le" => "<="
    "ge" => ">="
    "gt" => ">"
    "eq" => "="
    _ => "="
  }
}

///|
fn media_type_label(media_type : @media.MediaType) -> String {
  match media_type {
    @media.MediaType::All => "all"
    @media.MediaType::Screen => "screen"
    @media.MediaType::Print => "print"
    @media.MediaType::Speech => "speech"
  }
}

///|
fn describe_query(query : @media.MediaQuery) -> String {
  let buf = StringBuilder::new()
  if query.negated {
    buf.write_string("not ")
  }
  if query.only {
    buf.write_string("only ")
  }
  let mut wrote_head = false
  match query.media_type {
    Some(media_type) => {
      buf.write_string(media_type_label(media_type))
      wrote_head = true
    }
    None => ()
  }
  for feature in query.conditions {
    if wrote_head {
      buf.write_string(" and ")
    }
    buf.write_string("(")
    buf.write_string(describe_feature(feature))
    buf.write_string(")")
    wrote_head = true
  }
  let rendered = buf.to_string().trim().to_string()
  if rendered.is_empty() {
    "all"
  } else {
    rendered
  }
}

///|
fn describe_breakpoint(
  op : String,
  value_px : Int,
  guards : Array[String],
) -> String {
  let parts : Array[String] = [
    "(width " + op_symbol(op) + " " + value_px.to_string() + "px)",
  ]
  for guard_text in guards {
    parts.push("(" + guard_text + ")")
  }
  parts.join(" and ")
}

///|
fn describe_feature(feature : @media.MediaFeature) -> String {
  match feature {
    @media.MediaFeature::Color => "color"
    @media.MediaFeature::ColorGamut => "color-gamut"
    @media.MediaFeature::ColorIndex => "color-index"
    @media.MediaFeature::Grid => "grid"
    @media.MediaFeature::Hover => "hover"
    @media.MediaFeature::Monochrome => "monochrome"
    @media.MediaFeature::Pointer => "pointer"
    @media.MediaFeature::Scripting => "scripting"
    @media.MediaFeature::Update => "update"
    @media.MediaFeature::Width(Some(value)) =>
      "width: " + describe_media_value(value)
    @media.MediaFeature::Width(None) => "width"
    @media.MediaFeature::MinWidth(value) =>
      "min-width: " + describe_media_value(value)
    @media.MediaFeature::MaxWidth(value) =>
      "max-width: " + describe_media_value(value)
    @media.MediaFeature::Height(Some(value)) =>
      "height: " + describe_media_value(value)
    @media.MediaFeature::Height(None) => "height"
    @media.MediaFeature::MinHeight(value) =>
      "min-height: " + describe_media_value(value)
    @media.MediaFeature::MaxHeight(value) =>
      "max-height: " + describe_media_value(value)
    @media.MediaFeature::AspectRatio(Some(value)) =>
      "aspect-ratio: " + describe_media_value(value)
    @media.MediaFeature::AspectRatio(None) => "aspect-ratio"
    @media.MediaFeature::MinAspectRatio(value) =>
      "min-aspect-ratio: " + describe_media_value(value)
    @media.MediaFeature::MaxAspectRatio(value) =>
      "max-aspect-ratio: " + describe_media_value(value)
    @media.MediaFeature::Resolution(Some(value)) =>
      "resolution: " + describe_media_value(value)
    @media.MediaFeature::Resolution(None) => "resolution"
    @media.MediaFeature::MinResolution(value) =>
      "min-resolution: " + describe_media_value(value)
    @media.MediaFeature::MaxResolution(value) =>
      "max-resolution: " + describe_media_value(value)
    @media.MediaFeature::WidthRange(op, value) =>
      "width " +
      op_symbol(range_op_label(op)) +
      " " +
      describe_media_value(value)
    @media.MediaFeature::HeightRange(op, value) =>
      "height " +
      op_symbol(range_op_label(op)) +
      " " +
      describe_media_value(value)
    @media.MediaFeature::Orientation(value) =>
      "orientation:" + value.to_lower().to_string()
    @media.MediaFeature::DisplayMode(value) =>
      "display-mode:" + value.to_lower().to_string()
    @media.MediaFeature::PrefersColorScheme(value) =>
      "prefers-color-scheme:" + value.to_lower().to_string()
    @media.MediaFeature::PrefersReducedMotion(value) =>
      "prefers-reduced-motion:" + value.to_lower().to_string()
    @media.MediaFeature::Custom(name, Some(value)) =>
      name + ": " + describe_media_value(value)
    @media.MediaFeature::Custom(name, None) => name
  }
}

///|
fn describe_media_value(value : @media.MediaValue) -> String {
  match value {
    @media.MediaValue::Number(number) => number.to_string()
    @media.MediaValue::Dimension(number, unit) => number.to_string() + unit
    @media.MediaValue::Ratio(left, right) =>
      left.to_string() + "/" + right.to_string()
    @media.MediaValue::Ident(value) => value
  }
}

///|
fn range_op_label(op : @media.RangeOp) -> String {
  match op {
    @media.RangeOp::Lt => "lt"
    @media.RangeOp::Le => "le"
    @media.RangeOp::Ge => "ge"
    @media.RangeOp::Gt => "gt"
    @media.RangeOp::Eq => "eq"
  }
}

///|
fn push_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

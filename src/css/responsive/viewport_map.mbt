///|
/// CSS rule-to-viewport mapping for VRT test coverage.

///|
pub struct CssRuleViewportEntry {
  selector : String
  properties : Array[String]
  media_condition : String
  active_at_widths : Array[Int]
  inactive_at_widths : Array[Int]
} derive(Eq, Debug)

///|
pub struct CssRuleViewportMap {
  rules : Array[CssRuleViewportEntry]
} derive(Eq, Debug)

///|
pub struct RequiredTestViewport {
  width : Int
  reason : String
} derive(Eq, Debug)

///|
pub struct RequiredTestViewportsResult {
  viewports : Array[RequiredTestViewport]
} derive(Eq, Debug)

///|
pub impl Show for CssRuleViewportEntry with output(self, logger) {
  logger.write_string("{selector: ")
  logger.write_string(self.selector.to_string())
  logger.write_string(", properties: ")
  logger.write_string(self.properties.to_string())
  logger.write_string(", media_condition: ")
  logger.write_string(self.media_condition.to_string())
  logger.write_string(", active_at_widths: ")
  logger.write_string(self.active_at_widths.to_string())
  logger.write_string(", inactive_at_widths: ")
  logger.write_string(self.inactive_at_widths.to_string())
  logger.write_string("}")
}

///|
pub impl Show for CssRuleViewportMap with output(self, logger) {
  logger.write_string("{rules: ")
  logger.write_string(self.rules.to_string())
  logger.write_string("}")
}

///|
pub impl Show for RequiredTestViewport with output(self, logger) {
  logger.write_string("{width: ")
  logger.write_string(self.width.to_string())
  logger.write_string(", reason: ")
  logger.write_string(self.reason.to_string())
  logger.write_string("}")
}

///|
pub impl Show for RequiredTestViewportsResult with output(self, logger) {
  logger.write_string("{viewports: ")
  logger.write_string(self.viewports.to_string())
  logger.write_string("}")
}

///|
/// Discover which CSS rules are active at which viewport widths.
/// For each media-query-scoped rule, evaluates the query at each given width.
pub fn discover_css_rule_viewport_map(
  html : String,
  viewport_widths : Array[Int],
) -> CssRuleViewportMap {
  let doc = @html.parse_document(html)
  let rules : Array[CssRuleViewportEntry] = []
  // Track unique entries by (selector, media_condition) to merge properties
  let seen : Map[String, Int] = {} // key -> index in rules
  for css_text in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css_text)
    for rule in stylesheet.rules {
      match rule.media_query {
        Some(media_query) => {
          let media_condition = describe_media_query_list(media_query)
          let properties : Array[String] = []
          for decl in rule.declarations {
            match decl.value {
              @cascade.PropertyValue::Value(_) =>
                push_unique_str(properties, decl.property)
              _ => ()
            }
          }
          if properties.is_empty() {
            continue
          }
          let active : Array[Int] = []
          let inactive : Array[Int] = []
          for w in viewport_widths {
            let env = @media.MediaEnvironment::new(w.to_double(), 900.0)
            if media_query.evaluate(env) {
              active.push(w)
            } else {
              inactive.push(w)
            }
          }
          let key = rule.selector_text + "||" + media_condition
          match seen.get(key) {
            Some(idx) => {
              let existing = rules[idx]
              for prop in properties {
                push_unique_str(existing.properties, prop)
              }
            }
            None => {
              seen.set(key, rules.length())
              rules.push({
                selector: rule.selector_text,
                properties,
                media_condition,
                active_at_widths: active,
                inactive_at_widths: inactive,
              })
            }
          }
        }
        None => ()
      }
    }
  }
  { rules, }
}

///|
/// Discover which viewport widths should be tested based on CSS media queries.
/// Returns breakpoint-derived widths with reasons.
pub fn discover_required_test_viewports(
  html : String,
) -> RequiredTestViewportsResult {
  let bp_result = discover_responsive_breakpoints(html)
  let viewports : Array[RequiredTestViewport] = []
  let seen_widths : Map[Int, Bool] = {}
  for bp in bp_result.breakpoints {
    // Test at the breakpoint value itself
    if !seen_widths.contains(bp.value_px) {
      seen_widths.set(bp.value_px, true)
      let reason = bp.rule_count.to_string() +
        " rules have @media " +
        bp.normalized
      viewports.push({ width: bp.value_px, reason })
    }
    // Test just below the breakpoint for max-width / le
    if bp.op == "le" || bp.op == "lt" {
      let below = bp.value_px + 1
      if !seen_widths.contains(below) {
        seen_widths.set(below, true)
        viewports.push({
          width: below,
          reason: "just above @media " + bp.normalized,
        })
      }
    }
    // Test just below the breakpoint for min-width / ge
    if bp.op == "ge" || bp.op == "gt" {
      let below = bp.value_px - 1
      if below > 0 && !seen_widths.contains(below) {
        seen_widths.set(below, true)
        viewports.push({
          width: below,
          reason: "just below @media " + bp.normalized,
        })
      }
    }
  }
  viewports.sort_by(fn(a, b) { a.width.compare(b.width) })
  { viewports, }
}

///|
fn describe_media_query_list(mql : @media.MediaQueryList) -> String {
  let parts : Array[String] = []
  for query in mql.queries {
    parts.push(describe_query(query))
  }
  parts.join(", ")
}

///|
fn push_unique_str(arr : Array[String], value : String) -> Unit {
  if !arr.contains(value) {
    arr.push(value)
  }
}

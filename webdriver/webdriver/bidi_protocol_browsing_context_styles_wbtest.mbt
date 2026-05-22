///|
test "bidi getResponsiveBreakpoints returns canonical breakpoint metadata" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><head><style>@media (min-width: 768px) and (orientation: landscape) { .card { display: block; } }</style></head><body><div class='card'>foo</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.getResponsiveBreakpoints\",\"params\":{\"context\":\"session-1\",\"includeDiagnostics\":true}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let breakpoints = match result.get("breakpoints") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(breakpoints.length(), 1)
  let breakpoint = match breakpoints[0] {
    Object(map) => map
    _ => {}
  }
  match breakpoint.get("axis") {
    Some(String(value)) => assert_eq(value, "width")
    _ => assert_true(false)
  }
  match breakpoint.get("op") {
    Some(String(value)) => assert_eq(value, "ge")
    _ => assert_true(false)
  }
  match breakpoint.get("valuePx") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 768)
    _ => assert_true(false)
  }
  match breakpoint.get("guards") {
    Some(Array(values)) => {
      assert_eq(values.length(), 1)
      match values[0] {
        String(value) => assert_eq(value, "orientation:landscape")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
  let diagnostics = match result.get("diagnostics") {
    Some(Object(map)) => map
    _ => {}
  }
  match diagnostics.get("stylesheetCount") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 1)
    _ => assert_true(false)
  }
  match diagnostics.get("ruleCount") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 1)
    _ => assert_true(false)
  }
}

///|
test "bidi getResponsiveBreakpoints discovers styles inside shadow root" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body><div id='host'></div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const root = host.attachShadow({ mode: 'open' }); root.innerHTML = '<style>@media (min-width: 640px) { .card { display: block; } }</style><div class=\\\"card\\\">foo</div>'; return !!host.shadowRoot; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.getResponsiveBreakpoints\",\"params\":{\"context\":\"session-1\",\"includeDiagnostics\":true}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let breakpoints = match result.get("breakpoints") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(breakpoints.length(), 1)
  let breakpoint = match breakpoints[0] {
    Object(map) => map
    _ => {}
  }
  match breakpoint.get("valuePx") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 640)
    _ => assert_true(false)
  }
  let diagnostics = match result.get("diagnostics") {
    Some(Object(map)) => map
    _ => {}
  }
  match diagnostics.get("stylesheetCount") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 1)
    _ => assert_true(false)
  }
}

///|
test "bidi getComputedStyles returns live inline styles for selector" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body><div class='card'>foo</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const card = document.querySelector('.card'); if (!card) return false; card.setAttribute('style', 'display:flex;padding:12px 24px;color:rgb(31, 35, 40)'); return true; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.getComputedStyles\",\"params\":{\"context\":\"session-1\",\"selector\":\".card\",\"properties\":[\"display\",\"padding\",\"color\"]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let styles = match result.get("styles") {
    Some(Object(map)) => map
    _ => {}
  }
  match styles.get("display") {
    Some(String(value)) => assert_eq(value, "flex")
    _ => assert_true(false)
  }
  match styles.get("padding") {
    Some(String(value)) => assert_eq(value, "12px 24px")
    _ => assert_true(false)
  }
  match styles.get("color") {
    Some(String(value)) => assert_eq(value, "rgb(31, 35, 40)")
    _ => assert_true(false)
  }
}

///|
test "bidi getComputedStyles accepts sharedId target" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body><div class='card'>foo</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const card = document.querySelector('.card'); if (!card) return null; card.setAttribute('style', 'display:flex;padding:12px 24px;color:rgb(31, 35, 40)'); return card; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  let shared_id = extract_shared_id(
    extract_script_remote_value(extract_success_result(proto.take_messages())),
  )
  assert_true(shared_id != "")
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.getComputedStyles\",\"params\":{\"context\":\"session-1\",\"sharedId\":\"" +
      shared_id +
      "\",\"properties\":[\"display\",\"padding\",\"color\"]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let styles = match result.get("styles") {
    Some(Object(map)) => map
    _ => {}
  }
  match styles.get("display") {
    Some(String(value)) => assert_eq(value, "flex")
    _ => assert_true(false)
  }
  match styles.get("padding") {
    Some(String(value)) => assert_eq(value, "12px 24px")
    _ => assert_true(false)
  }
  match styles.get("color") {
    Some(String(value)) => assert_eq(value, "rgb(31, 35, 40)")
    _ => assert_true(false)
  }
}

///|
test "bidi getComputedStyles accepts elementId target" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body><div id='card'>foo</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const card = document.getElementById('card'); if (!card) return false; card.setAttribute('style', 'display:flex;padding:12px 24px;color:rgb(31, 35, 40)'); return true; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.getComputedStyles\",\"params\":{\"context\":\"session-1\",\"elementId\":\"card\",\"properties\":[\"display\",\"padding\",\"color\"]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let styles = match result.get("styles") {
    Some(Object(map)) => map
    _ => {}
  }
  match styles.get("display") {
    Some(String(value)) => assert_eq(value, "flex")
    _ => assert_true(false)
  }
  match styles.get("padding") {
    Some(String(value)) => assert_eq(value, "12px 24px")
    _ => assert_true(false)
  }
  match styles.get("color") {
    Some(String(value)) => assert_eq(value, "rgb(31, 35, 40)")
    _ => assert_true(false)
  }
}

///|
test "bidi getAllComputedStyles returns selector keyed styles" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body><div id='card' style='display:flex'>foo</div><span id='badge' style='color:rgb(255, 0, 0)'>bar</span></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.getAllComputedStyles\",\"params\":{\"context\":\"session-1\",\"properties\":[\"display\",\"color\"]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let styles = match result.get("styles") {
    Some(Object(map)) => map
    _ => {}
  }
  let card = match styles.get("div#card") {
    Some(Object(map)) => map
    _ => {}
  }
  let badge = match styles.get("span#badge") {
    Some(Object(map)) => map
    _ => {}
  }
  match card.get("display") {
    Some(String(value)) => assert_eq(value, "flex")
    _ => assert_true(false)
  }
  match badge.get("color") {
    Some(String(value)) => assert_eq(value, "rgb(255, 0, 0)")
    _ => assert_true(false)
  }
}

///|
test "bidi getComputedStylesWithState accepts hover selector target" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><head><style>.file-table .file-name a { text-decoration: none; } .file-table .file-name a:hover { text-decoration: underline; }</style></head><body><table class='file-table'><tr><td class='file-name'><a href='/README.md'>README.md</a></td></tr></table></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.getComputedStylesWithState\",\"params\":{\"context\":\"session-1\",\"selector\":\".file-table .file-name a:hover\",\"forcedStates\":[\"hover\"],\"properties\":[\"text-decoration\"]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let diff = match result.get("diff") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(diff.length(), 1)
  let entry = match diff[0] {
    Object(map) => map
    _ => {}
  }
  match entry.get("property") {
    Some(String(value)) => assert_eq(value, "text-decoration")
    _ => assert_true(false)
  }
  match entry.get("normal") {
    Some(String(value)) => assert_eq(value, "none")
    _ => assert_true(false)
  }
  match entry.get("forced") {
    Some(String(value)) => assert_eq(value, "underline")
    _ => assert_true(false)
  }
}

///|
test "bidi getCssRuleUsage reports matched and overridden rules" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><head><style>.unused { color: red; } .card { color: red; } div.card { color: blue; } .chip { padding: 4px; }</style></head><body><div id='card' class='card'>A</div><div id='chip' class='chip'>B</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.getCssRuleUsage\",\"params\":{\"context\":\"session-1\"}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let rules = match result.get("rules") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(rules.length(), 4)

  let unused = match rules[0] {
    Object(map) => map
    _ => {}
  }
  match unused.get("selector") {
    Some(String(value)) => assert_eq(value, ".unused")
    _ => assert_true(false)
  }
  match unused.get("matched") {
    Some(False) => ()
    _ => assert_true(false)
  }
  match unused.get("elements") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 0)
    _ => assert_true(false)
  }

  let overridden = match rules[1] {
    Object(map) => map
    _ => {}
  }
  match overridden.get("selector") {
    Some(String(value)) => assert_eq(value, ".card")
    _ => assert_true(false)
  }
  match overridden.get("matched") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match overridden.get("overridden") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match overridden.get("overriddenBy") {
    Some(String(value)) => assert_eq(value, "div.card")
    _ => assert_true(false)
  }

  let elements = match result.get("elements") {
    Some(Object(map)) => map
    _ => {}
  }
  let card = match elements.get("div#card") {
    Some(Object(map)) => map
    _ => {}
  }
  let chip = match elements.get("div#chip") {
    Some(Object(map)) => map
    _ => {}
  }
  match card.get("color") {
    Some(String(value)) => assert_eq(value, "div.card")
    _ => assert_true(false)
  }
  match chip.get("padding") {
    Some(String(value)) => assert_eq(value, ".chip")
    _ => assert_true(false)
  }
}

///|
test "bidi getCssRuleUsage reports inherited and initial no-op rules" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><head><style>.wrapper { color: red; } .child { color: red; } .box { margin: 0; }</style></head><body><div class='wrapper'><span id='child' class='child'>A</span></div><div id='box' class='box'>B</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.getCssRuleUsage\",\"params\":{\"context\":\"session-1\"}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let rules = match result.get("rules") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(rules.length(), 3)

  let child = match rules[1] {
    Object(map) => map
    _ => {}
  }
  match child.get("noEffect") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match child.get("noEffectReason") {
    Some(String(value)) => assert_eq(value, "same_as_inherited")
    _ => assert_true(false)
  }

  let box = match rules[2] {
    Object(map) => map
    _ => {}
  }
  match box.get("noEffect") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match box.get("noEffectReason") {
    Some(String(value)) => assert_eq(value, "same_as_initial")
    _ => assert_true(false)
  }
}

///|
test "bidi getCssRuleUsage reports same-as-fallback no-op rules" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><head><style>.card { color: red; } div.card { color: red; }</style></head><body><div class='card'>A</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.getCssRuleUsage\",\"params\":{\"context\":\"session-1\"}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let rules = match result.get("rules") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(rules.length(), 2)

  let base = match rules[0] {
    Object(map) => map
    _ => {}
  }
  match base.get("overridden") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match base.get("overriddenBy") {
    Some(String(value)) => assert_eq(value, "div.card")
    _ => assert_true(false)
  }

  let duplicate = match rules[1] {
    Object(map) => map
    _ => {}
  }
  match duplicate.get("noEffect") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match duplicate.get("noEffectReason") {
    Some(String(value)) => assert_eq(value, "same_as_fallback")
    _ => assert_true(false)
  }
}

///|

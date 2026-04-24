///|
extern "js" fn js_test_png_dimensions(encoded : String) -> String =
  #| (encoded) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     if (raw.length < 24) return "{}";
  #|     const width =
  #|       ((raw.charCodeAt(16) & 0xff) << 24) |
  #|       ((raw.charCodeAt(17) & 0xff) << 16) |
  #|       ((raw.charCodeAt(18) & 0xff) << 8) |
  #|       (raw.charCodeAt(19) & 0xff);
  #|     const height =
  #|       ((raw.charCodeAt(20) & 0xff) << 24) |
  #|       ((raw.charCodeAt(21) & 0xff) << 16) |
  #|       ((raw.charCodeAt(22) & 0xff) << 8) |
  #|       (raw.charCodeAt(23) & 0xff);
  #|     return JSON.stringify({ width: width >>> 0, height: height >>> 0 });
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_test_pdf_meta(encoded : String) -> String =
  #| (encoded) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     const marker = "%CRATER_META ";
  #|     const start = raw.indexOf(marker);
  #|     if (start < 0) return "{}";
  #|     const lineStart = start + marker.length;
  #|     const lineEnd = raw.indexOf("\n", lineStart);
  #|     return lineEnd >= 0 ? raw.slice(lineStart, lineEnd) : raw.slice(lineStart);
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_test_build_html_data_url(html : String) -> String =
  #| (html) => {
  #|   const text = String(html ?? "");
  #|   return "data:text/html;charset=utf-8;base64," + btoa(unescape(encodeURIComponent(text)));
  #| }

///|
extern "js" fn js_test_rgba_meta(
  encoded : String,
  width : Int,
  x : Int,
  y : Int,
) -> String =
  #| (encoded, width, x, y) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     const bytes = Uint8Array.from(raw, (ch) => ch.charCodeAt(0));
  #|     const index = ((Number(y) * Number(width)) + Number(x)) * 4;
  #|     return JSON.stringify({
  #|       length: bytes.length,
  #|       r: bytes[index] ?? -1,
  #|       g: bytes[index + 1] ?? -1,
  #|       b: bytes[index + 2] ?? -1,
  #|       a: bytes[index + 3] ?? -1,
  #|     });
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
fn extract_success_result(msgs : Array[BidiOutMessage]) -> Map[String, Json] {
  let json = @json.parse(msgs[0].to_json()) catch { _ => make_object({}) }
  match json {
    Object(map) =>
      match map.get("result") {
        Some(Object(result)) => result
        _ => {}
      }
    _ => {}
  }
}

///|
fn png_dimensions_from_base64(encoded : String) -> (Int, Int) {
  let parsed = @json.parse(js_test_png_dimensions(encoded)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => {
      let width = match map.get("width") {
        Some(Number(value, ..)) => value.to_int()
        _ => 0
      }
      let height = match map.get("height") {
        Some(Number(value, ..)) => value.to_int()
        _ => 0
      }
      (width, height)
    }
    _ => (0, 0)
  }
}

///|
fn pdf_meta_from_base64(encoded : String) -> Map[String, Json] {
  let parsed = @json.parse(js_test_pdf_meta(encoded)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => map
    _ => {}
  }
}

///|
fn rgba_meta_from_base64(
  encoded : String,
  width : Int,
  x : Int,
  y : Int,
) -> Map[String, Json] {
  let parsed = @json.parse(js_test_rgba_meta(encoded, width, x, y)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => map
    _ => {}
  }
}

///|
fn extract_script_remote_value(result : Map[String, Json]) -> Map[String, Json] {
  match result.get("result") {
    Some(Object(value)) => value
    _ => {}
  }
}

///|
fn extract_shared_id(result : Map[String, Json]) -> String {
  match result.get("sharedId") {
    Some(String(value)) => value
    _ => ""
  }
}

///|
test "bidi captureScreenshot uses viewport and document dimensions" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div style='margin-top:2000px'>foo</div>\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.captureScreenshot\",\"params\":{\"context\":\"session-1\",\"origin\":\"viewport\"}}",
    ),
  )
  let viewport_result = extract_success_result(proto.take_messages())
  let viewport_data = match viewport_result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  let (viewport_width, viewport_height) = png_dimensions_from_base64(
    viewport_data,
  )
  assert_eq(viewport_width, 1024)
  assert_eq(viewport_height, 768)

  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.captureScreenshot\",\"params\":{\"context\":\"session-1\",\"origin\":\"document\"}}",
    ),
  )
  let document_result = extract_success_result(proto.take_messages())
  let document_data = match document_result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  let (document_width, document_height) = png_dimensions_from_base64(
    document_data,
  )
  assert_eq(document_width, 1024)
  assert_true(document_height > viewport_height)
}

///|
test "bidi capturePaintData returns actual viewport rgba payload" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.setViewport\",\"params\":{\"context\":\"session-1\",\"viewport\":{\"width\":320,\"height\":240}}}",
    ),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff'><div style='width:120px;height:90px;background:#ff0000'></div></body></html>"
  let navigate_message = "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.capturePaintData\",\"params\":{\"context\":\"session-1\",\"origin\":\"viewport\"}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let width = match result.get("width") {
    Some(Number(value, ..)) => value.to_int()
    _ => 0
  }
  let height = match result.get("height") {
    Some(Number(value, ..)) => value.to_int()
    _ => 0
  }
  let data = match result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  assert_eq(width, 320)
  assert_eq(height, 240)
  let red_meta = rgba_meta_from_base64(data, width, 40, 40)
  let white_meta = rgba_meta_from_base64(data, width, 200, 200)
  match red_meta.get("length") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), width * height * 4)
    _ => assert_true(false)
  }
  match red_meta.get("r") {
    Some(Number(value, ..)) => assert_true(value > 200)
    _ => assert_true(false)
  }
  match red_meta.get("g") {
    Some(Number(value, ..)) => assert_true(value < 80)
    _ => assert_true(false)
  }
  match red_meta.get("b") {
    Some(Number(value, ..)) => assert_true(value < 80)
    _ => assert_true(false)
  }
  match white_meta.get("r") {
    Some(Number(value, ..)) => assert_true(value > 200)
    _ => assert_true(false)
  }
  match white_meta.get("g") {
    Some(Number(value, ..)) => assert_true(value > 200)
    _ => assert_true(false)
  }
  match white_meta.get("b") {
    Some(Number(value, ..)) => assert_true(value > 200)
    _ => assert_true(false)
  }
}

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
test "bidi print embeds synthetic pdf metadata" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"background\":true,\"orientation\":\"landscape\",\"page\":{\"width\":10,\"height\":20}}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let pdf_data = match result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  let meta = pdf_meta_from_base64(pdf_data)
  match meta.get("background") {
    Some(True) => ()
    _ => assert_true(false)
  }
  match meta.get("orientation") {
    Some(String(value)) => assert_eq(value, "landscape")
    _ => assert_true(false)
  }
  match meta.get("pageWidthCm") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 20)
    _ => assert_true(false)
  }
  match meta.get("pageHeightCm") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 10)
    _ => assert_true(false)
  }
}

///|
test "bidi printData returns raw pdf payload" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.printData\",\"params\":{\"context\":\"session-1\",\"background\":true}}",
    ),
  )
  let json = proto.take_messages()[0].to_json()
  let parsed = @json.parse(json) catch { _ => make_object({}) }
  let pdf_data = match parsed {
    Object(map) =>
      match map.get("result") {
        Some(String(value)) => value
        _ => ""
      }
    _ => ""
  }
  let meta = pdf_meta_from_base64(pdf_data)
  match meta.get("background") {
    Some(True) => ()
    _ => assert_true(false)
  }
}

///|
test "bidi print metadata clamps one-sided margin to minimum printable height" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"margin\":{\"top\":26.94}}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let pdf_data = match result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  let meta = pdf_meta_from_base64(pdf_data)
  match meta.get("pageWidthCm") {
    Some(Number(value, ..)) => assert_eq(value, 21.59)
    _ => assert_true(false)
  }
  match meta.get("pageHeightCm") {
    Some(Number(value, ..)) => assert_true(value < 27.94 && value > 27.9)
    _ => assert_true(false)
  }
}

///|
test "bidi print embeds filtered page content metadata" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  let page_url = js_test_build_html_data_url(
    "<style>div {page-break-after: always}</style><div>Page 1</div><div>Page 2</div><div>Page 3</div><div>Page 4</div><div>Page 5</div>",
  )
  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
      page_url +
      "\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"pageRanges\":[\"2-4\",\"4-5\"]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let pdf_data = match result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  let meta = pdf_meta_from_base64(pdf_data)
  match meta.get("pages") {
    Some(Array(pages)) => {
      assert_eq(pages.length(), 4)
      inspect(
        pages.map(fn(page) {
          match page {
            String(value) => value
            _ => ""
          }
        }),
        content="[\"Page 2\", \"Page 3\", \"Page 4\", \"Page 5\"]",
      )
    }
    _ => assert_true(false)
  }
}

///|
test "bidi print render signature matches scaled equivalent content" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  let base_url = js_test_build_html_data_url(
    "<style>html,body{margin:0;}div{background-color:black;width:100px;height:100px;}</style><div></div>",
  )
  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
      base_url +
      "\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"background\":true,\"scale\":2}}",
    ),
  )
  let scaled_meta = pdf_meta_from_base64(
    match extract_success_result(proto.take_messages()).get("data") {
      Some(String(value)) => value
      _ => ""
    },
  )

  let reference_url = js_test_build_html_data_url(
    "<style>html,body{margin:0;}div{background-color:black;width:200px;height:200px;}</style><div></div>",
  )
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
      reference_url +
      "\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":5,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"background\":true}}",
    ),
  )
  let reference_meta = pdf_meta_from_base64(
    match extract_success_result(proto.take_messages()).get("data") {
      Some(String(value)) => value
      _ => ""
    },
  )

  let scaled_signature = match scaled_meta.get("signature") {
    Some(String(value)) => value
    _ => ""
  }
  let reference_signature = match reference_meta.get("signature") {
    Some(String(value)) => value
    _ => ""
  }
  assert_eq(scaled_signature, reference_signature)
}

///|
test "bidi print render signature matches equivalent top margin css" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  let base_url = js_test_build_html_data_url(
    "<style>html,body{margin:0;}div{background-color:black;height:27.94cm;}</style><div></div>",
  )
  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
      base_url +
      "\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"background\":true,\"shrinkToFit\":false,\"margin\":{\"top\":2.54}}}",
    ),
  )
  let margin_meta = pdf_meta_from_base64(
    match extract_success_result(proto.take_messages()).get("data") {
      Some(String(value)) => value
      _ => ""
    },
  )

  let reference_url = js_test_build_html_data_url(
    "<style>html,body{margin:0;}div{background-color:black;height:27.94cm;margin-top:1.54cm;}</style><div></div>",
  )
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
      reference_url +
      "\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":5,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"background\":true,\"shrinkToFit\":false}}",
    ),
  )
  let reference_meta = pdf_meta_from_base64(
    match extract_success_result(proto.take_messages()).get("data") {
      Some(String(value)) => value
      _ => ""
    },
  )

  let margin_signature = match margin_meta.get("signature") {
    Some(String(value)) => value
    _ => ""
  }
  let reference_signature = match reference_meta.get("signature") {
    Some(String(value)) => value
    _ => ""
  }
  assert_eq(margin_signature, reference_signature)
}

///|
test "bidi captureScreenshotData returns raw png payload" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.captureScreenshotData\",\"params\":{\"context\":\"session-1\",\"origin\":\"viewport\"}}",
    ),
  )
  let json = proto.take_messages()[0].to_json()
  let parsed = @json.parse(json) catch { _ => make_object({}) }
  let png_data = match parsed {
    Object(map) =>
      match map.get("result") {
        Some(String(value)) => value
        _ => ""
      }
    _ => ""
  }
  let (width, height) = png_dimensions_from_base64(png_data)
  assert_eq(width, 1024)
  assert_eq(height, 768)
}

///|
test "bidi print validates shrink_to_fit alias" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.print\",\"params\":{\"context\":\"session-1\",\"shrink_to_fit\":{}}}",
    ),
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"message\":\"shrinkToFit must be a boolean\""))
}

///|
test "bidi locateNodes validates max_node_count alias" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div>foo</div>\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.locateNodes\",\"params\":{\"context\":\"session-1\",\"locator\":{\"type\":\"css\",\"value\":\"div\"},\"max_node_count\":0}}",
    ),
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(
    json.contains(
      "\"message\":\"maxNodeCount must be an integer in [1, 9007199254740991]\"",
    ),
  )
}

///|
test "bidi locateNodes accepts shadow root sharedId in startNodes" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const root = host.attachShadow({ mode: 'open' }); root.innerHTML = '<button class=\\\"target\\\">one</button><button class=\\\"target\\\">two</button>'; return root; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  let shadow_root_id = extract_shared_id(
    extract_script_remote_value(extract_success_result(proto.take_messages())),
  )
  assert_true(shadow_root_id != "")

  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.locateNodes\",\"params\":{\"context\":\"session-1\",\"locator\":{\"type\":\"css\",\"value\":\".target\"},\"startNodes\":[{\"sharedId\":\"" +
      shadow_root_id +
      "\"}]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  match result.get("nodes") {
    Some(Array(nodes)) => assert_eq(nodes.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "bidi locateNodes innerText accepts shadow root sharedId in startNodes" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const root = host.attachShadow({ mode: 'open' }); root.innerHTML = '<section><span>alpha beta</span></section><span>gamma</span>'; return root; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  let shadow_root_id = extract_shared_id(
    extract_script_remote_value(extract_success_result(proto.take_messages())),
  )
  assert_true(shadow_root_id != "")

  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.locateNodes\",\"params\":{\"context\":\"session-1\",\"locator\":{\"type\":\"innerText\",\"value\":\"alpha beta\",\"matchType\":\"full\"},\"startNodes\":[{\"sharedId\":\"" +
      shadow_root_id +
      "\"}]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  match result.get("nodes") {
    Some(Array(nodes)) => assert_eq(nodes.length(), 1)
    _ => assert_true(false)
  }
}

///|
test "bidi locateNodes accessibility accepts shadow root sharedId in startNodes" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const root = host.attachShadow({ mode: 'open' }); root.innerHTML = '<button aria-label=\\\"Shadow CTA\\\">ignored</button><button aria-label=\\\"Other\\\">other</button>'; return root; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  let shadow_root_id = extract_shared_id(
    extract_script_remote_value(extract_success_result(proto.take_messages())),
  )
  assert_true(shadow_root_id != "")

  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.locateNodes\",\"params\":{\"context\":\"session-1\",\"locator\":{\"type\":\"accessibility\",\"value\":{\"role\":\"button\",\"name\":\"Shadow CTA\"}},\"startNodes\":[{\"sharedId\":\"" +
      shadow_root_id +
      "\"}]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  match result.get("nodes") {
    Some(Array(nodes)) => assert_eq(nodes.length(), 1)
    _ => assert_true(false)
  }
}

///|
test "bidi locateNodes xpath accepts shadow root sharedId in startNodes" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\",\"wait\":\"complete\"}}",
    ),
  )
  ignore(proto.take_messages())

  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const root = host.attachShadow({ mode: 'open' }); root.innerHTML = '<button data-kind=\\\"target\\\">one</button><button data-kind=\\\"target\\\">two</button><button data-kind=\\\"other\\\">other</button>'; return root; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
    ),
  )
  let shadow_root_id = extract_shared_id(
    extract_script_remote_value(extract_success_result(proto.take_messages())),
  )
  assert_true(shadow_root_id != "")

  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.locateNodes\",\"params\":{\"context\":\"session-1\",\"locator\":{\"type\":\"xpath\",\"value\":\".//button[@data-kind='target']\"},\"startNodes\":[{\"sharedId\":\"" +
      shadow_root_id +
      "\"}]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  match result.get("nodes") {
    Some(Array(nodes)) => assert_eq(nodes.length(), 2)
    _ => assert_true(false)
  }
}

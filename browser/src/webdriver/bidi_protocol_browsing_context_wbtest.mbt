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

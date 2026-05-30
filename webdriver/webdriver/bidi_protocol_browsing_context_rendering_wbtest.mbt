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
  match result.get("timing") {
    Some(Object(timing)) => {
      assert_true(timing.get("paintTreeMs") != None)
      assert_true(timing.get("rasterMs") != None)
      assert_true(timing.get("totalMs") != None)
    }
    _ => assert_true(false)
  }
  match result.get("visual") {
    Some(Object(visual)) => {
      match visual.get("nonWhitePixels") {
        Some(Number(value, ..)) => assert_true(value > 0)
        _ => assert_true(false)
      }
      match visual.get("isBlank") {
        Some(False) => ()
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "bidi captureScreenshotData uses actual paint png for viewport" {
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
      "{\"id\":4,\"method\":\"browsingContext.captureScreenshotData\",\"params\":{\"context\":\"session-1\",\"origin\":\"viewport\"}}",
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
  let red_meta = png_pixel_meta_from_base64(png_data, 40, 40)
  let white_meta = png_pixel_meta_from_base64(png_data, 200, 200)
  match red_meta.get("width") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 320)
    _ => assert_true(false)
  }
  match red_meta.get("height") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 240)
    _ => assert_true(false)
  }
  match red_meta.get("nonWhite") {
    Some(Number(value, ..)) => assert_true(value > 0)
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
test "bidi captureScreenshotData uses actual paint png for document origin" {
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
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff;height:410px;position:relative'><div style='position:absolute;left:0;top:0;width:120px;height:80px;background:#ff0000'></div><div style='position:absolute;left:0;top:340px;width:90px;height:70px;background:#00aa00'></div></body></html>"
  let navigate_message = "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.captureScreenshotData\",\"params\":{\"context\":\"session-1\",\"origin\":\"document\"}}",
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
  let top_meta = png_pixel_meta_from_base64(png_data, 40, 40)
  let lower_meta = png_pixel_meta_from_base64(png_data, 40, 360)
  match top_meta.get("width") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 320)
    _ => assert_true(false)
  }
  match top_meta.get("height") {
    Some(Number(value, ..)) => assert_true(value.to_int() > 240)
    _ => assert_true(false)
  }
  match top_meta.get("r") {
    Some(Number(value, ..)) => assert_true(value > 200)
    _ => assert_true(false)
  }
  match top_meta.get("g") {
    Some(Number(value, ..)) => assert_true(value < 80)
    _ => assert_true(false)
  }
  match top_meta.get("b") {
    Some(Number(value, ..)) => assert_true(value < 80)
    _ => assert_true(false)
  }
  match lower_meta.get("r") {
    Some(Number(value, ..)) => assert_true(value < 80)
    _ => assert_true(false)
  }
  match lower_meta.get("g") {
    Some(Number(value, ..)) => assert_true(value > 120)
    _ => assert_true(false)
  }
  match lower_meta.get("b") {
    Some(Number(value, ..)) => assert_true(value < 80)
    _ => assert_true(false)
  }
}

///|
test "bidi captureScreenshotData document origin ignores fixed overflow for height" {
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
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff;height:420px'><main style='height:420px;background:#ffffff'></main><div style='position:fixed;left:0;top:2500px;width:80px;height:20px;background:#000000'></div></body></html>"
  let navigate_message = "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.captureScreenshotData\",\"params\":{\"context\":\"session-1\",\"origin\":\"document\"}}",
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
  let (document_width, document_height) = png_dimensions_from_base64(png_data)
  assert_eq(document_width, 320)
  assert_eq(document_height, 420)
}

///|
test "bidi captureScreenshotData keeps viewport layout when document is horizontally scrollable" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":2,\"method\":\"browsingContext.setViewport\",\"params\":{\"context\":\"session-1\",\"viewport\":{\"width\":320,\"height\":180}}}",
    ),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff'><div style='width:800px;height:20px;background:#000000'></div><div><span style='display:inline-block;width:100px;height:40px;background:#ff0000'></span><span style='display:inline-block;width:100px;height:40px;background:#00ff00'></span><span style='display:inline-block;width:100px;height:40px;background:#0000ff'></span><span style='display:inline-block;width:100px;height:40px;background:#ff0000'></span><span style='display:inline-block;width:100px;height:40px;background:#00ff00'></span><span style='display:inline-block;width:100px;height:40px;background:#0000ff'></span><span style='display:inline-block;width:100px;height:40px;background:#ff0000'></span><span style='display:inline-block;width:100px;height:40px;background:#00ff00'></span><span style='display:inline-block;width:100px;height:40px;background:#0000ff'></span><span style='display:inline-block;width:100px;height:40px;background:#ff0000'></span><span style='display:inline-block;width:100px;height:40px;background:#00ff00'></span><span style='display:inline-block;width:100px;height:40px;background:#0000ff'></span><span style='display:inline-block;width:100px;height:40px;background:#ff0000'></span><span style='display:inline-block;width:100px;height:40px;background:#00ff00'></span><span style='display:inline-block;width:100px;height:40px;background:#0000ff'></span><span style='display:inline-block;width:100px;height:40px;background:#ff0000'></span><span style='display:inline-block;width:100px;height:40px;background:#00ff00'></span><span style='display:inline-block;width:100px;height:40px;background:#0000ff'></span></div></body></html>"
  let navigate_message = "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.captureScreenshotData\",\"params\":{\"context\":\"session-1\",\"origin\":\"document\"}}",
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
  let (document_width, document_height) = png_dimensions_from_base64(png_data)
  assert_eq(document_width, 800)
  assert_true(document_height > 180)
}

///|

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
test "bidi renderSelector crops to the selected element" {
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
  let html = "<!DOCTYPE html><html><body style='margin:0;background:#ffffff'><div class='target' style='width:120px;height:90px;background:#ff0000'></div></body></html>"
  let navigate_message = "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.renderSelector\",\"params\":{\"context\":\"session-1\",\"selector\":\".target\"}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let width = match result.get("width") {
    Some(Number(value, ..)) => value.to_int()
    _ => -1
  }
  let height = match result.get("height") {
    Some(Number(value, ..)) => value.to_int()
    _ => -1
  }
  // cropped output matches the element's box, not the full 320x240 viewport
  assert_eq(width, 120)
  assert_eq(height, 90)
  let data = match result.get("data") {
    Some(String(value)) => value
    _ => ""
  }
  let meta = rgba_meta_from_base64(data, width, 10, 10)
  match meta.get("length") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), width * height * 4)
    _ => assert_true(false)
  }
  let bbox = match result.get("boundingBox") {
    Some(Object(map)) => map
    _ => {}
  }
  match bbox.get("width") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 120)
    _ => assert_true(false)
  }
  match bbox.get("height") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 90)
    _ => assert_true(false)
  }
}

///|
test "bidi diffPaintTree reports layout shift and paint property change" {
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
  let baseline = "<!DOCTYPE html><html><body style='margin:0'><div class='box' style='width:120px;height:50px;background:#ff0000'>x</div></body></html>"
  let current = "<!DOCTYPE html><html><body style='margin:0'><div class='box' style='width:200px;height:50px;background:#00ff00'>x</div></body></html>"
  let msg = "{\"id\":3,\"method\":\"browsingContext.diffPaintTree\",\"params\":{\"context\":\"session-1\",\"baseline\":{\"html\":\"" +
    baseline +
    "\"},\"current\":{\"html\":\"" +
    current +
    "\"}}}"
  ignore(proto.process_message(msg))
  let result = extract_success_result(proto.take_messages())
  let shifts = match result.get("layoutShifts") {
    Some(Array(items)) => items
    _ => []
  }
  // the box widened 120 -> 200, so some node reports dw == 80
  let mut saw_width_shift = false
  for shift in shifts {
    match shift {
      Object(map) =>
        match map.get("dw") {
          Some(Number(v, ..)) =>
            if (v - 80.0).abs() < 0.5 {
              saw_width_shift = true
            }
          _ => ()
        }
      _ => ()
    }
  }
  assert_true(saw_width_shift)
  let changes = match result.get("changes") {
    Some(Array(items)) => items
    _ => []
  }
  // background changed red -> green, which a pixel diff at the box would catch
  // but the structured diff names the property explicitly
  let mut saw_bg_change = false
  for change in changes {
    match change {
      Object(map) =>
        match map.get("property") {
          Some(String("background-color")) => saw_bg_change = true
          _ => ()
        }
      _ => ()
    }
  }
  assert_true(saw_bg_change)
}

///|
test "bidi mutateStyle reports affected nodes and layout changes" {
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
  let html = "<!DOCTYPE html><html><head><style>.box{width:120px;height:50px}</style></head><body style='margin:0'><div class='box'>x</div></body></html>"
  let navigate_message = "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  ignore(
    proto.process_message(
      "{\"id\":4,\"method\":\"browsingContext.mutateStyle\",\"params\":{\"context\":\"session-1\",\"mutations\":[{\"selector\":\".box\",\"property\":\"width\",\"action\":\"set\",\"value\":\"200px\"}]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  let affected = match result.get("affectedNodes") {
    Some(Array(items)) => items
    _ => []
  }
  assert_true(affected.length() > 0)
  let layout_changes = match result.get("layoutChanges") {
    Some(Array(items)) => items
    _ => []
  }
  // the box widened 120 -> 200 under the .box{width:200px} mutation
  let mut saw_box_widen = false
  for change in layout_changes {
    match change {
      Object(map) => {
        let before_w = match map.get("before") {
          Some(Object(b)) =>
            match b.get("width") {
              Some(Number(v, ..)) => v
              _ => 0.0
            }
          _ => 0.0
        }
        let after_w = match map.get("after") {
          Some(Object(a)) =>
            match a.get("width") {
              Some(Number(v, ..)) => v
              _ => 0.0
            }
          _ => 0.0
        }
        if (after_w - before_w - 80.0).abs() < 0.5 {
          saw_box_widen = true
        }
      }
      _ => ()
    }
  }
  assert_true(saw_box_widen)
}

///|
/// Regression (#246 review #2): mutateStyle must not let a mutation value break
/// out of the injected <style> block. A value containing '}' is rejected, so it
/// cannot mutate unintended nodes.
test "bidi mutateStyle rejects style-breaking mutation tokens" {
  let proto = BidiProtocol::new()
  ignore(
    proto.process_message("{\"id\":1,\"method\":\"session.new\",\"params\":{}}"),
  )
  ignore(proto.take_messages())
  let html = "<!DOCTYPE html><html><head><style>.box{width:120px;height:50px}</style></head><body style='margin:0'><div class='box'>x</div><div class='other' style='width:30px;height:30px'>y</div></body></html>"
  let navigate_message = "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    js_test_build_html_data_url(html) +
    "\",\"wait\":\"complete\"}}"
  ignore(proto.process_message(navigate_message))
  ignore(proto.take_messages())
  // Malicious value tries to close the .box rule and add a rule for .other.
  ignore(
    proto.process_message(
      "{\"id\":3,\"method\":\"browsingContext.mutateStyle\",\"params\":{\"context\":\"session-1\",\"mutations\":[{\"selector\":\".box\",\"property\":\"width\",\"action\":\"set\",\"value\":\"120px} .other{width:300px\"}]}}",
    ),
  )
  let result = extract_success_result(proto.take_messages())
  // The injection token is rejected, so nothing changes -> no layout changes.
  let layout_changes = match result.get("layoutChanges") {
    Some(Array(items)) => items
    _ => []
  }
  assert_eq(layout_changes.length(), 0)
}

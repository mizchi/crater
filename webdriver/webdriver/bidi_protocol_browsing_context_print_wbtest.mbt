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
        content="[Page 2, Page 3, Page 4, Page 5]",
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

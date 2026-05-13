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

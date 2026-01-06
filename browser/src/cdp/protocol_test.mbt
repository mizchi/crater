///|
/// CDP Protocol Tests
///
/// Tests for JSON-RPC protocol handling.

///|
test "CdpProtocol processes Target.createBrowserContext" {
  let protocol = CdpProtocol::new()
  let json =
    #|{"id":1,"method":"Target.createBrowserContext"}
  let result = protocol.process_message(json)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  inspect(messages.length(), content="1")
}

///|
test "CdpProtocol processes Target.createTarget" {
  let protocol = CdpProtocol::new()
  // First create a context
  let json1 =
    #|{"id":1,"method":"Target.createBrowserContext"}
  let _ = protocol.process_message(json1)
  let _ = protocol.take_messages()
  // Create target
  let json2 =
    #|{"id":2,"method":"Target.createTarget","params":{"url":"about:blank"}}
  let result = protocol.process_message(json2)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  inspect(messages.length(), content="1")
}

///|
test "CdpProtocol handles invalid JSON" {
  let protocol = CdpProtocol::new()
  let result = protocol.process_message("not json")
  inspect(result is Err(_), content="true")
}

///|
test "CdpProtocol handles missing method" {
  let protocol = CdpProtocol::new()
  let json =
    #|{"id":1}
  let result = protocol.process_message(json)
  inspect(result is Err(_), content="true")
}

///|
test "CdpProtocol handles unknown domain" {
  let protocol = CdpProtocol::new()
  let json =
    #|{"id":1,"method":"Unknown.method"}
  let result = protocol.process_message(json)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  inspect(messages.length(), content="1")
  // Should return an error response
  let msg = messages[0]
  match msg {
    Response(resp) => inspect(resp.error is Some(_), content="true")
    _ => inspect(false, content="true")
  }
}

///|
test "CdpProtocol processes Browser.getVersion" {
  let protocol = CdpProtocol::new()
  let json =
    #|{"id":1,"method":"Browser.getVersion"}
  let result = protocol.process_message(json)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  inspect(messages.length(), content="1")
}

///|
test "CdpProtocol processes Page.navigate" {
  let protocol = CdpProtocol::new()
  // First create context and target
  let json1 =
    #|{"id":1,"method":"Target.createBrowserContext"}
  let _ = protocol.process_message(json1)
  let _ = protocol.take_messages()
  let json2 =
    #|{"id":2,"method":"Target.createTarget","params":{"url":"about:blank"}}
  let _ = protocol.process_message(json2)
  let _ = protocol.take_messages()
  // Navigate
  let json3 =
    #|{"id":3,"method":"Page.navigate","params":{"url":"http://example.com"}}
  let result = protocol.process_message(json3)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  inspect(messages.length(), content="1")
}

///|
test "CdpProtocol processes DOM.getDocument" {
  let protocol = CdpProtocol::new()
  // First create context, target, and load HTML
  let json1 =
    #|{"id":1,"method":"Target.createBrowserContext"}
  let _ = protocol.process_message(json1)
  let _ = protocol.take_messages()
  let json2 =
    #|{"id":2,"method":"Target.createTarget","params":{"url":"about:blank"}}
  let _ = protocol.process_message(json2)
  let _ = protocol.take_messages()
  // Get document
  let json3 =
    #|{"id":3,"method":"DOM.getDocument","params":{"depth":1}}
  let result = protocol.process_message(json3)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  inspect(messages.length(), content="1")
}

///|
test "CdpOutMessage.to_json serializes response" {
  let resp = CdpResponse::new(
    Some(1),
    Some(Json::object({ "test": Json::boolean(true) })),
    None,
    None,
  )
  let msg = CdpOutMessage::response(resp)
  let json_str = msg.to_json()
  inspect(json_str.contains("\"id\":1"), content="true")
  inspect(json_str.contains("\"result\""), content="true")
}

///|
test "CdpOutMessage.to_json serializes event" {
  let evt = CdpEvent::new(
    "Target.targetCreated",
    Some(Json::object({ "targetId": Json::string("TID-1") })),
    None,
  )
  let msg = CdpOutMessage::event(evt)
  let json_str = msg.to_json()
  inspect(
    json_str.contains("\"method\":\"Target.targetCreated\""),
    content="true",
  )
  inspect(json_str.contains("\"targetId\""), content="true")
}

///|
test "CdpProtocol processes Target.attachToTarget" {
  let protocol = CdpProtocol::new()
  // Create context and target
  let json1 =
    #|{"id":1,"method":"Target.createBrowserContext"}
  let _ = protocol.process_message(json1)
  let _ = protocol.take_messages()
  let json2 =
    #|{"id":2,"method":"Target.createTarget","params":{"url":"about:blank"}}
  let _ = protocol.process_message(json2)
  let msgs = protocol.take_messages()
  // Get target ID from response
  let target_id = match msgs[0] {
    Response(resp) =>
      match resp.result {
        Some(Object(map)) =>
          match map.get("targetId") {
            Some(String(id)) => id
            _ => "unknown"
          }
        _ => "unknown"
      }
    _ => "unknown"
  }
  // Attach to target
  let json3 = "{\"id\":3,\"method\":\"Target.attachToTarget\",\"params\":{\"targetId\":\"" +
    target_id +
    "\"}}"
  let result = protocol.process_message(json3)
  inspect(result is Ok(_), content="true")
  let messages = protocol.take_messages()
  // Should have event + response
  inspect(messages.length(), content="2")
}

///|
test "CdpProtocol processes enable/disable methods" {
  let protocol = CdpProtocol::new()
  // Create a target first (needed for Runtime.enable to send events)
  let _ = protocol.process_message(
    "{\"id\":0,\"method\":\"Target.createTarget\",\"params\":{\"url\":\"about:blank\"}}",
  )
  let _ = protocol.take_messages()
  // Test various enable methods
  let methods_list = [
    "DOM.enable", "Page.enable", "Network.enable", "Security.enable",
    "Performance.enable", "Log.enable",
  ]
  for m in methods_list {
    let json = "{\"id\":1,\"method\":\"" + m + "\"}"
    let result = protocol.process_message(json)
    inspect(result is Ok(_), content="true")
    let messages = protocol.take_messages()
    inspect(messages.length(), content="1")
  }
  // Runtime.enable sends additional executionContextCreated events
  let runtime_result = protocol.process_message(
    "{\"id\":2,\"method\":\"Runtime.enable\"}",
  )
  inspect(runtime_result is Ok(_), content="true")
  let runtime_messages = protocol.take_messages()
  // 1 result + 2 executionContextCreated events
  inspect(runtime_messages.length(), content="3")
}

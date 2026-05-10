///|
/// WebDriver BiDi script fixture, page setup, user context, and subscription helper tests.

///|
test "bidi script getElementForTest returns first matching node" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='target'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.getElementForTest\",\"params\":{\"context\":\"session-1\",\"selector\":\"#target\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains("\"result\":{\"type\":\"node\",\"sharedId\":\"node-"),
  )
}

///|
test "bidi script getElementForTest creates textarea fallback when requested" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.getElementForTest\",\"params\":{\"context\":\"session-1\",\"selector\":\"textarea\",\"allowFrameFallback\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains("\"result\":{\"type\":\"node\",\"sharedId\":\"node-"),
  )
}

///|
test "bidi script prepareLoadedStaticTestPage dispatches DOMContentLoaded and resets allEvents" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<script>var allEvents={events:[{type:'stale'}]};document.addEventListener('DOMContentLoaded',function(){window.__domcontentloaded_ran=true;});</script><input id='keys'><div id='outer'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify({count: window.allEvents.events.length, dom: !!window.__domcontentloaded_ran, focused: globalThis.__bidiFocusedElement === null})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"count\\\":0,\\\"dom\\\":true,\\\"focused\\\":true}\"",
    ),
  )
}

///|
test "bidi script prepareLoadedStaticTestPage inlineScripts runs scripts in order" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='root'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"phase\":\"inlineScripts\",\"scripts\":[\"window.__inlineOrder = [1];\",\"window.__inlineOrder.push(2);\"]}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify(window.__inlineOrder)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[1,2]\""))
}

///|
test "bidi script inlineScripts exposes window properties as globals" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<body></body>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"phase\":\"inlineScripts\",\"scripts\":[\"Object.assign(window, { __craterBareProbe: function(){ document.body.setAttribute('data-probe','ok'); } });\",\"__craterBareProbe();\"]}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"document.body.getAttribute('data-probe')\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"ok\""))
}

///|
test "bidi script prepareLoadedStaticTestPage extracts inline scripts from html" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='root'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"phase\":\"inlineScripts\",\"html\":\"<script src='skip.js'></script><script>window.__inlineOrder = [1];</script><script>window.__inlineOrder.push(2);</script>\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify(window.__inlineOrder)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[1,2]\""))
}

///|
test "bidi script loadStaticTestPageForTest navigates and prepares allEvents" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let html = "<script>var allEvents={events:[{type:'stale'}]};document.addEventListener('DOMContentLoaded',function(){window.__domcontentloaded_ran=true;});</script><input id='keys'><div id='outer'></div>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.loadStaticTestPageForTest\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"html\":\"" +
    escape_json_string(html) +
    "\"}}",
  )
  let load_json = proto.take_messages()[0].to_json()
  assert_true(load_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify({count: window.allEvents.events.length, dom: !!window.__domcontentloaded_ran, focused: globalThis.__bidiFocusedElement === null, dataUrl: window.location.href.startsWith('data:text/html')})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"count\\\":0,\\\"dom\\\":true,\\\"focused\\\":true,\\\"dataUrl\\\":true}\"",
    ),
  )
}

///|
test "bidi script setupBeforeunloadPageForTest marks input as interacted" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='target'>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.setupBeforeunloadPageForTest\",\"params\":{\"context\":\"session-1\"}}",
  )
  let setup_json = proto.take_messages()[0].to_json()
  assert_true(setup_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const input = document.getElementById('target'); return { value: input && typeof input.value === 'string' ? input.value : '', focused: globalThis.__bidiFocusedElement === input }; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"value\\\":\\\"foo\\\",\\\"focused\\\":true}\"",
    ),
  )
}

///|
test "bidi script prepareBeforeunloadPageForTest navigates and sets up page" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.prepareBeforeunloadPageForTest\",\"params\":{\"context\":\"session-1\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))
  assert_true(
    prepare_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\"",
    ),
  )

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const input = document.querySelector('input'); return { value: input && typeof input.value === 'string' ? input.value : '', focused: globalThis.__bidiFocusedElement === input, url: window.location.href }; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"value\\\":\\\"foo\\\",\\\"focused\\\":true,\\\"url\\\":\\\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\\\"}\"",
    ),
  )
}

///|
test "bidi script prepareBeforeunloadPageUrlForTest returns raw url string" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.prepareBeforeunloadPageUrlForTest\",\"params\":{\"context\":\"session-1\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))
  assert_true(
    prepare_json.contains(
      "\"result\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\"",
    ),
  )
  assert_false(prepare_json.contains("\"navigation\""))
}

///|
test "bidi script prepareLoadedStaticTestPage pageSpecific styles actions fixture" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div class='area' id='area'></div><div class='block' id='block'></div><div id='trackPointer'></div><div id='resultContainer'></div><div id='dragArea'></div><div id='dragTarget'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"phase\":\"pageSpecific\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const area = document.getElementById('area'); const dragTarget = document.getElementById('dragTarget'); return {areaWidth: area && area.style ? area.style.width : '', dragTop: dragTarget && dragTarget.style ? dragTarget.style.top : '', dragLeft: dragTarget && dragTarget.style ? dragTarget.style.left : ''}; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"areaWidth\\\":\\\"100px\\\",\\\"dragTop\\\":\\\"22px\\\",\\\"dragLeft\\\":\\\"47px\\\"}\"",
    ),
  )
}

///|
test "bidi script prepareLoadedStaticTestPage pageSpecific sets wheel fixture" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='root'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions_scroll.html\",\"phase\":\"pageSpecific\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const scrollable = document.getElementById('scrollable'); const iframe = document.getElementById('iframe'); return {overflow: scrollable && scrollable.style ? scrollable.style.overflow : '', hasRecorder: typeof window.recordWheelEvent === 'function', iframeSetup: !!(iframe && iframe.__craterWheelIframeSetup)}; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"overflow\\\":\\\"scroll\\\",\\\"hasRecorder\\\":true,\\\"iframeSetup\\\":true}\"",
    ),
  )
}

///|
test "bidi script createIframeContextForTest returns child context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.createIframeContextForTest\",\"params\":{\"context\":\"session-1\",\"url\":\"about:blank\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-"))
  assert_true(json.contains("\"parentContext\":\"session-1\""))
}

///|
test "bidi script createIframeContextIdForTest returns raw child context id" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.createIframeContextIdForTest\",\"params\":{\"context\":\"session-1\",\"url\":\"about:blank\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":\"session-"))
  assert_false(json.contains("\"parentContext\""))
}

///|
test "bidi browser hasUserContext reflects current user contexts" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.hasUserContext\",\"params\":{\"userContext\":\"default\"}}",
  )
  let default_json = proto.take_messages()[0].to_json()
  assert_true(default_json.contains("\"type\":\"success\""))
  assert_true(default_json.contains("\"known\":true"))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  let create_json = proto.take_messages()[0].to_json()
  assert_true(create_json.contains("\"userContext\":\"user-1\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browser.hasUserContext\",\"params\":{\"userContext\":\"user-1\"}}",
  )
  let created_json = proto.take_messages()[0].to_json()
  assert_true(created_json.contains("\"type\":\"success\""))
  assert_true(created_json.contains("\"known\":true"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browser.removeUserContext\",\"params\":{\"userContext\":\"user-1\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"browser.hasUserContext\",\"params\":{\"userContext\":\"user-1\"}}",
  )
  let removed_json = proto.take_messages()[0].to_json()
  assert_true(removed_json.contains("\"type\":\"success\""))
  assert_true(removed_json.contains("\"known\":false"))
}

///|
test "bidi browser hasUserContextValue returns raw bool" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.hasUserContextValue\",\"params\":{\"userContext\":\"default\"}}",
  )
  let default_json = proto.take_messages()[0].to_json()
  assert_true(default_json.contains("\"type\":\"success\""))
  assert_true(default_json.contains("\"result\":true"))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browser.hasUserContextValue\",\"params\":{\"userContext\":\"missing\"}}",
  )
  let missing_json = proto.take_messages()[0].to_json()
  assert_true(missing_json.contains("\"type\":\"success\""))
  assert_true(missing_json.contains("\"result\":false"))
}

///|
test "bidi session isSubscribedForContext follows parent context subscriptions" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.isSubscribedForContext\",\"params\":{\"event\":\"network.beforeRequestSent\",\"context\":\"session-2\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"subscribed\":true"))
}

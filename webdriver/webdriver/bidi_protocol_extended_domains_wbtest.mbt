///|
/// WebDriver BiDi permissions, webExtension, speculation, bluetooth, and emulation regression tests.

///|
test "bidi permissions setPermission validates descriptor type" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"permissions.setPermission\",\"params\":{\"descriptor\":false,\"state\":\"granted\",\"origin\":\"https://example.com/\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi script callFunctionResult unwraps synthetic permissions query state" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"https://example.com/common/blank.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"permissions.setPermission\",\"params\":{\"descriptor\":{\"name\":\"geolocation\"},\"state\":\"granted\",\"origin\":\"https://example.com/\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"() => { return navigator.permissions.query({ name: 'geolocation' }).then(val => val.state, err => err.message) }\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\"") == false)
  assert_true(json.contains("\"value\":\"granted\""))
}

///|
test "bidi webExtension install validates extensionData type" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"webExtension.install\",\"params\":{\"extensionData\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi webExtension install accepts valid base64 payload and uninstall removes it" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"webExtension.install\",\"params\":{\"extensionData\":{\"type\":\"base64\",\"value\":\"Q3IyNA==\"}}}",
  )
  let install_json = proto.take_messages()[0].to_json()
  assert_true(install_json.contains("\"type\":\"success\""))
  assert_true(install_json.contains("\"extension\":\"web-extension-1\""))

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"webExtension.uninstall\",\"params\":{\"extension\":\"web-extension-1\"}}",
  )
  let uninstall_json = proto.take_messages()[0].to_json()
  assert_true(uninstall_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"webExtension.uninstall\",\"params\":{\"extension\":\"web-extension-1\"}}",
  )
  let missing_json = proto.take_messages()[0].to_json()
  assert_true(missing_json.contains("\"type\":\"error\""))
  assert_true(missing_json.contains("\"error\":\"no such web extension\""))
}

///|
test "bidi webExtension installId returns raw extension id string" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"webExtension.installId\",\"params\":{\"extensionData\":{\"type\":\"base64\",\"value\":\"Q3IyNA==\"}}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":\"web-extension-1\""))
  assert_true(json.contains("\"extension\"") == false)
}

///|
test "bidi webExtension install rejects malformed base64 as unknown error" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"webExtension.install\",\"params\":{\"extensionData\":{\"type\":\"base64\",\"value\":\"not a base64\"}}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"unknown error\""))
}

///|
test "bidi speculation rules emit pending and ready events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"speculation.prefetchStatusUpdated\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"const script = document.createElement('script'); script.type = 'speculationrules'; script.textContent = `{\\\"prefetch\\\":[{\\\"where\\\":{\\\"href_matches\\\":\\\"https://example.com/common/dummy.xml\\\"},\\\"eagerness\\\":\\\"immediate\\\"}]}`; document.head.appendChild(script);\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let messages = proto.take_messages()
  assert_eq(messages.length(), 3)
  let pending_json = messages[0].to_json()
  let ready_json = messages[1].to_json()
  let response_json = messages[2].to_json()
  assert_true(
    pending_json.contains("\"method\":\"speculation.prefetchStatusUpdated\""),
  )
  assert_true(pending_json.contains("\"status\":\"pending\""))
  assert_true(ready_json.contains("\"status\":\"ready\""))
  assert_true(response_json.contains("\"type\":\"success\""))
}

///|
test "bidi speculation click emits success event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"speculation.prefetchStatusUpdated\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"const script = document.createElement('script'); script.type = 'speculationrules'; script.textContent = `{\\\"prefetch\\\":[{\\\"where\\\":{\\\"href_matches\\\":\\\"https://example.com/common/dummy.xml\\\"},\\\"eagerness\\\":\\\"immediate\\\"}]}`; document.head.appendChild(script);\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"const prefetchLink = document.getElementById('prefetch-page'); if (prefetchLink) { prefetchLink.click(); }\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let messages = proto.take_messages()
  assert_eq(messages.length(), 2)
  let success_json = messages[0].to_json()
  let response_json = messages[1].to_json()
  assert_true(
    success_json.contains("\"method\":\"speculation.prefetchStatusUpdated\""),
  )
  assert_true(success_json.contains("\"status\":\"success\""))
  assert_true(response_json.contains("\"type\":\"success\""))
}

///|
test "bidi bluetooth requestDevice emits prompt event and resolves on accept" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"bluetooth.requestDevicePromptUpdated\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"bluetooth.simulateAdapter\",\"params\":{\"context\":\"session-1\",\"state\":\"powered-on\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"bluetooth.simulatePreconnectedPeripheral\",\"params\":{\"context\":\"session-1\",\"address\":\"09:09:09:09:09:09\",\"name\":\"SOME_BL_DEVICE\",\"manufacturer_data\":[{\"key\":17,\"data\":\"AP8BAX8=\"}],\"known_service_uuids\":[\"12345678-1234-5678-9abc-def123456789\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"async (device_name)=>{ const device = await navigator.bluetooth.requestDevice({ filters: [{name:device_name}] }); return { id: device.id, name: device.name, } }\",\"arguments\":[{\"type\":\"string\",\"value\":\"SOME_BL_DEVICE\"}],\"target\":{\"context\":\"session-1\"},\"await_promise\":true,\"user_activation\":true}}",
  )
  let prompt_messages = proto.take_messages()
  assert_eq(prompt_messages.length(), 1)
  let prompt_json = prompt_messages[0].to_json()
  assert_true(
    prompt_json.contains("\"method\":\"bluetooth.requestDevicePromptUpdated\""),
  )
  assert_true(prompt_json.contains("\"id\":\"09:09:09:09:09:09\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"bluetooth.handleRequestDevicePrompt\",\"params\":{\"context\":\"session-1\",\"prompt\":\"bluetooth-prompt-1\",\"accept\":true,\"device\":\"09:09:09:09:09:09\"}}",
  )
  let messages = proto.take_messages()
  assert_eq(messages.length(), 2)
  let request_json = messages[0].to_json()
  let command_json = messages[1].to_json()
  assert_true(request_json.contains("\"type\":\"success\""))
  assert_true(request_json.contains("\"value\":\"09:09:09:09:09:09\""))
  assert_true(request_json.contains("\"value\":\"SOME_BL_DEVICE\""))
  assert_true(command_json.contains("\"type\":\"success\""))
}

///|
test "bidi bluetooth preconnected peripheral validates manufacturer data key" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"bluetooth.simulatePreconnectedPeripheral\",\"params\":{\"context\":\"session-1\",\"address\":\"09:09:09:09:09:09\",\"name\":\"SOME_BL_DEVICE\",\"manufacturer_data\":[{\"key\":-1,\"data\":\"AP8BAX8=\"}],\"known_service_uuids\":[\"12345678-1234-5678-9abc-def123456789\"]}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi bluetooth getCharacteristics returns simulated uuids" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let ctx_id = "session-1"
  let address = "09:09:09:09:09:09"
  let service_uuid = "0000180d-0000-1000-8000-00805f9b34fb"
  let characteristic_uuid = "00002a08-0000-1000-8000-00805f9b34fb"
  proto.bluetooth_granted_devices_by_context[ctx_id] = [
    make_object({
      "address": Json::string(address),
      "name": Json::string("SOME_BL_DEVICE"),
      "manufacturerData": Json::array([]),
      "knownServiceUuids": Json::array([]),
    }),
  ]
  proto.bluetooth_services_by_scope[bluetooth_scope_key(ctx_id, address)] = [
    service_uuid,
  ]
  proto.bluetooth_characteristics_by_scope[bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  )] = make_object({ "broadcast": Json::boolean(true) })

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"async ()=>{ const devices = await navigator.bluetooth.getDevices(); const device = devices[0]; const service = await device.gatt.getPrimaryService('0000180d-0000-1000-8000-00805f9b34fb'); const characteristics = await service.getCharacteristics(); return characteristics.map(c => c.uuid) }\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"type\":\"array\""))
  assert_true(json.contains(characteristic_uuid))
}

///|
test "bidi bluetooth getCharacteristic returns simulated properties" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let ctx_id = "session-1"
  let address = "09:09:09:09:09:09"
  let service_uuid = "0000180d-0000-1000-8000-00805f9b34fb"
  let characteristic_uuid = "00002a08-0000-1000-8000-00805f9b34fb"
  proto.bluetooth_granted_devices_by_context[ctx_id] = [
    make_object({
      "address": Json::string(address),
      "name": Json::string("SOME_BL_DEVICE"),
      "manufacturerData": Json::array([]),
      "knownServiceUuids": Json::array([]),
    }),
  ]
  proto.bluetooth_services_by_scope[bluetooth_scope_key(ctx_id, address)] = [
    service_uuid,
  ]
  proto.bluetooth_characteristics_by_scope[bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  )] = make_object({
    "broadcast": Json::boolean(true),
    "read": Json::boolean(true),
  })

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"async ()=>{ const toPropertyStrings = (properties) => { let propertyStrings = []; if (properties.broadcast) { propertyStrings.push('broadcast'); } if (properties.read) { propertyStrings.push('read'); } return propertyStrings; }; const devices = await navigator.bluetooth.getDevices(); const device = devices[0]; const service = await device.gatt.getPrimaryService('0000180d-0000-1000-8000-00805f9b34fb'); const characteristic = await service.getCharacteristic('00002a08-0000-1000-8000-00805f9b34fb'); return toPropertyStrings(characteristic.properties); }\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"broadcast\""))
  assert_true(json.contains("\"read\""))
}

///|
test "bidi emulation setUserAgentOverride updates navigator userAgent and headers echo" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"SOME_USER_AGENT\"}}",
  )
  let response_json = proto.take_messages()[0].to_json()
  assert_true(response_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"window.navigator.userAgent\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"type\":\"success\""))
  assert_true(eval_json.contains("\"value\":\"SOME_USER_AGENT\""))

  let headers_payload = proto.build_network_headers_echo_payload("session-1", [])
  assert_true(headers_payload.contains("\"user-agent\":[\"SOME_USER_AGENT\"]"))
}

///|
test "bidi emulation synthetic fetch headers echo uses effective user agent" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"SOME_USER_AGENT\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"fetch('http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py').then(r => r.text())\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"user-agent\":[\"SOME_USER_AGENT\"]"))
}

///|
test "bidi emulation setUserAgentOverride rejects iframe contexts" {
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
    "{\"id\":3,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"contexts\":[\"session-2\"],\"userAgent\":\"SOME_USER_AGENT\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi emulation setLocaleOverride updates locale surfaces and headers echo" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setLocaleOverride\",\"params\":{\"locale\":\"fr-ca\"}}",
  )
  let response_json = proto.take_messages()[0].to_json()
  assert_true(response_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"navigator.language\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let language_json = proto.take_messages()[0].to_json()
  assert_true(language_json.contains("\"type\":\"success\""))
  assert_true(language_json.contains("\"value\":\"fr-CA\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"navigator.languages\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let languages_json = proto.take_messages()[0].to_json()
  assert_true(languages_json.contains("\"type\":\"array\""))
  assert_true(languages_json.contains("\"value\":\"fr-CA\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"new Intl.DateTimeFormat().resolvedOptions().locale\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let locale_json = proto.take_messages()[0].to_json()
  assert_true(locale_json.contains("\"type\":\"success\""))
  assert_true(locale_json.contains("\"value\":\"fr-CA\""))

  let headers_payload = proto.build_network_headers_echo_payload("session-1", [])
  assert_true(headers_payload.contains("\"accept-language\":[\"fr-CA\"]"))
}

///|
test "bidi emulation setLocaleOverride rejects iframe contexts" {
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
    "{\"id\":3,\"method\":\"emulation.setLocaleOverride\",\"params\":{\"contexts\":[\"session-2\"],\"locale\":\"fr-CA\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi emulation setGeolocationOverride validates missing coordinates and error" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setGeolocationOverride\",\"params\":{\"contexts\":[\"session-1\"]}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi emulation setGeolocationOverride returns synthetic current position" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"https://example.com/common/blank.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"permissions.setPermission\",\"params\":{\"descriptor\":{\"name\":\"geolocation\"},\"state\":\"granted\",\"origin\":\"https://example.com/\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"emulation.setGeolocationOverride\",\"params\":{\"contexts\":[\"session-1\"],\"coordinates\":{\"latitude\":4,\"longitude\":2}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"(multiplier) => new Promise(resolve => window.navigator.geolocation.getCurrentPosition(position => resolve(position.coords.toJSON()), error => resolve({code: error.code}), {timeout: 500 * multiplier}))\",\"arguments\":[{\"type\":\"number\",\"value\":1}],\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"latitude\""))
  assert_true(json.contains("\"longitude\""))
  assert_true(json.contains("\"accuracy\""))
  assert_true(json.contains("\"value\":4"))
  assert_true(json.contains("\"value\":2"))
}

///|
test "bidi emulation setGeolocationOverride notifies synthetic watchPosition" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"https://example.com/common/blank.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"permissions.setPermission\",\"params\":{\"descriptor\":{\"name\":\"geolocation\"},\"state\":\"granted\",\"origin\":\"https://example.com/\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"script.message\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"emulation.setGeolocationOverride\",\"params\":{\"contexts\":[\"session-1\"],\"coordinates\":{\"latitude\":4,\"longitude\":2,\"accuracy\":1}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"(channel) => window.navigator.geolocation.watchPosition((result) => channel(result.coords.toJSON()))\",\"arguments\":[{\"type\":\"channel\",\"value\":{\"channel\":\"channel_name\"}}],\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let initial_messages = proto.take_messages()
  assert_eq(initial_messages.length(), 2)
  let initial_watch_json = initial_messages[0].to_json() +
    initial_messages[1].to_json()
  assert_true(initial_watch_json.contains("\"method\":\"script.message\""))
  assert_true(initial_watch_json.contains("\"channel\":\"channel_name\""))
  assert_true(initial_watch_json.contains("\"latitude\""))
  assert_true(initial_watch_json.contains("\"value\":4"))

  let _ = proto.process_message(
    "{\"id\":7,\"method\":\"emulation.setGeolocationOverride\",\"params\":{\"contexts\":[\"session-1\"],\"coordinates\":{\"latitude\":10,\"longitude\":20,\"accuracy\":3}}}",
  )
  let update_messages = proto.take_messages()
  assert_eq(update_messages.length(), 2)
  let update_json = update_messages[0].to_json() + update_messages[1].to_json()
  assert_true(update_json.contains("\"method\":\"script.message\""))
  assert_true(update_json.contains("\"value\":10"))
  assert_true(update_json.contains("\"value\":20"))
  assert_true(update_json.contains("\"value\":3"))
}

///|
test "bidi emulation setNetworkConditions validates missing networkConditions" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"contexts\":[\"session-1\"]}}",
  )
  let messages = proto.take_messages()
  assert_eq(messages.length(), 1)
  let json = messages[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("networkConditions must be provided"))
}

///|
test "bidi emulation setNetworkConditions resolves effective offline by precedence" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  let create_msgs = proto.take_messages()
  let created_user_context_json = @json.parse(create_msgs[0].to_json()) catch {
    _ => Json::null()
  }
  let user_context_id = match created_user_context_json {
    Object(map) =>
      match map.get("result") {
        Some(Object(result_map)) =>
          match result_map.get("userContext") {
            Some(String(id)) => id
            _ => ""
          }
        _ => ""
      }
    _ => ""
  }
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\",\"userContext\":\"" +
    user_context_id +
    "\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"networkConditions\":{\"type\":\"offline\"},\"userContexts\":[\"" +
    user_context_id +
    "\"]}}",
  )
  ignore(proto.take_messages())
  assert_false(proto.resolve_effective_network_offline("session-1"))
  assert_true(proto.resolve_effective_network_offline("session-2"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"networkConditions\":null,\"contexts\":[\"session-2\"]}}",
  )
  ignore(proto.take_messages())
  assert_true(proto.resolve_effective_network_offline("session-2"))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"networkConditions\":{\"type\":\"offline\"},\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())
  assert_true(proto.resolve_effective_network_offline("session-1"))
}

///|
test "bidi script callFunctionResult handles synthetic network fetch probe" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"(url)=>fetch(url)\",\"arguments\":[{\"type\":\"string\",\"value\":\"https://example.com/common/blank.html\"}],\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let online_messages = proto.take_messages()
  assert_eq(online_messages.length(), 1)
  let online_json = online_messages[0].to_json()
  assert_true(online_json.contains("\"type\":\"success\""))
  assert_true(online_json.contains("\"result\":{\"type\":\"undefined\"}"))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"networkConditions\":{\"type\":\"offline\"},\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"(url)=>fetch(url)\",\"arguments\":[{\"type\":\"string\",\"value\":\"https://example.com/common/blank.html\"}],\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let offline_messages = proto.take_messages()
  assert_eq(offline_messages.length(), 1)
  let offline_json = offline_messages[0].to_json()
  assert_true(offline_json.contains("\"exceptionDetails\""))
  assert_true(offline_json.contains("Network is offline"))
}

///|
test "bidi emulation setNetworkConditions emits offline and online script.message events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"script.message\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"(channel)=>{window.addEventListener('offline',(e)=>{channel('offline, isTrusted: '+ e.isTrusted);});window.addEventListener('online',(e)=>{channel('online, isTrusted: '+ e.isTrusted);});}\",\"arguments\":[{\"type\":\"channel\",\"value\":{\"channel\":\"channel_name\"}}],\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"networkConditions\":{\"type\":\"offline\"},\"contexts\":[\"session-1\"]}}",
  )
  let offline_messages = proto.take_messages()
  assert_eq(offline_messages.length(), 2)
  let offline_json = offline_messages[0].to_json() +
    offline_messages[1].to_json()
  assert_true(offline_json.contains("\"method\":\"script.message\""))
  assert_true(offline_json.contains("\"channel\":\"channel_name\""))
  assert_true(offline_json.contains("offline, isTrusted: true"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"emulation.setNetworkConditions\",\"params\":{\"networkConditions\":null,\"contexts\":[\"session-1\"]}}",
  )
  let online_messages = proto.take_messages()
  assert_eq(online_messages.length(), 2)
  let online_json = online_messages[0].to_json() + online_messages[1].to_json()
  assert_true(online_json.contains("\"method\":\"script.message\""))
  assert_true(online_json.contains("\"channel\":\"channel_name\""))
  assert_true(online_json.contains("online, isTrusted: true"))
}

///|
test "bidi emulation setScreenSettingsOverride validates missing screenArea" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setScreenSettingsOverride\",\"params\":{\"contexts\":[\"session-1\"]}}",
  )
  let messages = proto.take_messages()
  assert_eq(messages.length(), 1)
  let json = messages[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("screenArea must be provided"))
}

///|
test "bidi emulation setScreenSettingsOverride resolves effective screen area by precedence" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  let create_msgs = proto.take_messages()
  let created_user_context_json = @json.parse(create_msgs[0].to_json()) catch {
    _ => Json::null()
  }
  let user_context_id = match created_user_context_json {
    Object(map) =>
      match map.get("result") {
        Some(Object(result_map)) =>
          match result_map.get("userContext") {
            Some(String(id)) => id
            _ => ""
          }
        _ => ""
      }
    _ => ""
  }
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\",\"userContext\":\"" +
    user_context_id +
    "\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"emulation.setScreenSettingsOverride\",\"params\":{\"screenArea\":{\"width\":120,\"height\":140},\"userContexts\":[\"" +
    user_context_id +
    "\"]}}",
  )
  ignore(proto.take_messages())
  let session1_area = proto
    .resolve_effective_screen_area("session-1")
    .stringify()
  let session2_area = proto
    .resolve_effective_screen_area("session-2")
    .stringify()
  assert_true(session1_area.contains("\"width\":1024"))
  assert_true(session2_area.contains("\"width\":120"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"emulation.setScreenSettingsOverride\",\"params\":{\"screenArea\":null,\"contexts\":[\"session-2\"]}}",
  )
  ignore(proto.take_messages())
  let reset_area = proto.resolve_effective_screen_area("session-2").stringify()
  assert_true(reset_area.contains("\"width\":120"))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"emulation.setScreenSettingsOverride\",\"params\":{\"screenArea\":{\"width\":200,\"height\":220},\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())
  let override_area = proto
    .resolve_effective_screen_area("session-1")
    .stringify()
  assert_true(override_area.contains("\"width\":200"))
  assert_true(override_area.contains("\"height\":220"))
}

///|
test "bidi emulation setScreenSettingsOverride updates runtime screen metrics and matchMedia" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setScreenSettingsOverride\",\"params\":{\"screenArea\":{\"width\":100,\"height\":120},\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify({width: screen.width, height: screen.height, availWidth: screen.availWidth, availHeight: screen.availHeight, min99: matchMedia('(min-device-width: 99px)').matches, min101: matchMedia('(min-device-width: 101px)').matches})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\\\"width\\\":100"))
  assert_true(json.contains("\\\"height\\\":120"))
  assert_true(json.contains("\\\"availWidth\\\":100"))
  assert_true(json.contains("\\\"availHeight\\\":120"))
  assert_true(json.contains("\\\"min99\\\":true"))
  assert_true(json.contains("\\\"min101\\\":false"))
}

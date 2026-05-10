///|
/// WebDriver BiDi input actions, shadow retargeting, file dialog, and setFiles regression tests.

///|
test "bidi input performActions validates context type" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.performActions\",\"params\":{\"context\":true,\"actions\":[]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi input performActions validates unknown context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.performActions\",\"params\":{\"context\":\"missing\",\"actions\":[]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"no such frame\""))
}

///|
test "bidi input key actions update focused input value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='keys'><script>document.getElementById('keys').focus()</script>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"a\"},{\"type\":\"keyUp\",\"value\":\"a\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.getElementById('keys').value\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"a\""))
}

///|
test "bidi input key actions update shadow-focused input value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host'></div><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open'});const input=document.createElement('input');input.id='keys';shadow.appendChild(input);input.focus();}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"a\"},{\"type\":\"keyUp\",\"value\":\"a\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.getElementById('host').shadowRoot.querySelector('#keys').value\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"a\""))
}

///|
test "bidi input Tab moves focus into and out of shadow root controls" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<input id='first'><div id='host'></div><input id='last'><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open'});const input=document.createElement('input');input.id='inner';shadow.appendChild(input);}document.getElementById('first').focus();</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE004\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); return JSON.stringify([document.activeElement === host, host.shadowRoot.activeElement && host.shadowRoot.activeElement.id || '']); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,\\\"inner\\\"]\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE004\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); return JSON.stringify([document.activeElement && document.activeElement.id || '', host.shadowRoot.activeElement === null]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let after_msgs = proto.take_messages()
  assert_eq(after_msgs.length(), 1)
  let after_json = after_msgs[0].to_json()
  assert_true(after_json.contains("\"type\":\"success\""))
  assert_true(after_json.contains("\"value\":\"[\\\"last\\\",true]\""))
}

///|
test "bidi input Shift+Tab moves focus from shadow root control to previous light DOM control" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<input id='first'><div id='host'></div><input id='last'><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open'});const input=document.createElement('input');input.id='inner';shadow.appendChild(input);input.focus();}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE008\"},{\"type\":\"keyDown\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE008\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); return JSON.stringify([document.activeElement && document.activeElement.id || '', host.shadowRoot.activeElement === null]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[\\\"first\\\",true]\""))
}

///|
test "bidi input Tab moves focus through named slotted control" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<input id='first'><div id='host'></div><input id='last'><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');shadow.appendChild(slot);const input=document.createElement('input');input.id='slotted';input.setAttribute('slot','content');host.appendChild(input);}document.getElementById('first').focus();</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE004\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.activeElement && document.activeElement.id || ''\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"slotted\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE004\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.activeElement && document.activeElement.id || ''\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let after_msgs = proto.take_messages()
  assert_eq(after_msgs.length(), 1)
  let after_json = after_msgs[0].to_json()
  assert_true(after_json.contains("\"type\":\"success\""))
  assert_true(after_json.contains("\"value\":\"last\""))
}

///|
test "bidi input Shift+Tab moves focus from named slotted control to previous light DOM control" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<input id='first'><div id='host'></div><input id='last'><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');shadow.appendChild(slot);const input=document.createElement('input');input.id='slotted';input.setAttribute('slot','content');host.appendChild(input);input.focus();}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE008\"},{\"type\":\"keyDown\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE004\"},{\"type\":\"keyUp\",\"value\":\"\\uE008\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.activeElement && document.activeElement.id || ''\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"first\""))
}

///|
test "bidi script focus inside shadow root updates activeElement chain" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open'}); const inner = document.createElement('input'); shadow.appendChild(inner); inner.focus(); return JSON.stringify([document.activeElement === host, shadow.activeElement === inner]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true]\""))
}

///|
test "bidi script focus on delegatesFocus host reaches first shadow descendant" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open', delegatesFocus:true}); const inner = document.createElement('button'); inner.id = 'inner'; shadow.appendChild(inner); host.focus(); return JSON.stringify([document.activeElement === host, shadow.activeElement === inner, shadow.delegatesFocus === true]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true,true]\""))
}

///|
test "bidi script focus on delegatesFocus host reaches slotted focusable descendant" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open', delegatesFocus:true}); const slot = document.createElement('slot'); slot.setAttribute('name', 'content'); shadow.appendChild(slot); const input = document.createElement('input'); input.id = 'slotted'; input.setAttribute('slot', 'content'); host.appendChild(input); host.focus(); return JSON.stringify([document.activeElement === input, shadow.activeElement === null]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true]\""))
}

///|
test "bidi input pointer actions on delegatesFocus host focus first shadow descendant" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open',delegatesFocus:true});const inner=document.createElement('button');inner.id='inner';inner.style.width='20px';inner.style.height='20px';shadow.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":80,\"y\":80},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.shadowRoot; return JSON.stringify([document.activeElement === host, shadow.activeElement && shadow.activeElement.id === 'inner']); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true]\""))
}

///|
test "bidi input pointer actions on delegatesFocus host focus slotted descendant" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>const host=document.getElementById('host');if(!host.shadowRoot){const shadow=host.attachShadow({mode:'open',delegatesFocus:true});const slot=document.createElement('slot');slot.setAttribute('name','content');shadow.appendChild(slot);const input=document.createElement('input');input.id='slotted';input.setAttribute('slot','content');host.appendChild(input);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":80,\"y\":80},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); return JSON.stringify([document.activeElement && document.activeElement.id === 'slotted', host.shadowRoot && host.shadowRoot.activeElement === null]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true]\""))
}

///|
test "bidi script delegatesFocus shadow descendant dispatches focus-family events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open', delegatesFocus:true}); const input = document.createElement('input'); shadow.appendChild(input); const logs = []; for (const type of ['focus','focusin','blur','focusout']) { input.addEventListener(type, () => logs.push(type)); } host.focus(); host.blur(); return JSON.stringify(logs); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"focus\\\",\\\"focusin\\\",\\\"blur\\\",\\\"focusout\\\"]\"",
    ),
  )
}

///|
test "bidi script delegatesFocus slotted descendant dispatches focus-family events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open', delegatesFocus:true}); const slot = document.createElement('slot'); slot.setAttribute('name', 'content'); shadow.appendChild(slot); const input = document.createElement('input'); input.setAttribute('slot', 'content'); host.appendChild(input); const logs = []; for (const type of ['focus','focusin','blur','focusout']) { input.addEventListener(type, () => logs.push(type)); } host.focus(); input.blur(); return JSON.stringify(logs); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"focus\\\",\\\"focusin\\\",\\\"blur\\\",\\\"focusout\\\"]\"",
    ),
  )
}

///|
test "bidi script focusin retargets delegatesFocus shadow descendant to host outside shadow root" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open', delegatesFocus:true}); const input = document.createElement('input'); shadow.appendChild(input); const logs = []; input.addEventListener('focusin', (event) => logs.push('inner:' + String(event.target === input))); shadow.addEventListener('focusin', (event) => logs.push('shadow:' + String(event.target === input))); host.addEventListener('focusin', (event) => logs.push('host:' + String(event.target === host))); document.addEventListener('focusin', (event) => logs.push('doc:' + String(event.target === host))); host.focus(); return JSON.stringify(logs); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:true\\\",\\\"shadow:true\\\",\\\"host:true\\\",\\\"doc:true\\\"]\"",
    ),
  )
}

///|
test "bidi script focusin keeps slotted delegatesFocus target as light DOM node" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open', delegatesFocus:true}); const slot = document.createElement('slot'); slot.setAttribute('name', 'content'); shadow.appendChild(slot); const input = document.createElement('input'); input.setAttribute('slot', 'content'); host.appendChild(input); const logs = []; input.addEventListener('focusin', (event) => logs.push('inner:' + String(event.target === input))); host.addEventListener('focusin', (event) => logs.push('host:' + String(event.target === input))); document.addEventListener('focusin', (event) => logs.push('doc:' + String(event.target === input))); host.focus(); return JSON.stringify(logs); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:true\\\",\\\"host:true\\\",\\\"doc:true\\\"]\"",
    ),
  )
}

///|
test "bidi script focusout and focusin between slotted descendants keep light DOM target and relatedTarget" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open'}); const slot = document.createElement('slot'); slot.setAttribute('name', 'content'); shadow.appendChild(slot); const left = document.createElement('input'); left.id = 'left'; left.setAttribute('slot', 'content'); const right = document.createElement('input'); right.id = 'right'; right.setAttribute('slot', 'content'); host.appendChild(left); host.appendChild(right); left.focus(); const logs = []; left.addEventListener('focusout', (event) => logs.push('left:focusout:' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); right.addEventListener('focusin', (event) => logs.push('right:focusin:' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); host.addEventListener('focusout', (event) => logs.push('host:focusout:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); document.addEventListener('focusout', (event) => logs.push('doc:focusout:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); host.addEventListener('focusin', (event) => logs.push('host:focusin:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); document.addEventListener('focusin', (event) => logs.push('doc:focusin:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); right.focus(); return JSON.stringify(logs); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"left:focusout:right\\\",\\\"host:focusout:left:right\\\",\\\"doc:focusout:left:right\\\",\\\"right:focusin:left\\\",\\\"host:focusin:right:left\\\",\\\"doc:focusin:right:left\\\"]\"",
    ),
  )
}

///|
test "bidi script focusout and focusin between shadow descendants stay inside shadow root" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open'}); const left = document.createElement('input'); left.id = 'left'; const right = document.createElement('input'); right.id = 'right'; shadow.appendChild(left); shadow.appendChild(right); left.focus(); const logs = []; left.addEventListener('focusout', (event) => logs.push('left:focusout:' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); right.addEventListener('focusin', (event) => logs.push('right:focusin:' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); shadow.addEventListener('focusout', (event) => logs.push('shadow:focusout:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); shadow.addEventListener('focusin', (event) => logs.push('shadow:focusin:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'))); host.addEventListener('focusout', () => logs.push('host:focusout')); document.addEventListener('focusout', () => logs.push('doc:focusout')); host.addEventListener('focusin', () => logs.push('host:focusin')); document.addEventListener('focusin', () => logs.push('doc:focusin')); right.focus(); return JSON.stringify(logs); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"left:focusout:right\\\",\\\"shadow:focusout:left:right\\\",\\\"right:focusin:left\\\",\\\"shadow:focusin:right:left\\\"]\"",
    ),
  )
}

///|
test "bidi script shadowRoot querySelector supports :host pseudo-class" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); host.className = 'active'; const shadow = host.attachShadow({mode:'open'}); shadow.innerHTML = '<button id=\\\"inner\\\">ok</button>'; return JSON.stringify([shadow.querySelector(':host') === host, shadow.querySelector(':host(.active)') === host, shadow.querySelector(':host(.missing)') === null, shadow.querySelectorAll(':host').length, shadow.querySelector(':host > #inner') === shadow.firstChild, shadow.querySelectorAll(':host > button').length]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true,true,1,true,1]\""))
}

///|
test "bidi script blur inside shadow root clears activeElement chain" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='host'></div>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const host = document.getElementById('host'); const shadow = host.attachShadow({mode:'open'}); const inner = document.createElement('input'); shadow.appendChild(inner); inner.focus(); inner.blur(); return JSON.stringify([document.activeElement === document.body, shadow.activeElement === null]); })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[true,true]\""))
}

///|
test "bidi input keyUp without keyDown does not dispatch keyboard events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='keys'><script>document.getElementById('keys').focus()</script>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.events=[];const k=document.getElementById('keys');k.focus();['keydown','keypress','keyup'].forEach(t=>k.addEventListener(t,e=>window.events.push({type:e.type,key:e.key,code:e.code})));\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyUp\",\"value\":\"a\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[]\""))
}

///|
test "bidi interaction key command mapping uses shared command names" {
  let down = @interaction.command_name(
    bidi_key_interaction_command("keyDown", "Enter"),
  )
  let up = @interaction.command_name(bidi_key_interaction_command("keyUp", "a"))
  assert_eq(down, "KeyDown(Enter)")
  assert_eq(up, "KeyUp(a)")
}

///|
test "bidi interaction pointer command mapping preserves coords and button" {
  let move_name = @interaction.command_name(
    bidi_pointer_interaction_command("pointerMove", 10.0, 20.0, 0),
  )
  let down = @interaction.command_name(
    bidi_pointer_interaction_command("pointerDown", 11.0, 21.0, 2),
  )
  let up = @interaction.command_name(
    bidi_pointer_interaction_command("pointerUp", 12.0, 22.0, 1),
  )
  assert_eq(move_name, "PointerMove(10,20)")
  assert_eq(down, "PointerButtonDown(11,21,2)")
  assert_eq(up, "PointerButtonUp(12,22,1)")
}

///|
test "bidi input special right key resolves code and key" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='keys'><script>document.getElementById('keys').focus()</script>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.events=[];const k=document.getElementById('keys');k.focus();['keydown','keypress','keyup'].forEach(t=>k.addEventListener(t,e=>window.events.push({type:e.type,key:e.key,code:e.code,location:e.location})));\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE014\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.events[0])\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\\\"key\\\":\\\"ArrowRight\\\""))
  assert_true(json.contains("\\\"code\\\":\\\"ArrowRight\\\""))
}

///|
test "bidi input pointer actions record click event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='outer' style='width:100px;height:100px'></div><script>window.allEvents={events:[]}</script>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events.map(e => e.type))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(
    json.contains(
      "\"value\":\"[\\\"pointerover\\\",\\\"mouseover\\\",\\\"pointerenter\\\",\\\"mouseenter\\\",\\\"pointermove\\\",\\\"mousemove\\\",\\\"pointerdown\\\",\\\"mousedown\\\",\\\"pointerup\\\",\\\"mouseup\\\",\\\"click\\\"]\"",
    ),
  )
}

///|
test "bidi input pointer actions target shadow-root descendants via elementFromPoint" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.allEvents={events:[]};window.shadowClickLog=[];const host=document.getElementById('host');if(!host.__shadowClickTestReady){host.__shadowClickTestReady=true;host.addEventListener('click',()=>window.shadowClickLog.push('host'));const root=host.attachShadow({mode:'open'});const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';inner.addEventListener('click',()=>window.shadowClickLog.push('inner'));root.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const hit = document.elementFromPoint(10, 10); return hit ? (hit.id || hit.tagName || '') : ''; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let hit_msgs = proto.take_messages()
  let hit_json = @json.parse(hit_msgs[0].to_json()) catch { _ => Json::null() }
  let hit_value = match hit_json {
    Object(map) =>
      match map.get("result") {
        Some(Object(result_map)) =>
          match result_map.get("result") {
            Some(Object(remote_map)) =>
              match remote_map.get("value") {
                Some(String(value)) => value
                _ => ""
              }
            _ => ""
          }
        _ => ""
      }
    _ => ""
  }
  assert_eq(hit_value, "inner")

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.shadowClickLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let log_json = @json.parse(msgs[0].to_json()) catch { _ => Json::null() }
  let log_value = match log_json {
    Object(map) =>
      match map.get("result") {
        Some(Object(result_map)) =>
          match result_map.get("result") {
            Some(Object(remote_map)) =>
              match remote_map.get("value") {
                Some(String(value)) => value
                _ => ""
              }
            _ => ""
          }
        _ => ""
      }
    _ => ""
  }
  assert_eq(log_value, "[\"inner\",\"host\"]")
}

///|
test "bidi input pointer click retargets shadow descendant to host outside shadow root" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.shadowTargetLog=[];const host=document.getElementById('host');if(!host.__shadowRetargetReady){host.__shadowRetargetReady=true;const root=host.attachShadow({mode:'open'});const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';inner.addEventListener('click',(event)=>window.shadowTargetLog.push('inner:'+String(event.target===inner)));root.addEventListener('click',(event)=>window.shadowTargetLog.push('shadow:'+String(event.target===inner)));host.addEventListener('click',(event)=>window.shadowTargetLog.push('host:'+String(event.target===host)));document.addEventListener('click',(event)=>window.shadowTargetLog.push('doc:'+String(event.target===host)));root.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.shadowTargetLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:true\\\",\\\"shadow:true\\\",\\\"host:true\\\",\\\"doc:true\\\"]\"",
    ),
  )
}

///|
test "bidi input pointer click keeps slotted descendant as light DOM target" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.slotTargetLog=[];const host=document.getElementById('host');if(!host.__slotRetargetReady){host.__slotRetargetReady=true;const root=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');root.appendChild(slot);const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';inner.setAttribute('slot','content');inner.addEventListener('click',(event)=>window.slotTargetLog.push('inner:'+String(event.target===inner)));host.addEventListener('click',(event)=>window.slotTargetLog.push('host:'+String(event.target===inner)));document.addEventListener('click',(event)=>window.slotTargetLog.push('doc:'+String(event.target===inner)));host.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.slotTargetLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:true\\\",\\\"host:true\\\",\\\"doc:true\\\"]\"",
    ),
  )
}

///|
test "bidi input pointerdown/up and mousedown/up retarget shadow descendant to host" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.shadowPressLog=[];const host=document.getElementById('host');if(!host.__shadowPressReady){host.__shadowPressReady=true;const root=host.attachShadow({mode:'open'});const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';for(const type of ['pointerdown','mousedown','pointerup','mouseup']){inner.addEventListener(type,(event)=>window.shadowPressLog.push('inner:'+type+':'+String(event.target===inner)));root.addEventListener(type,(event)=>window.shadowPressLog.push('shadow:'+type+':'+String(event.target===inner)));host.addEventListener(type,(event)=>window.shadowPressLog.push('host:'+type+':'+String(event.target===host)));document.addEventListener(type,(event)=>window.shadowPressLog.push('doc:'+type+':'+String(event.target===host)));}root.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.shadowPressLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:pointerdown:true\\\",\\\"shadow:pointerdown:true\\\",\\\"host:pointerdown:true\\\",\\\"doc:pointerdown:true\\\",\\\"inner:mousedown:true\\\",\\\"shadow:mousedown:true\\\",\\\"host:mousedown:true\\\",\\\"doc:mousedown:true\\\",\\\"inner:pointerup:true\\\",\\\"shadow:pointerup:true\\\",\\\"host:pointerup:true\\\",\\\"doc:pointerup:true\\\",\\\"inner:mouseup:true\\\",\\\"shadow:mouseup:true\\\",\\\"host:mouseup:true\\\",\\\"doc:mouseup:true\\\"]\"",
    ),
  )
}

///|
test "bidi input pointerdown/up and mousedown/up keep slotted descendant as light DOM target" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.slotPressLog=[];const host=document.getElementById('host');if(!host.__slotPressReady){host.__slotPressReady=true;const root=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');root.appendChild(slot);const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';inner.setAttribute('slot','content');for(const type of ['pointerdown','mousedown','pointerup','mouseup']){inner.addEventListener(type,(event)=>window.slotPressLog.push('inner:'+type+':'+String(event.target===inner)));host.addEventListener(type,(event)=>window.slotPressLog.push('host:'+type+':'+String(event.target===inner)));document.addEventListener(type,(event)=>window.slotPressLog.push('doc:'+type+':'+String(event.target===inner)));}host.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.slotPressLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:pointerdown:true\\\",\\\"host:pointerdown:true\\\",\\\"doc:pointerdown:true\\\",\\\"inner:mousedown:true\\\",\\\"host:mousedown:true\\\",\\\"doc:mousedown:true\\\",\\\"inner:pointerup:true\\\",\\\"host:pointerup:true\\\",\\\"doc:pointerup:true\\\",\\\"inner:mouseup:true\\\",\\\"host:mouseup:true\\\",\\\"doc:mouseup:true\\\"]\"",
    ),
  )
}

///|
test "bidi input hover retargets shadow descendant to host for over/out events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.shadowHoverLog=[];const host=document.getElementById('host');if(!host.__shadowHoverReady){host.__shadowHoverReady=true;const root=host.attachShadow({mode:'open'});const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';for(const type of ['pointerover','mouseover','pointerout','mouseout']){inner.addEventListener(type,(event)=>window.shadowHoverLog.push('inner:'+type+':'+String(event.target===inner)));root.addEventListener(type,(event)=>window.shadowHoverLog.push('shadow:'+type+':'+String(event.target===inner)));host.addEventListener(type,(event)=>window.shadowHoverLog.push('host:'+type+':'+String(event.target===host)));document.addEventListener(type,(event)=>window.shadowHoverLog.push('doc:'+type+':'+String(event.target===host)));}root.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":140,\"y\":140}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.shadowHoverLog.slice(0, 16))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:pointerover:true\\\",\\\"shadow:pointerover:true\\\",\\\"host:pointerover:true\\\",\\\"doc:pointerover:true\\\",\\\"inner:mouseover:true\\\",\\\"shadow:mouseover:true\\\",\\\"host:mouseover:true\\\",\\\"doc:mouseover:true\\\",\\\"inner:pointerout:true\\\",\\\"shadow:pointerout:true\\\",\\\"host:pointerout:true\\\",\\\"doc:pointerout:true\\\",\\\"inner:mouseout:true\\\",\\\"shadow:mouseout:true\\\",\\\"host:mouseout:true\\\",\\\"doc:mouseout:true\\\"]\"",
    ),
  )
}

///|
test "bidi input hover keeps slotted descendant as light DOM target for over/out events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.slotHoverLog=[];const host=document.getElementById('host');if(!host.__slotHoverReady){host.__slotHoverReady=true;const root=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');root.appendChild(slot);const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';inner.setAttribute('slot','content');for(const type of ['pointerover','mouseover','pointerout','mouseout']){inner.addEventListener(type,(event)=>window.slotHoverLog.push('inner:'+type+':'+String(event.target===inner)));host.addEventListener(type,(event)=>window.slotHoverLog.push('host:'+type+':'+String(event.target===inner)));document.addEventListener(type,(event)=>window.slotHoverLog.push('doc:'+type+':'+String(event.target===inner)));}host.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":140,\"y\":140}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.slotHoverLog.slice(0, 12))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:pointerover:true\\\",\\\"host:pointerover:true\\\",\\\"doc:pointerover:true\\\",\\\"inner:mouseover:true\\\",\\\"host:mouseover:true\\\",\\\"doc:mouseover:true\\\",\\\"inner:pointerout:true\\\",\\\"host:pointerout:true\\\",\\\"doc:pointerout:true\\\",\\\"inner:mouseout:true\\\",\\\"host:mouseout:true\\\",\\\"doc:mouseout:true\\\"]\"",
    ),
  )
}

///|
test "bidi input hover keeps enter leave events on shadow descendant" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.shadowEnterLeaveLog=[];const host=document.getElementById('host');if(!host.__shadowEnterLeaveReady){host.__shadowEnterLeaveReady=true;const root=host.attachShadow({mode:'open'});const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';for(const type of ['pointerenter','mouseenter','pointerleave','mouseleave']){inner.addEventListener(type,(event)=>window.shadowEnterLeaveLog.push('inner:'+type+':'+String(event.target===inner)));root.addEventListener(type,(event)=>window.shadowEnterLeaveLog.push('shadow:'+type+':'+String(event.target===inner)));host.addEventListener(type,(event)=>window.shadowEnterLeaveLog.push('host:'+type+':'+String(event.target===host)));document.addEventListener(type,(event)=>window.shadowEnterLeaveLog.push('doc:'+type+':'+String(event.target===host)));}root.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":140,\"y\":140}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.shadowEnterLeaveLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:pointerenter:true\\\",\\\"inner:mouseenter:true\\\",\\\"inner:pointerleave:true\\\",\\\"inner:mouseleave:true\\\"]\"",
    ),
  )
}

///|
test "bidi input hover keeps enter leave events on slotted descendant" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:100px;height:100px'></div><script>window.slotEnterLeaveLog=[];const host=document.getElementById('host');if(!host.__slotEnterLeaveReady){host.__slotEnterLeaveReady=true;const root=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');root.appendChild(slot);const inner=document.createElement('button');inner.id='inner';inner.style.width='100px';inner.style.height='100px';inner.setAttribute('slot','content');for(const type of ['pointerenter','mouseenter','pointerleave','mouseleave']){inner.addEventListener(type,(event)=>window.slotEnterLeaveLog.push('inner:'+type+':'+String(event.target===inner)));host.addEventListener(type,(event)=>window.slotEnterLeaveLog.push('host:'+type+':'+String(event.target===inner)));document.addEventListener(type,(event)=>window.slotEnterLeaveLog.push('doc:'+type+':'+String(event.target===inner)));}host.appendChild(inner);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":140,\"y\":140}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.slotEnterLeaveLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"inner:pointerenter:true\\\",\\\"inner:mouseenter:true\\\",\\\"inner:pointerleave:true\\\",\\\"inner:mouseleave:true\\\"]\"",
    ),
  )
}

///|
test "bidi input hover between shadow descendants stays inside shadow root" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:120px;height:50px'></div><script>window.shadowInternalHoverLog=[];const host=document.getElementById('host');if(!host.__shadowInternalHoverReady){host.__shadowInternalHoverReady=true;const root=host.attachShadow({mode:'open'});const left=document.createElement('button');left.id='left';left.style.position='absolute';left.style.left='0px';left.style.top='0px';left.style.width='50px';left.style.height='50px';const right=document.createElement('button');right.id='right';right.style.position='absolute';right.style.left='60px';right.style.top='0px';right.style.width='50px';right.style.height='50px';for(const type of ['pointerover','mouseover','pointerout','mouseout']){left.addEventListener(type,(event)=>window.shadowInternalHoverLog.push('left:'+type+':'+(event.relatedTarget?event.relatedTarget.id:'none')));right.addEventListener(type,(event)=>window.shadowInternalHoverLog.push('right:'+type+':'+(event.relatedTarget?event.relatedTarget.id:'none')));root.addEventListener(type,(event)=>window.shadowInternalHoverLog.push('shadow:'+type+':'+(event.target.id||'')));host.addEventListener(type,(event)=>window.shadowInternalHoverLog.push('host:'+type+':'+String(event.target===host)+':'+String(event.relatedTarget===host)));document.addEventListener(type,(event)=>window.shadowInternalHoverLog.push('doc:'+type+':'+String(event.target===host)+':'+String(event.relatedTarget===host)));}root.appendChild(left);root.appendChild(right);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":70,\"y\":10}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.shadowInternalHoverLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"left:pointerover:none\\\",\\\"shadow:pointerover:left\\\",\\\"host:pointerover:true:false\\\",\\\"doc:pointerover:true:false\\\",\\\"left:mouseover:none\\\",\\\"shadow:mouseover:left\\\",\\\"host:mouseover:true:false\\\",\\\"doc:mouseover:true:false\\\",\\\"left:pointerout:right\\\",\\\"shadow:pointerout:left\\\",\\\"left:mouseout:right\\\",\\\"shadow:mouseout:left\\\",\\\"right:pointerover:left\\\",\\\"shadow:pointerover:right\\\",\\\"right:mouseover:left\\\",\\\"shadow:mouseover:right\\\"]\"",
    ),
  )
}

///|
test "bidi input hover between slotted descendants keeps light DOM target and relatedTarget outside shadow root" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:120px;height:50px'></div><script>window.slotInternalHoverLog=[];const host=document.getElementById('host');if(!host.__slotInternalHoverReady){host.__slotInternalHoverReady=true;const root=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');root.appendChild(slot);const left=document.createElement('button');left.id='left';left.slot='content';left.style.position='absolute';left.style.left='0px';left.style.top='0px';left.style.width='50px';left.style.height='50px';const right=document.createElement('button');right.id='right';right.slot='content';right.style.position='absolute';right.style.left='60px';right.style.top='0px';right.style.width='50px';right.style.height='50px';for(const type of ['pointerover','mouseover','pointerout','mouseout']){left.addEventListener(type,(event)=>window.slotInternalHoverLog.push('left:'+type+':'+(event.relatedTarget?event.relatedTarget.id:'none')));right.addEventListener(type,(event)=>window.slotInternalHoverLog.push('right:'+type+':'+(event.relatedTarget?event.relatedTarget.id:'none')));host.addEventListener(type,(event)=>window.slotInternalHoverLog.push('host:'+type+':'+(event.target?event.target.id:'')+':'+(event.relatedTarget?event.relatedTarget.id:'none')));document.addEventListener(type,(event)=>window.slotInternalHoverLog.push('doc:'+type+':'+(event.target?event.target.id:'')+':'+(event.relatedTarget?event.relatedTarget.id:'none')));}host.appendChild(left);host.appendChild(right);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":70,\"y\":10}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.slotInternalHoverLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\\\"left:pointerout:right\\\""))
  assert_true(json.contains("\\\"host:pointerout:left:right\\\""))
  assert_true(json.contains("\\\"doc:pointerout:left:right\\\""))
  assert_true(json.contains("\\\"right:pointerover:left\\\""))
  assert_true(json.contains("\\\"host:pointerover:right:left\\\""))
  assert_true(json.contains("\\\"doc:pointerover:right:left\\\""))
}

///|
test "bidi input hover enter leave between slotted descendants keeps relatedTarget and does not leak outside shadow root" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let html = "data:text/html,<div id='host' style='position:relative;width:120px;height:50px'></div><script>window.slotInternalEnterLeaveLog=[];const host=document.getElementById('host');if(!host.__slotInternalEnterLeaveReady){host.__slotInternalEnterLeaveReady=true;const root=host.attachShadow({mode:'open'});const slot=document.createElement('slot');slot.setAttribute('name','content');root.appendChild(slot);const left=document.createElement('button');left.id='left';left.slot='content';left.style.position='absolute';left.style.left='0px';left.style.top='0px';left.style.width='50px';left.style.height='50px';const right=document.createElement('button');right.id='right';right.slot='content';right.style.position='absolute';right.style.left='60px';right.style.top='0px';right.style.width='50px';right.style.height='50px';for(const type of ['pointerenter','mouseenter','pointerleave','mouseleave']){left.addEventListener(type,(event)=>window.slotInternalEnterLeaveLog.push('left:'+type+':'+(event.relatedTarget?event.relatedTarget.id:'none')));right.addEventListener(type,(event)=>window.slotInternalEnterLeaveLog.push('right:'+type+':'+(event.relatedTarget?event.relatedTarget.id:'none')));host.addEventListener(type,(event)=>window.slotInternalEnterLeaveLog.push('host:'+type+':'+(event.target?event.target.id:'')+':'+(event.relatedTarget?event.relatedTarget.id:'none')));document.addEventListener(type,(event)=>window.slotInternalEnterLeaveLog.push('doc:'+type+':'+(event.target?event.target.id:'')+':'+(event.relatedTarget?event.relatedTarget.id:'none')));}host.appendChild(left);host.appendChild(right);}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerMove\",\"x\":70,\"y\":10}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.slotInternalEnterLeaveLog)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"[\\\"left:pointerenter:none\\\",\\\"left:mouseenter:none\\\",\\\"left:pointerleave:right\\\",\\\"left:mouseleave:right\\\",\\\"right:pointerenter:left\\\",\\\"right:mouseenter:left\\\"]\"",
    ),
  )
}

///|
test "bidi input pointer drag actions emit drag sequence" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='draggable' draggable='true' style='position:absolute;left:0;top:0;width:40px;height:40px'></div><div id='droppable' style='position:absolute;left:60px;top:0;width:40px;height:40px'></div><script>window.allEvents={events:[]}</script>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerMove\",\"x\":70,\"y\":10},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events.filter(e => e.type.indexOf('drag') === 0).map(e => [e.type, e.target || '', e.relatedTarget || '', e.effectAllowed || '', e.dropEffect || '']))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(
    json.contains(
      "\"value\":\"[[\\\"dragstart\\\",\\\"draggable\\\",\\\"droppable\\\",\\\"all\\\",\\\"none\\\"],[\\\"drag\\\",\\\"draggable\\\",\\\"droppable\\\",\\\"all\\\",\\\"none\\\"],[\\\"dragenter\\\",\\\"droppable\\\",\\\"draggable\\\",\\\"all\\\",\\\"none\\\"],[\\\"dragover\\\",\\\"droppable\\\",\\\"draggable\\\",\\\"all\\\",\\\"none\\\"],[\\\"dragend\\\",\\\"draggable\\\",\\\"\\\",\\\"all\\\",\\\"none\\\"]]\"",
    ),
  )
}

///|
test "bidi input pointer drag does not drop when effectAllowed is none" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='draggable' draggable='true' style='position:absolute;left:0;top:0;width:40px;height:40px'></div><div id='droppable' style='position:absolute;left:60px;top:0;width:40px;height:40px'></div><script>window.allEvents={events:[]};const src=document.getElementById('draggable');const dst=document.getElementById('droppable');src.addEventListener('dragstart',e=>{e.dataTransfer.effectAllowed='none';});dst.addEventListener('dragover',e=>{e.preventDefault();e.dataTransfer.dropEffect='move';});</script>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerMove\",\"x\":70,\"y\":10},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events.filter(e => e.type.indexOf('drag') === 0).map(e => [e.type, e.effectAllowed || '', e.dropEffect || '']))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(
    json.contains(
      "\"value\":\"[[\\\"dragstart\\\",\\\"none\\\",\\\"none\\\"],[\\\"drag\\\",\\\"none\\\",\\\"none\\\"],[\\\"dragenter\\\",\\\"none\\\",\\\"none\\\"],[\\\"dragover\\\",\\\"none\\\",\\\"move\\\"],[\\\"dragend\\\",\\\"none\\\",\\\"move\\\"]]\"",
    ),
  )
}

///|
test "bidi input pointer drag does not drop when dropEffect is incompatible" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='draggable' draggable='true' style='position:absolute;left:0;top:0;width:40px;height:40px'></div><div id='droppable' style='position:absolute;left:60px;top:0;width:40px;height:40px'></div><script>window.allEvents={events:[]};const src=document.getElementById('draggable');const dst=document.getElementById('droppable');src.addEventListener('dragstart',e=>{e.dataTransfer.effectAllowed='copy';});dst.addEventListener('dragover',e=>{e.preventDefault();e.dataTransfer.dropEffect='move';});</script>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerMove\",\"x\":70,\"y\":10},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events.filter(e => e.type.indexOf('drag') === 0).map(e => [e.type, e.effectAllowed || '', e.dropEffect || '']))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(
    json.contains(
      "\"value\":\"[[\\\"dragstart\\\",\\\"copy\\\",\\\"none\\\"],[\\\"drag\\\",\\\"copy\\\",\\\"none\\\"],[\\\"dragenter\\\",\\\"copy\\\",\\\"none\\\"],[\\\"dragover\\\",\\\"copy\\\",\\\"move\\\"],[\\\"dragend\\\",\\\"copy\\\",\\\"move\\\"]]\"",
    ),
  )
}

///|
test "bidi input pointerDown can close context without trailing action" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input style='position:absolute;left:0;top:0;width:120px;height:80px' onmousedown='window.close()'>close</input>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0}]}]}}",
  )
  let perform_msgs = proto.take_messages()
  assert_eq(perform_msgs.length(), 1)
  let perform_json = perform_msgs[0].to_json()
  assert_true(perform_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"1\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let evaluate_msgs = proto.take_messages()
  assert_eq(evaluate_msgs.length(), 1)
  let evaluate_json = evaluate_msgs[0].to_json()
  assert_true(evaluate_json.contains("\"type\":\"error\""))
  assert_true(evaluate_json.contains("\"error\":\"no such frame\""))
}

///|
test "bidi script evaluate input.click emits fileDialogOpened event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id=input type=file />\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"input.click()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let result_json = msgs[1].to_json()
  assert_true(event_json.contains("input.fileDialogOpened"))
  assert_true(event_json.contains("\"context\":\"session-1\""))
  assert_true(event_json.contains("\"multiple\":false"))
  assert_true(event_json.contains("\"element\":{\"sharedId\":\"node-"))
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"result\":{\"type\":\"undefined\"}"))
}

///|
test "bidi script evaluate input.click return preserves node result" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id=input type=file multiple />\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"input.click(); input\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let result_json = msgs[1].to_json()
  assert_true(event_json.contains("input.fileDialogOpened"))
  assert_true(event_json.contains("\"multiple\":true"))
  assert_true(event_json.contains("\"element\":{\"sharedId\":\"node-"))
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"result\":{\"type\":\"node\""))
  assert_true(result_json.contains("\"sharedId\":\"node-"))
}

///|
test "bidi script evaluateResult input.click return unwraps node result" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id=input type=file multiple />\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"input.click(); input\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let result_json = msgs[1].to_json()
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"sharedId\":\"node-"))
  assert_false(result_json.contains("\"realm\":"))
}

///|
test "bidi script evaluate showOpenFilePicker emits event without element" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.showOpenFilePicker({'multiple': true})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let result_json = msgs[1].to_json()
  assert_true(event_json.contains("input.fileDialogOpened"))
  assert_true(event_json.contains("\"context\":\"session-1\""))
  assert_true(event_json.contains("\"multiple\":true"))
  assert_false(event_json.contains("\"element\""))
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"result\":{\"type\":\"undefined\"}"))
}

///|
test "bidi script evaluateResult file cancel probe resolves for dismiss handler" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{\"alwaysMatch\":{\"unhandledPromptBehavior\":{\"file\":\"dismiss\"}}}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"new Promise(resolve => { const picker = document.createElement('input'); picker.type = 'file'; picker.addEventListener('cancel', (event) => { resolve(event.isTrusted); }); picker.click(); })\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let result_json = msgs[0].to_json()
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"type\":\"boolean\""))
  assert_true(result_json.contains("\"value\":true"))
}

///|
test "bidi script evaluateResult file cancel probe stays pending for ignore handler" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{\"alwaysMatch\":{\"unhandledPromptBehavior\":{\"file\":\"ignore\"}}}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"new Promise(resolve => { const picker = document.createElement('input'); picker.type = 'file'; picker.addEventListener('cancel', (event) => { resolve(event.isTrusted); }); picker.click(); })\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 0)
}

///|
test "bidi script evaluateResult file cancel probe defaults to ignore" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"new Promise(resolve => { const picker = document.createElement('input'); picker.type = 'file'; picker.addEventListener('cancel', (event) => { resolve(event.isTrusted); }); picker.click(); })\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 0)
}

///|
test "bidi prepareBaselineContextForTest preserves default file prompt behavior" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{\"alwaysMatch\":{\"unhandledPromptBehavior\":\"ignore\"}}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.prepareBaselineContextForTest\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"new Promise(resolve => { const picker = document.createElement('input'); picker.type = 'file'; picker.addEventListener('cancel', (event) => { resolve(event.isTrusted); }); picker.click(); })\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 0)
}

///|
test "bidi input isFileDialogCanceledForTest returns false by default" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.isFileDialogCanceledForTest\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":false"))
}

///|
test "bidi input isFileDialogCanceledForTest returns true for dismiss handler" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{\"alwaysMatch\":{\"unhandledPromptBehavior\":{\"file\":\"dismiss\"}}}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.isFileDialogCanceledForTest\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":true"))
}

///|
test "bidi script evaluate allEvents returns synthetic setFiles events per context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.recordSyntheticEvents\",\"params\":{\"context\":\"session-1\",\"events\":[{\"type\":\"input\",\"files\":[\"noop.txt\"]},{\"type\":\"change\",\"files\":[\"noop.txt\"]}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"string\""))
  assert_true(json.contains("\\\"type\\\":\\\"input\\\""))
  assert_true(json.contains("\\\"type\\\":\\\"change\\\""))
  assert_true(json.contains("\\\"files\\\":[\\\"noop.txt\\\"]"))
}

///|
test "bidi script evaluate allEvents isolates contexts for synthetic setFiles events" {
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
    "{\"id\":3,\"method\":\"input.recordSyntheticEvents\",\"params\":{\"context\":\"session-1\",\"events\":[{\"type\":\"input\",\"files\":[\"noop.txt\"]}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-2\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains("\"result\":{\"type\":\"string\",\"value\":\"[]\"}"),
  )
}

///|
test "bidi script evaluateResult allEvents unwraps to string remote value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.recordSyntheticEvents\",\"params\":{\"context\":\"session-1\",\"events\":[{\"type\":\"input\",\"files\":[\"noop.txt\"]}]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"string\""))
  assert_true(json.contains("\\\"type\\\":\\\"input\\\""))
}

///|
test "bidi input setFiles accepts files alias and derives display name" {
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
    "{\"id\":3,\"method\":\"input.setFiles\",\"params\":{\"context\":\"session-1\",\"element\":{\"type\":\"null\"},\"files\":[\"path/to/noop.txt\"]}}",
  )
  let set_json = proto.take_messages()[0].to_json()
  assert_true(set_json.contains("\"type\":\"success\""))
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let events_json = proto.take_messages()[0].to_json()
  assert_true(events_json.contains("\\\"files\\\":[\\\"noop.txt\\\"]"))
}

///|
test "bidi input setFiles derives display name from windows path" {
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
    "{\"id\":3,\"method\":\"input.setFiles\",\"params\":{\"context\":\"session-1\",\"element\":{\"type\":\"null\"},\"files\":[\"C:\\\\tmp\\\\noop.txt\"]}}",
  )
  let set_json = proto.take_messages()[0].to_json()
  assert_true(set_json.contains("\"type\":\"success\""))
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let events_json = proto.take_messages()[0].to_json()
  assert_true(events_json.contains("\\\"files\\\":[\\\"noop.txt\\\"]"))
}

///|
test "bidi script fetchForTest derives request data from json fields" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addDataCollector\",\"params\":{\"dataTypes\":[\"request\"],\"maxEncodedDataSize\":10000}}",
  )
  let collector_json = proto.take_messages()[0].to_json()
  assert_true(collector_json.contains("\"collector\":\"collector-1\""))
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.fetchForTest\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"POST\",\"headersJson\":\"{\\\"x-test\\\":\\\"ok\\\"}\",\"postDataJson\":\"{\\\"foo\\\":1,\\\"bar\\\":2}\",\"postDataMode\":\"formData\"}}",
  )
  let fetch_msgs = proto.take_messages()
  assert_eq(fetch_msgs.length(), 2)
  let event_json = fetch_msgs[0].to_json()
  let result_json = fetch_msgs[1].to_json()
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(event_json.contains("\"request\":{\"method\":\"POST\""))
  assert_true(event_json.contains("\"name\":\"x-test\""))
  assert_true(event_json.contains("\"value\":\"ok\""))
  assert_true(result_json.contains("\"type\":\"success\""))
  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.getData\",\"params\":{\"request\":\"request-1\",\"dataType\":\"request\",\"collector\":\"collector-1\"}}",
  )
  let data_json = proto.take_messages()[0].to_json()
  assert_true(data_json.contains("\"type\":\"success\""))
  assert_true(data_json.contains("\"value\":\""))
  assert_true(data_json.contains("form-data; name=\\\"foo\\\""))
  assert_true(data_json.contains("form-data; name=\\\"bar\\\""))
}

///|
test "bidi script fetchForTest derives request data from raw fields" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addDataCollector\",\"params\":{\"dataTypes\":[\"request\"],\"maxEncodedDataSize\":10000}}",
  )
  let collector_json = proto.take_messages()[0].to_json()
  assert_true(collector_json.contains("\"collector\":\"collector-1\""))
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.fetchForTest\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"headers\":{\"x-test\":\"ok\"},\"postData\":{\"foo\":1,\"bar\":2}}}",
  )
  let fetch_msgs = proto.take_messages()
  assert_eq(fetch_msgs.length(), 2)
  let event_json = fetch_msgs[0].to_json()
  let result_json = fetch_msgs[1].to_json()
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(event_json.contains("\"request\":{\"method\":\"POST\""))
  assert_true(event_json.contains("\"name\":\"x-test\""))
  assert_true(event_json.contains("\"value\":\"ok\""))
  assert_true(result_json.contains("\"type\":\"success\""))
  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.getData\",\"params\":{\"request\":\"request-1\",\"dataType\":\"request\",\"collector\":\"collector-1\"}}",
  )
  let data_json = proto.take_messages()[0].to_json()
  assert_true(data_json.contains("\"type\":\"success\""))
  assert_true(data_json.contains("\"value\":\""))
  assert_true(data_json.contains("form-data; name=\\\"foo\\\""))
  assert_true(data_json.contains("form-data; name=\\\"bar\\\""))
}

///|
test "bidi script evaluate allEvents normalizes modifier codes and dedupes consecutive entries" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let html = "data:text/html,<script>window.allEvents={events:[{type:'keydown',key:'Shift',code:'',location:1},{type:'keydown',key:'Shift',code:'',location:1},{type:'keydown',key:'Meta',code:'Unidentified',location:2}]}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("ShiftLeft"))
  assert_true(json.contains("MetaRight"))
  assert_false(json.contains("\"code\":\"\""))
  assert_false(
    json.contains(
      "\\\"key\\\":\\\"Shift\\\",\\\"code\\\":\\\"ShiftLeft\\\",\\\"location\\\":1},{\\\"type\\\":\\\"keydown\\\",\\\"key\\\":\\\"Shift\\\",\\\"code\\\":\\\"ShiftLeft\\\",\\\"location\\\":1",
    ),
  )
}

///|
test "bidi input pointerDown close reports error when actions continue" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input style='position:absolute;left:0;top:0;width:120px;height:80px' onmousedown='window.close()'>close</input>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"no such frame\""))
}

///|
test "V8: simple expression" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(0, dom, "return 1 + 2", @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "3")
}

///|
test "V8: console.log capture" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "console.log('hello'); return 42",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "42")
  assert_eq(result.logs.length(), 1)
  assert_eq(result.logs[0], "hello")
}

///|
test "V8: error handling" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(0, dom, "throw new Error('oops')", @js.ImmediateFlush)
  assert_false(result.success)
  assert_true(result.value.contains("oops"))
}

///|
test "V8: undefined return" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(0, dom, "let x = 1;", @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "undefined")
}

///|
test "V8: multiple executions share state" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let _ = rt.execute(0, dom, "globalThis.__counter = 1;", @js.ImmediateFlush)
  let result = rt.execute(
    0,
    dom,
    "return globalThis.__counter + 1",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "2")
}

///|
test "V8: JsContext integration" {
  let rt = V8JsRuntime::new()
  let dom = @dom.DomTree::new()
  let ctx = @js.JsContext::new_with_runtime(dom, rt.as_js_runtime())
  let result = ctx.execute("return 'hello from v8'")
  assert_true(result.success)
  assert_eq(result.value, "hello from v8")
}

// ============================================================
// Mock DOM tests
// ============================================================

///|
test "V8+DOM: document.createElement" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const div = document.createElement('div'); return div.tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "DIV")
}

///|
test "V8+DOM: setAttribute and getAttribute" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const el = document.createElement('span'); el.setAttribute('class', 'test'); return el.getAttribute('class')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "test")
}

///|
test "V8+DOM: appendChild and getElementById" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const div = document.createElement('div'); div.id = 'myDiv'; document.body.appendChild(div); return document.getElementById('myDiv').tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "DIV")
}

///|
test "V8+DOM: textContent" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const p = document.createElement('p'); p.textContent = 'Hello'; document.body.appendChild(p); return document.body.textContent",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "Hello")
}

///|
test "V8+DOM: addEventListener and click" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "let clicked = false; const btn = document.createElement('button'); btn.addEventListener('click', () => { clicked = true; }); btn.click(); return clicked",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true")
}

///|
test "V8+DOM: form.requestSubmit dispatches SubmitEvent with submitter" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    (
      #|document.body.innerHTML = '<form id="form"><button id="btn" type="submit">Go</button></form>';
      #|const form = document.getElementById('form');
      #|const button = document.getElementById('btn');
      #|let seen = '';
      #|form.addEventListener('submit', (event) => {
      #|  seen = [
      #|    typeof SubmitEvent === 'function',
      #|    event instanceof SubmitEvent,
      #|    event.submitter === button,
      #|    event.target === form
      #|  ].join(',');
      #|  event.preventDefault();
      #|});
      #|form.requestSubmit(button);
      #|return seen
    ),
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,true,true,true")
}

///|
test "V8+DOM: form.requestSubmit validates required controls and honors formnovalidate" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    (
      #|document.body.innerHTML = `
      #|  <form id="form">
      #|    <input id="field" required>
      #|    <button id="submitter" type="submit">Go</button>
      #|    <button id="skip" type="submit" formnovalidate>Skip</button>
      #|  </form>`;
      #|const form = document.getElementById('form');
      #|const field = document.getElementById('field');
      #|const submitter = document.getElementById('submitter');
      #|const skip = document.getElementById('skip');
      #|let submitCount = 0;
      #|let invalidCount = 0;
      #|field.addEventListener('invalid', () => { invalidCount += 1; });
      #|form.addEventListener('submit', (event) => {
      #|  submitCount += 1;
      #|  event.preventDefault();
      #|});
      #|form.requestSubmit(submitter);
      #|const blocked = [submitCount, invalidCount, field.validity.valueMissing, field.validationMessage.length > 0].join(',');
      #|form.requestSubmit(skip);
      #|return blocked + '|' + [submitCount, invalidCount].join(',')
    ),
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "0,1,true,true|1,1")
}

///|
test "V8+DOM: form.submit bypasses submit event" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    (
      #|document.body.innerHTML = '<form id="form"><input id="field" required><button id="btn" type="submit">Go</button></form>';
      #|const form = document.getElementById('form');
      #|const field = document.getElementById('field');
      #|let submitCount = 0;
      #|let invalidCount = 0;
      #|form.addEventListener('submit', () => {
      #|  submitCount += 1;
      #|});
      #|field.addEventListener('invalid', () => {
      #|  invalidCount += 1;
      #|});
      #|const value = form.submit();
      #|return [typeof form.submit === 'function', value === undefined, submitCount, invalidCount].join(',')
    ),
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,true,0,0")
}

///|
test "V8+DOM: click on reset button dispatches reset and restores controls" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    (
      #|document.body.innerHTML = '<form id="form"><input id="field" value="seed"><input id="check" type="checkbox" checked><button id="reset" type="reset">Reset</button></form>';
      #|const form = document.getElementById('form');
      #|const field = document.getElementById('field');
      #|const check = document.getElementById('check');
      #|const button = document.getElementById('reset');
      #|let resetCount = 0;
      #|form.addEventListener('reset', () => {
      #|  resetCount += 1;
      #|});
      #|field.value = 'edited';
      #|check.checked = false;
      #|button.click();
      #|return [resetCount, field.value, check.checked].join(',')
    ),
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "1,seed,true")
}

///|
test "V8+DOM: Promise ordering" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  // Use globalThis to capture async results since return is synchronous
  let result = rt.execute(
    0,
    dom,
    "globalThis.__order = []; globalThis.__order.push('sync'); Promise.resolve().then(() => globalThis.__order.push('promise')); globalThis.__order.push('end');",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  // Now read the final order after microtask checkpoint
  let check = rt.execute(
    0,
    dom,
    "return globalThis.__order.join(',')",
    @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "sync,end,promise")
}

///|
test "V8+DOM: setTimeout ordering" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__order2 = []; globalThis.__order2.push('sync'); setTimeout(() => globalThis.__order2.push('timeout'), 0); Promise.resolve().then(() => globalThis.__order2.push('promise')); globalThis.__order2.push('end');",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0,
    dom,
    "return globalThis.__order2.join(',')",
    @js.DeferredFlush,
  )
  assert_true(check.success)
  // sync → end → promise (microtask) → timeout (task)
  assert_eq(check.value, "sync,end,promise,timeout")
}

// ============================================================
// Full mock DOM tests
// ============================================================

///|
test "V8+FullDOM: document.createElement with full mock" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const div = document.createElement('div'); div.setAttribute('id', 'test'); document.body.appendChild(div); return document.getElementById('test').tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "DIV")
}

///|
test "V8+FullDOM: innerHTML and outerHTML" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const div = document.createElement('div'); div.textContent = 'hello'; return div.outerHTML",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_true(result.value.contains("hello"))
}

///|
test "V8+FullDOM: classList manipulation" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const el = document.createElement('div'); el.classList.add('a', 'b'); el.classList.remove('a'); return el.classList.contains('b') + ',' + el.classList.contains('a')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,false")
}

///|
test "V8+FullDOM: querySelector and querySelectorAll" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const d1 = document.createElement('div'); d1.classList.add('item'); const d2 = document.createElement('div'); d2.classList.add('item'); document.body.appendChild(d1); document.body.appendChild(d2); return document.querySelectorAll('.item').length",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "2")
}

///|
test "V8+FullDOM: Event dispatch" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  // Test basic addEventListener + dispatchEvent (not click bubbling which depends on full impl)
  let result = rt.execute(
    0,
    dom,
    "globalThis.__clicked = false; const btn = document.createElement('button'); btn.addEventListener('click', () => { globalThis.__clicked = true; }); btn.dispatchEvent(new Event('click'));",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0,
    dom,
    "return String(globalThis.__clicked)",
    @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "true")
}

///|
test "V8+FullDOM: click bubbles to ancestor listeners" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let code =
    #|globalThis.__clickedOrder = [];
    #|const outer = document.createElement('div');
    #|const inner = document.createElement('button');
    #|outer.addEventListener('click', () => globalThis.__clickedOrder.push('outer'));
    #|inner.addEventListener('click', () => globalThis.__clickedOrder.push('inner'));
    #|outer.appendChild(inner);
    #|document.body.appendChild(outer);
    #|inner.click();
  let result = rt.execute(0, dom, code, @js.ImmediateFlush)
  assert_true(result.success)
  let check = rt.execute(
    0,
    dom,
    "return globalThis.__clickedOrder.join(',')",
    @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "inner,outer")
}

///|
test "V8+FullDOM: Promise.resolve chain" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  // V8 native Promises: test in single execute with globalThis capture
  let result = rt.execute(
    0,
    dom,
    "globalThis.__pResult2 = 'pending'; Promise.resolve('a').then(v => v + 'b').then(v => { globalThis.__pResult2 = v; });",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  // After ImmediateFlush, microtask checkpoint has run, so __pResult2 should be set
  // Read it back in a separate eval to confirm
  let check = rt.execute(
    0,
    dom,
    "return globalThis.__pResult2",
    @js.ImmediateFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "ab")
}

///|
test "V8+FullDOM: setTimeout with nested setTimeout" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__timerOrder = []; setTimeout(() => { globalThis.__timerOrder.push('first'); setTimeout(() => globalThis.__timerOrder.push('nested'), 0); }, 0);",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0,
    dom,
    "return globalThis.__timerOrder.join(',')",
    @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "first,nested")
}

///|
test "V8+FullDOM: attachShadow closed mode tracks metadata and clonable serialization" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|const host = document.createElement('div');
    #|const shadow = host.attachShadow({
    #|  mode: 'closed',
    #|  delegatesFocus: true,
    #|  clonable: true,
    #|  serializable: true,
    #|  slotAssignment: 'manual'
    #|});
    #|shadow.innerHTML = '<span id="inner">shadow-text</span>';
    #|const clone = host.cloneNode(true);
    #|return JSON.stringify([
    #|  host.shadowRoot === null,
    #|  shadow.mode,
    #|  shadow.delegatesFocus === true,
    #|  shadow.clonable === true,
    #|  shadow.serializable === true,
    #|  shadow.slotAssignment === 'manual',
    #|  shadow.getHTML().indexOf('shadow-text') >= 0,
    #|  clone.getHTML({ serializableShadowRoots: true }).indexOf('shadowrootmode="closed"') >= 0,
    #|  clone.getHTML({ serializableShadowRoots: true }).indexOf('shadow-text') >= 0
    #|]);
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(
    result.value,
    "[true,\"closed\",true,true,true,true,true,true,true]",
  )
}

///|
test "V8+FullDOM: setHTMLUnsafe parses declarative shadow DOM" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|const host = document.createElement('div');
    #|host.setHTMLUnsafe('<template shadowrootmode="open" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable><button id="inner">shadow-text</button></template><span id="light">light-text</span>');
    #|return JSON.stringify([
    #|  host.shadowRoot !== null,
    #|  host.shadowRoot && host.shadowRoot.getElementById('inner') !== null,
    #|  host.querySelector('template') === null,
    #|  host.querySelector('#light') !== null,
    #|  host.shadowRoot && host.shadowRoot.delegatesFocus === true,
    #|  host.shadowRoot && host.shadowRoot.clonable === true,
    #|  host.shadowRoot && host.shadowRoot.serializable === true,
    #|  host.getHTML({ serializableShadowRoots: true }).indexOf('shadowrootmode="open"') >= 0
    #|]);
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "[true,true,true,true,true,true,true,true]")
}

///|
test "V8+FullDOM: attachInternals exposes CustomStateSet on custom element names" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|const panel = document.createElement('x-panel');
    #|panel.id = 'panel';
    #|document.body.appendChild(panel);
    #|const internals = panel.attachInternals();
    #|const states = internals.states;
    #|states.add('open');
    #|let invalidName = '';
    #|try {
    #|  document.createElement('div').attachInternals();
    #|} catch (e) {
    #|  invalidName = e.name;
    #|}
    #|let duplicateName = '';
    #|try {
    #|  panel.attachInternals();
    #|} catch (e) {
    #|  duplicateName = e.name;
    #|}
    #|return JSON.stringify([
    #|  internals.states === states,
    #|  states instanceof CustomStateSet,
    #|  states.has('open'),
    #|  panel.__customStates instanceof Set && panel.__customStates.has('open'),
    #|  invalidName,
    #|  duplicateName
    #|]);
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(
    result.value,
    "[true,true,true,true,\"NotSupportedError\",\"NotSupportedError\"]",
  )
}

///|
test "V8+FullDOM: :state() matches and querySelector reflect CustomStateSet changes" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|const panel = document.createElement('x-panel');
    #|document.body.appendChild(panel);
    #|const internals = panel.attachInternals();
    #|internals.states.add('open');
    #|const beforeDelete = JSON.stringify([
    #|  panel.matches(':state(open)'),
    #|  !panel.matches(':state(closed)'),
    #|  document.querySelector(':state(open)') === panel,
    #|  document.querySelector('x-panel:state(open)') === panel,
    #|  document.querySelectorAll(':state(open)').length
    #|]);
    #|internals.states.delete('open');
    #|const afterDelete = JSON.stringify([
    #|  !panel.matches(':state(open)'),
    #|  document.querySelector(':state(open)') === null,
    #|  document.querySelectorAll(':state(open)').length
    #|]);
    #|return beforeDelete + '|' + afterDelete;
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "[true,true,true,true,1]|[true,true,0]")
}

// ============================================================
// Basic tests (no mock DOM)
// ============================================================

///|
test "V8: multiple console.log" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "console.log('a'); console.log('b'); console.warn('w'); return 'ok'",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.logs.length(), 3)
  assert_eq(result.logs[0], "a")
  assert_eq(result.logs[1], "b")
  assert_eq(result.logs[2], "[WARN] w")
}

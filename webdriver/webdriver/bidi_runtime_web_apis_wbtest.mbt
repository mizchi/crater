///|
/// Runtime web API shim coverage — locks the behaviour of localStorage,
/// sessionStorage, history.pushState/replaceState/back, IntersectionObserver,
/// and ResizeObserver in the BiDi JS realm. These shims are the surface
/// modern SPA frontends (Preact / React / Lit) expect to be present at
/// page load; the tests pin the shape so a regression in the shim setup
/// can't silently re-stub them into uselessness.
///
/// Helper notes:
///
/// 1. `read_global_string` returns the raw BiDi response JSON, which
///    JSON-encodes the value (inner `"` -> `\"`). Tests therefore read one
///    scalar at a time rather than stringifying an object — comparing
///    `\"id\":42` against `"id":42` via String::contains doesn't match
///    because of the escape backslash.
///
/// 2. The init block in bidi_runtime_eval.mbt is guarded by
///    `if (!globalThis.document)`, so it runs ONCE per JS realm. Multiple
///    tests in the same `moon test` invocation share `globalThis.history`,
///    `globalThis.localStorage`, etc. Tests must not assume "fresh" state
///    on entry — they reset what they need, or assert deltas (e.g. for
///    history.length) rather than absolute values.

///|
test "localStorage round-trips a string value" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "localStorage.clear(); localStorage.setItem('k', 'v'); globalThis.__lsRead = localStorage.getItem('k');",
  )
  let resp = read_global_string(proto, 3, "__lsRead")
  assert_true(resp.contains("\"v\""))
}

///|
test "localStorage coerces non-string values to DOMString" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "localStorage.clear(); localStorage.setItem('n', 42); globalThis.__lsRead = localStorage.getItem('n');",
  )
  let resp = read_global_string(proto, 3, "__lsRead")
  // Per spec, the stored value is the string "42", not the number 42.
  assert_true(resp.contains("\"42\""))
}

///|
test "localStorage.getItem returns null for missing keys, including empty-string values" {
  let proto = make_proto_with_session()
  // The previous stub `this._data[key] || null` would mis-return null for
  // an explicitly stored empty string. Lock the corrected behaviour: empty
  // string is preserved, missing key returns null.
  run_sync_in_context(
    proto, 2, "localStorage.clear(); localStorage.setItem('empty', ''); globalThis.__lsEmpty = localStorage.getItem('empty'); globalThis.__lsMissing = String(localStorage.getItem('not-set'));",
  )
  let empty = read_global_string(proto, 3, "__lsEmpty")
  assert_true(empty.contains("\"\""))
  let missing = read_global_string(proto, 4, "__lsMissing")
  // Stringifying null gives the literal "null" the response surfaces.
  assert_true(missing.contains("\"null\""))
}

///|
test "localStorage length and key(n) reflect insertion order" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "localStorage.clear(); localStorage.setItem('a','1'); localStorage.setItem('b','2'); localStorage.setItem('c','3'); globalThis.__lsLen = String(localStorage.length); globalThis.__lsKey0 = localStorage.key(0); globalThis.__lsKey2 = localStorage.key(2); globalThis.__lsKeyOob = String(localStorage.key(99));",
  )
  let len = read_global_string(proto, 3, "__lsLen")
  assert_true(len.contains("\"3\""))
  let key0 = read_global_string(proto, 4, "__lsKey0")
  assert_true(key0.contains("\"a\""))
  let key2 = read_global_string(proto, 5, "__lsKey2")
  assert_true(key2.contains("\"c\""))
  let oob = read_global_string(proto, 6, "__lsKeyOob")
  // Out-of-bounds index returns null, not the empty string the old stub
  // would produce via `[] || null` on undefined.
  assert_true(oob.contains("\"null\""))
}

///|
test "sessionStorage is a separate store from localStorage" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "localStorage.clear(); sessionStorage.clear(); localStorage.setItem('shared','from-local'); sessionStorage.setItem('shared','from-session'); globalThis.__l = localStorage.getItem('shared'); globalThis.__s = sessionStorage.getItem('shared');",
  )
  let l = read_global_string(proto, 3, "__l")
  assert_true(l.contains("\"from-local\""))
  let s = read_global_string(proto, 4, "__s")
  assert_true(s.contains("\"from-session\""))
}

///|
test "history.pushState updates location.pathname and globalThis.__pageUrl" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.location.href = 'https://example.com/start'; globalThis.__pageUrl = 'https://example.com/start'; history.pushState({ id: 42 }, '', '/new-route?q=1'); globalThis.__path = String(globalThis.location.pathname); globalThis.__search = String(globalThis.location.search); globalThis.__pageUrl2 = String(globalThis.__pageUrl); globalThis.__stateId = String(history.state.id);",
  )
  let pathname = read_global_string(proto, 3, "__path")
  assert_true(pathname.contains("/new-route"))
  let search = read_global_string(proto, 4, "__search")
  assert_true(search.contains("?q=1"))
  let page_url = read_global_string(proto, 5, "__pageUrl2")
  assert_true(page_url.contains("/new-route"))
  let state_id = read_global_string(proto, 6, "__stateId")
  // Reading the scalar id avoids JSON.stringify's quote-escape problem
  // when comparing through the BiDi response wrapper.
  assert_true(state_id.contains("\"42\""))
}

///|
test "history.replaceState updates location without growing the stack" {
  let proto = make_proto_with_session()
  // Assert that the stack length is UNCHANGED by replaceState, regardless
  // of the absolute starting length (which leaks across tests inside a
  // single moon test invocation — see header note 2).
  run_sync_in_context(
    proto, 2, "globalThis.location.href = 'https://example.com/a'; globalThis.__pageUrl = 'https://example.com/a'; const before = history.length; history.replaceState({ r: 1 }, '', '/replaced'); globalThis.__lenDelta = String(history.length - before); globalThis.__path = String(globalThis.location.pathname);",
  )
  let delta = read_global_string(proto, 3, "__lenDelta")
  // replaceState must NOT push a new entry (spec) — delta should be 0.
  assert_true(delta.contains("\"0\""))
  let path_after = read_global_string(proto, 4, "__path")
  assert_true(path_after.contains("/replaced"))
}

///|
async test "history.back() fires popstate with the previous state" {
  let proto = make_proto_with_session()
  // The listener-registration global is per-realm and persists across
  // evaluates; previous tests may have left stale popstate listeners. We
  // attach our own and check that AT LEAST ONE dispatch matched the state
  // we pushed — order-independent.
  run_sync_in_context(
    proto, 2, "globalThis.location.href = 'https://example.com/'; globalThis.__pageUrl = 'https://example.com/'; globalThis.__popMarker = '<none>'; const stepListener = (ev) => { if (ev && ev.state && ev.state.step) globalThis.__popMarker = String(ev.state.step); }; globalThis.addEventListener('popstate', stepListener); history.pushState({ step: 'one' }, '', '/one'); history.pushState({ step: 'two' }, '', '/two'); history.back(); globalThis.removeEventListener && globalThis.removeEventListener('popstate', stepListener);",
  )
  @async.sleep(10)
  let resp = read_global_string(proto, 4, "__popMarker")
  // back() lands on the most-recently-pushed prior entry with state {step:'one'}.
  assert_true(resp.contains("\"one\""))
}

///|
async test "IntersectionObserver fires the callback once after observe" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__ioRatio = '-1'; globalThis.__ioTarget = '<none>'; const target = { id: 't', getBoundingClientRect: () => ({ x: 0, y: 0, width: 10, height: 20, top: 0, left: 0, right: 10, bottom: 20 }) }; const io = new IntersectionObserver((entries) => { globalThis.__ioRatio = String(entries[0].intersectionRatio); globalThis.__ioTarget = String(entries[0].target.id); }); io.observe(target);",
  )
  @async.sleep(10)
  let ratio = read_global_string(proto, 3, "__ioRatio")
  assert_true(ratio.contains("\"1\""))
  let target = read_global_string(proto, 4, "__ioTarget")
  assert_true(target.contains("\"t\""))
}

///|
async test "IntersectionObserver re-observes after unobserve" {
  let proto = make_proto_with_session()
  // unobserve() drops the target from the observer's set. A subsequent
  // observe() of the same target is treated as a fresh observation and
  // fires the callback again. Counter is read back as a string-coerced
  // numeric global.
  run_sync_in_context(
    proto, 2, "globalThis.__ioCount = 0; const target = { id: 'd', getBoundingClientRect: () => ({ x: 0, y: 0, width: 1, height: 1, top: 0, left: 0, right: 1, bottom: 1 }) }; const io = new IntersectionObserver(() => { globalThis.__ioCount = globalThis.__ioCount + 1; }); io.observe(target); io.unobserve(target); io.observe(target);",
  )
  @async.sleep(10)
  run_sync_in_context(
    proto, 3, "globalThis.__ioReport = String(globalThis.__ioCount);",
  )
  let resp = read_global_string(proto, 4, "__ioReport")
  // Two observe() calls with unobserve() in between → both fire. Net: 2.
  assert_true(resp.contains("\"2\""))
}

///|
async test "ResizeObserver fires callback once with target's bounding rect" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__roWidth = '-1'; globalThis.__roInline = '-1'; const target = { id: 'r', getBoundingClientRect: () => ({ x: 0, y: 0, width: 200, height: 50, top: 0, left: 0, right: 200, bottom: 50 }) }; const ro = new ResizeObserver((entries) => { globalThis.__roWidth = String(entries[0].contentRect.width); globalThis.__roInline = String(entries[0].borderBoxSize[0].inlineSize); }); ro.observe(target);",
  )
  @async.sleep(10)
  let width = read_global_string(proto, 3, "__roWidth")
  assert_true(width.contains("\"200\""))
  let inline_size = read_global_string(proto, 4, "__roInline")
  assert_true(inline_size.contains("\"200\""))
}

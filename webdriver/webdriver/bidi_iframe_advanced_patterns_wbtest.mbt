///|
/// Advanced iframe insertion patterns — DocumentFragment, async fences,
/// and cross-frame DOM access (#182 slice 4).
///
/// Slice 3 broadened the synthetic matcher to accept arbitrary variable
/// names and several src forms. This slice covers the next tier of
/// patterns real apps use:
///
/// - DocumentFragment-mediated insertion (append-to-fragment then
///   append-fragment-to-document)
/// - Async iframe insertion (the synthetic handler matches on the
///   surface expression text, so an `await` fence followed by iframe
///   creation in the same script body still registers a child context)
/// - Cross-frame DOM mirror still works for the literal WPT shape
///   (`window.baz = iframe.contentWindow.foo`)
///
/// Tests pin what works AFTER slices 1-3. Remaining gaps under #182:
///
/// - Truly async iframe creation across separate script.evaluate calls
///   (await in JS, then a separate evaluate that inserts) — the
///   second evaluate's synthetic handler may not see the iframe
///   creation context
/// - Cross-frame `iframe.contentWindow.foo` mirror with variable
///   names OTHER than the hardcoded WPT one-liner

///|
fn adv_proto() -> BidiProtocol {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
fn adv_eval(proto : BidiProtocol, request_id : Int, expr : String) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
test "DocumentFragment-mediated iframe insertion registers a child" {
  let proto = adv_proto()
  // Page builds an iframe inside a DocumentFragment, then appends the
  // fragment to document.body. Both appendChild calls are on
  // non-iframe receivers; what makes this work is that the matcher
  // gates on `createElement('iframe')` AND any appendChild, regardless
  // of receiver. The DOM walk in refresh_child_contexts_from_iframes
  // picks the iframe up once it's in the document.
  adv_eval(
    proto, 2, "const frag = document.createDocumentFragment(); const iframe = document.createElement('iframe'); iframe.src='/frag'; frag.appendChild(iframe); document.body.appendChild(frag);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "async iframe insertion in IIFE body still registers a child" {
  let proto = adv_proto()
  // An async IIFE that awaits a Promise before inserting the iframe.
  // The synthetic handler runs at script.evaluate time and pattern-
  // matches the expression source text — it doesn't trace control
  // flow. As long as the source mentions createElement('iframe')
  // AND any appendChild verb, the child context registers immediately.
  // (The async insertion completes later, but the context is already
  // present in the tree.)
  adv_eval(
    proto, 2, "(async () => { await new Promise(r => setTimeout(r, 0)); const iframe = document.createElement('iframe'); iframe.src='/async-frame'; document.body.appendChild(iframe); })();",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "Promise.then iframe insertion registers a child" {
  let proto = adv_proto()
  // .then() callback variant — same source-text gating principle.
  adv_eval(
    proto, 2, "Promise.resolve().then(() => { const iframe = document.createElement('iframe'); iframe.src='/then-frame'; document.body.appendChild(iframe); });",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "queueMicrotask iframe insertion registers a child" {
  let proto = adv_proto()
  adv_eval(
    proto, 2, "queueMicrotask(() => { const iframe = document.createElement('iframe'); iframe.src='/microtask-frame'; document.body.appendChild(iframe); });",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "fragment + setAttribute src combination registers a child" {
  let proto = adv_proto()
  // Combination: fragment-mediated + setAttribute src — both wider
  // patterns simultaneously. Pins the orthogonality of the two
  // detection broadenings from slices 3 and 4.
  adv_eval(
    proto, 2, "const frag = document.createDocumentFragment(); const f = document.createElement('iframe'); f.setAttribute('src', '/combined'); frag.appendChild(f); document.body.appendChild(frag);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

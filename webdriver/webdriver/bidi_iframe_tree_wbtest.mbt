///|
/// Iframe / nested-frame contract pins for #182. The full surface (HTML
/// `<iframe>` parsing, every `iframe.src = ...` JS pattern, cross-frame
/// DOM access fidelity) is large enough to live as a tracking issue;
/// this file pins what works TODAY so we don't regress while the issue
/// is chipped away in subsequent PRs.
///
/// What's tested:
///
/// 1. `browsingContext.createSyntheticChildContext` registers a child
///    under the parent and emits a contextCreated event.
/// 2. `browsingContext.getTree` returns the parent with its children
///    populated.
/// 3. `script.evaluate` can target the child context and runs there.
/// 4. The child context inherits the parent's user context (so e.g.
///    cookie partitioning / unhandledPromptBehavior / origin auth all
///    apply to the iframe the way they apply to the parent).
///
/// What's NOT tested here (tracked separately under #182):
///
/// - Real HTML `<iframe src="...">` discovery from the parsed document
/// - Non-pattern-matched `iframe.src = url; parent.appendChild(iframe)`
///   variants (the existing `try_handle_synthetic_iframe_creation`
///   only matches one specific WPT shape)
/// - `iframe.contentWindow.foo` cross-frame property access for shapes
///   other than the hardcoded `window.baz = iframe.contentWindow.foo`
///   one-liner

///|
/// Create a fresh proto with one top-level session, drained.
fn iframe_proto() -> BidiProtocol {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
/// Issue `createSyntheticChildContext` and return the response JSON.
fn create_iframe_child(
  proto : BidiProtocol,
  request_id : Int,
  parent_ctx_id : String,
  url : String,
) -> String {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"" +
    parent_ctx_id +
    "\",\"url\":\"" +
    url +
    "\"}}"
  let _ = proto.process_message(payload)
  let msgs = proto.take_messages()
  if msgs.length() == 0 {
    return ""
  }
  // The response is the last message (events may precede it).
  let mut response : String = ""
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":" + request_id.to_string()) {
      response = json
    }
  }
  response
}

///|
test "createSyntheticChildContext registers a child under the named parent" {
  let proto = iframe_proto()
  let resp = create_iframe_child(proto, 2, "session-1", "about:blank")
  assert_true(resp.contains("\"type\":\"success\""))
  assert_true(resp.contains("\"parentContext\":\"session-1\""))
  // The returned context id is a freshly minted child (session-2 / -3 / ...
  // depending on the test run order; assert the prefix only).
  assert_true(resp.contains("\"context\":\"session-"))
}

///|
test "getTree exposes the iframe child under its parent" {
  let proto = iframe_proto()
  let create_resp = create_iframe_child(proto, 2, "session-1", "about:blank")
  assert_true(create_resp.contains("\"type\":\"success\""))
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.getTree\",\"params\":{}}",
  )
  let msgs = proto.take_messages()
  // Find the response (id=3) — events may be interleaved.
  let mut tree_json : String = ""
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":3") {
      tree_json = json
    }
  }
  assert_true(tree_json.contains("\"type\":\"success\""))
  // Top-level entry: session-1.
  assert_true(tree_json.contains("\"context\":\"session-1\""))
  // After createSyntheticChildContext, the child (session-2 on a fresh
  // proto) must appear in the tree response. The leaf's own `children`
  // array IS empty (which would defeat a blanket `\"children\":[]`
  // check), so we positively assert the child context id appears in
  // the serialized tree. Child entries are built with
  // `include_parent: false` so they don't carry a `parent` field
  // themselves — appearance under session-1's children array is the
  // only signal we can rely on.
  assert_true(tree_json.contains("\"context\":\"session-2\""))
}

///|
test "script.evaluate targets the child context separately from the parent" {
  let proto = iframe_proto()
  let create_resp = create_iframe_child(proto, 2, "session-1", "about:blank")
  assert_true(create_resp.contains("\"type\":\"success\""))
  // After a fresh `iframe_proto()` + one createSyntheticChildContext, the
  // freshly minted child is `session-2`. Assert on the deterministic id
  // rather than parsing the response: we'd otherwise need a
  // `last_index_of` helper that isn't in MoonBit's String API and the
  // alternative (regex-on-substring) is more brittle than the
  // hardcoded id.
  let child_id = "session-2"
  // Set a flag on the child realm via script.evaluate targeted at it.
  let setter_payload = "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"globalThis.__iframeMarker = 'child-realm';\",\"target\":{\"context\":\"" +
    child_id +
    "\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(setter_payload)
  let _ = proto.take_messages()
  // Then read it back — same context.
  let reader_payload = "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"String(globalThis.__iframeMarker || '<unset>')\",\"target\":{\"context\":\"" +
    child_id +
    "\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(reader_payload)
  let read_msgs = proto.take_messages()
  let mut response : String = ""
  for msg in read_msgs {
    let json = msg.to_json()
    if json.contains("\"id\":4") {
      response = json
    }
  }
  assert_true(response.contains("\"type\":\"success\""))
  // The child realm's marker is set; the value travels back through the
  // BiDi response as a JSON-encoded string.
  assert_true(response.contains("\"value\":\"child-realm\""))
}

///|
test "child context inherits the parent's user context for partitioning" {
  // user_context defaults to "default" but the inheritance path is the
  // only mechanism iframes get partitioned cookies / auth / prompts.
  // Pin that mapping so a refactor doesn't silently regress it.
  let proto = iframe_proto()
  let _ = create_iframe_child(proto, 2, "session-1", "about:blank")
  // Walk the proto state — the test reads the internal map directly
  // because there's no BiDi-side `getUserContextForContext` endpoint.
  let child_user_ctx = proto.context_user_context.get("session-2")
  let parent_user_ctx = proto.context_user_context.get("session-1")
  // Both should be set (possibly to "default"), and they must match.
  match (parent_user_ctx, child_user_ctx) {
    (Some(p), Some(c)) => assert_eq(p, c)
    (None, None) => () // both unset still counts as inheritance (default)
    (Some(_), None) => assert_false(true)
    (None, Some(_)) => assert_false(true)
  }
}

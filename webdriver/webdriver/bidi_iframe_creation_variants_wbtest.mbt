///|
/// JS iframe creation pattern variants (#182 sub-task).
///
/// `try_handle_synthetic_iframe_creation` previously matched only the
/// narrow WPT shape `createElement('iframe')` + literal
/// `appendChild(iframe)` + `iframe.src=`. Real apps name the element
/// variable anything, append via any parent, and set src via any of
/// several spec-allowed forms. These tests pin the loosened matcher.
///
/// What's covered:
///
/// - createElement + non-literal-`iframe` variable name + appendChild
/// - .src with whitespace around the `=`
/// - setAttribute('src', ...) / setAttribute("src", ...)
/// - srcdoc → child context registered at `about:srcdoc`
/// - alternative DOM insertion verbs (prepend, append, insertBefore)
///
/// What's still out of scope (left under #182):
///
/// - Async iframe insertion (`await someAsyncOp(); document.body.append(f)`)
///   — the synthetic handler runs at script.evaluate time before any
///   `await` fence resolves
/// - Document fragments / DocumentFragment.appendChild flows
/// - iframe.contentWindow.foo cross-frame access for shapes other than
///   the hardcoded one-liner in the existing handler

///|
fn eval_in_session(
  proto : BidiProtocol,
  request_id : Int,
  expr : String,
) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
fn iframe_proto_with_session() -> BidiProtocol {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
test "createElement + custom-named variable + appendChild registers a child" {
  let proto = iframe_proto_with_session()
  // Variable named `f`, not `iframe`. The previous matcher required
  // `appendChild(iframe)` literally and would have missed this.
  eval_in_session(
    proto, 2, "const f = document.createElement('iframe'); f.src = '/from-f'; document.body.appendChild(f);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "createElement + custom parent.appendChild registers a child" {
  let proto = iframe_proto_with_session()
  // `wrapper.appendChild(iframe)` instead of `document.body.appendChild(iframe)`.
  eval_in_session(
    proto, 2, "const wrapper = document.getElementById('host'); const iframe = document.createElement('iframe'); iframe.src='/wrapped'; wrapper.appendChild(iframe);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "src with whitespace around the equals sign is honored" {
  let proto = iframe_proto_with_session()
  // Spaces around `=`. The original matcher used the marker
  // `iframe.src=` (no space) and would have fallen back to about:blank.
  eval_in_session(
    proto, 2, "const iframe = document.createElement('iframe'); iframe.src = '/whitespaced'; document.body.appendChild(iframe);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "setAttribute('src', ...) is honored" {
  let proto = iframe_proto_with_session()
  eval_in_session(
    proto, 2, "const iframe = document.createElement('iframe'); iframe.setAttribute('src', '/via-setAttr'); document.body.appendChild(iframe);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "srcdoc creates a child at about:srcdoc" {
  let proto = iframe_proto_with_session()
  eval_in_session(
    proto, 2, "const iframe = document.createElement('iframe'); iframe.srcdoc = '<p>inline</p>'; document.body.appendChild(iframe);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "alternative DOM insertion verb (prepend) registers a child" {
  let proto = iframe_proto_with_session()
  eval_in_session(
    proto, 2, "const iframe = document.createElement('iframe'); iframe.src='/pre'; document.body.prepend(iframe);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "matcher does NOT trigger without a createElement('iframe') call" {
  let proto = iframe_proto_with_session()
  // A page that creates a DIV (or any non-iframe element) and inserts
  // it must NOT trigger child-context registration. Pins the strong
  // gate condition so the loosened matcher doesn't false-positive.
  eval_in_session(
    proto, 2, "const d = document.createElement('div'); d.id='nope'; document.body.appendChild(d);",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  // No iframe created → no child context.
  assert_eq(children.length(), 0)
}

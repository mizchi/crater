///|
/// HTML <iframe> discovery during navigation (#182 sub-task).
///
/// When a page's parsed HTML contains `<iframe src="...">`, the
/// navigation commit path (apply_navigation_commit_state →
/// refresh_child_contexts_from_iframes) walks the DOM and registers
/// a child browsing context for each iframe element. These tests
/// verify that flow end-to-end through `browsingContext.navigate`,
/// not just the `createSyntheticChildContext` shortcut covered by
/// `bidi_iframe_tree_wbtest.mbt`.
///
/// The HTML must reach the parsed DOM via the navigate's
/// `load_data_url_content` path; data: URLs and direct `<iframe>`
/// markup both go through `apply_navigation_commit_state`.

///|
/// Helper: navigate session-1 to a data: URL and drain the response.
fn navigate_to_html(
  proto : BidiProtocol,
  request_id : Int,
  html : String,
) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html," +
    html +
    "\",\"wait\":\"complete\"}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Helper: getTree and return the full response JSON for inspection.
fn get_tree_json(proto : BidiProtocol, request_id : Int) -> String {
  let _ = proto.process_message(
    "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"browsingContext.getTree\",\"params\":{}}",
  )
  let msgs = proto.take_messages()
  let mut response = ""
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":" + request_id.to_string()) {
      response = json
    }
  }
  response
}

///|
test "navigate to HTML with <iframe src=...> registers a child context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  navigate_to_html(
    proto, 2, "<html><body><iframe src='about:blank' name='child1'></iframe></body></html>",
  )
  // After navigate completes, context_children[session-1] should
  // contain at least one entry. We don't know the exact child id
  // because it's allocated counter-style and other tests in the
  // same moon-test invocation may have advanced the counter — we
  // just require non-empty.
  let children = proto.context_children.get("session-1").unwrap_or([])
  assert_true(children.length() >= 1)
}

///|
test "navigate to HTML with multiple iframes registers one child per iframe" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  navigate_to_html(
    proto, 2, "<html><body><iframe src='about:blank' name='a'></iframe><iframe src='about:blank' name='b'></iframe><iframe src='about:blank' name='c'></iframe></body></html>",
  )
  let children = proto.context_children.get("session-1").unwrap_or([])
  // Three <iframe> elements, three registered children.
  assert_eq(children.length(), 3)
}

///|
test "getTree exposes discovered iframe children under their parent" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  navigate_to_html(
    proto, 2, "<html><body><iframe src='about:blank'></iframe></body></html>",
  )
  let tree_json = get_tree_json(proto, 3)
  assert_true(tree_json.contains("\"type\":\"success\""))
  assert_true(tree_json.contains("\"context\":\"session-1\""))
  // At least one child appears in the tree. Child entries don't
  // carry the `parent` field (include_parent=false at depth>0), so we
  // just check the children array isn't `[]` on session-1's entry by
  // looking for ANY second `"context":"session-` reference.
  let first = tree_json.find("\"context\":\"session-")
  assert_true(first is Some(_))
  match first {
    Some(idx) => {
      let after = tree_json.unsafe_substring(
        start=idx + 1,
        end=tree_json.length(),
      )
      // Another "context":"session-" reference means a child entry
      // exists in the tree (one for session-1, one for the iframe).
      assert_true(after.contains("\"context\":\"session-"))
    }
    None => assert_false(true)
  }
}

///|
test "renavigating clears the old iframe children and registers fresh ones" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  navigate_to_html(
    proto, 2, "<html><body><iframe src='about:blank'></iframe><iframe src='about:blank'></iframe></body></html>",
  )
  let after_first = proto.context_children.get("session-1").unwrap_or([])
  assert_eq(after_first.length(), 2)
  // Renavigate with a different iframe count — drop_child_contexts
  // followed by refresh should land on the new count, not append.
  navigate_to_html(
    proto, 3, "<html><body><iframe src='about:blank'></iframe></body></html>",
  )
  let after_second = proto.context_children.get("session-1").unwrap_or([])
  assert_eq(after_second.length(), 1)
}

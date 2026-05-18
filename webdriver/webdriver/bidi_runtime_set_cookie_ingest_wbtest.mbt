///|
/// Tests for the BiDi runtime fetch shim's inbound Set-Cookie ingest
/// bridge. Covers bug.bidi.form-submit-no-followup-navigation.
///
/// The shim already attaches partition cookies OUTBOUND
/// (`__bidiResolveCookies`, see bidi_runtime_fetch_wbtest.mbt). This file
/// pins the inverse: when the fetch shim observes a `Set-Cookie` response
/// header it buffers an entry into `__bidiPendingCookieIngest`, and the
/// next `script.evaluate` boundary calls `flush_pending_cookie_ingest`
/// (from `apply_effective_viewport_to_runtime_context`) which routes
/// each entry through `BidiProtocol::persist_cookies_from_response`. The
/// cookie then shows up via `storage.getCookies` and rides the outbound
/// `__bidiResolveCookies` bridge on the next request — closing the
/// POST + 302 + Set-Cookie -> GET /dashboard loop that the bug describes.
///
/// We deliberately test the bridge end-to-end via direct buffer
/// population rather than driving `globalThis.fetch` synchronously. The
/// real fetch shim runs the Set-Cookie capture inside a `.then` Promise
/// microtask; MoonBit's blackbox-test driver does not yield the Node
/// event loop between script.evaluate calls, so the response handler
/// would not have fired by the time we sample the buffer. The captured
/// buffer shape is identical either way.

///|
/// Spin up a fresh BidiProtocol with a default session.new, scrubbing
/// JS-side runtime state and the pending-cookie buffer so each test
/// starts from a clean slate.
fn make_proto_with_session_for_ingest() -> BidiProtocol {
  reset_runtime_js_state()
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  // Clear any pending buffer residue carried over from a previous test
  // run (reset_runtime_js_state does not touch this key).
  let _ = proto.process_message(
    "{\"id\":97,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"globalThis.__bidiPendingCookieIngest = []; null\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
/// Push a synthesized inbound entry into the JS-side pending buffer for
/// session-1. Mirrors exactly what the fetch shim's
/// `captureInboundSetCookies` helper produces on a real response.
fn push_pending_ingest(
  proto : BidiProtocol,
  request_id : Int,
  url : String,
  set_cookie_headers : Array[String],
) -> Unit {
  let cookies_json_parts : Array[String] = []
  for header in set_cookie_headers {
    cookies_json_parts.push(Json::string(header).stringify())
  }
  let cookies_json = "[" + cookies_json_parts.join(",") + "]"
  let entry = "{\"url\":" +
    Json::string(url).stringify() +
    ",\"cookies\":" +
    cookies_json +
    ",\"ctx\":\"session-1\"}"
  let expr = "(globalThis.__bidiPendingCookieIngest = globalThis.__bidiPendingCookieIngest || [], globalThis.__bidiPendingCookieIngest.push(" +
    entry +
    "), null)"
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Issue storage.getCookies for session-1 and return the response JSON.
fn get_cookies_json(proto : BidiProtocol, request_id : Int) -> String {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"storage.getCookies\",\"params\":{\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}"
  let _ = proto.process_message(payload)
  let msgs = proto.take_messages()
  if msgs.length() == 0 {
    return ""
  }
  msgs[0].to_json()
}

///|
/// Run a no-op evaluate purely to trigger the
/// `apply_effective_viewport_to_runtime_context` codepath. That codepath
/// drains the pending cookie buffer through
/// `flush_pending_cookie_ingest`.
fn trigger_flush(proto : BidiProtocol, request_id : Int) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":\"0\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Direct unit test for `BidiProtocol::persist_cookies_from_response`.
/// Bypasses the JS bridge entirely so a parser / scope / storage
/// regression is isolated from the bridge plumbing.
test "persist_cookies_from_response persists Set-Cookie into storage jar" {
  let proto = make_proto_with_session_for_ingest()
  proto.persist_cookies_from_response("session-1", "http://localhost/login", [
    "session=abc; Path=/; SameSite=Lax",
  ])
  let cookies_json = get_cookies_json(proto, 2)
  assert_true(cookies_json.contains("\"name\":\"session\""))
  assert_true(cookies_json.contains("\"value\":\"abc\""))
  assert_true(cookies_json.contains("\"domain\":\"localhost\""))
  assert_true(cookies_json.contains("\"sameSite\":\"lax\""))
}

///|
/// Multiple Set-Cookie response headers (legitimately repeated header,
/// surfaced as an array by Headers.getSetCookie()) must all be persisted.
test "persist_cookies_from_response persists multiple Set-Cookie headers" {
  let proto = make_proto_with_session_for_ingest()
  proto.persist_cookies_from_response("session-1", "http://localhost/multi", [
    "a=1; Path=/", "b=2; Path=/",
  ])
  let cookies_json = get_cookies_json(proto, 2)
  assert_true(cookies_json.contains("\"name\":\"a\""))
  assert_true(cookies_json.contains("\"value\":\"1\""))
  assert_true(cookies_json.contains("\"name\":\"b\""))
  assert_true(cookies_json.contains("\"value\":\"2\""))
}

///|
/// Bridge integration: drop an entry into `__bidiPendingCookieIngest`
/// (the same shape that `captureInboundSetCookies` produces), then drive
/// `apply_effective_viewport_to_runtime_context` via a no-op evaluate
/// to confirm the JS drain -> MoonBit `persist_cookies_from_response`
/// path lands the cookie in the partition jar.
test "fetch shim ingest buffer drain persists Set-Cookie into partition jar" {
  let proto = make_proto_with_session_for_ingest()
  push_pending_ingest(proto, 2, "http://localhost/login", [
    "session=bridged; Path=/; HttpOnly",
  ])
  // Drain happens before set_runtime_context_cookies so the
  // outbound snapshot reflects the new cookie immediately.
  trigger_flush(proto, 3)
  let cookies_json = get_cookies_json(proto, 4)
  assert_true(cookies_json.contains("\"name\":\"session\""))
  assert_true(cookies_json.contains("\"value\":\"bridged\""))
  assert_true(cookies_json.contains("\"httpOnly\":true"))
}

///|
/// End-to-end POST -> 302 -> GET sequence reified at the partition jar
/// level. After the bridge ingests a Set-Cookie from the login POST, the
/// outbound `__bidiResolveCookies` bridge must attach `session=login-ok`
/// to a subsequent same-origin request URL — that's what makes
/// form.submit's follow-up GET to /dashboard authenticated. The reverse
/// of this assertion is bug.bidi.form-submit-no-followup-navigation.
test "fetch shim ingested cookie rides the outbound bridge on the next request" {
  let proto = make_proto_with_session_for_ingest()
  push_pending_ingest(proto, 2, "http://localhost/login", [
    "session=login-ok; Path=/",
  ])
  // The drain plus the snapshot push happen inside this evaluate.
  trigger_flush(proto, 3)
  // Use the bridge directly with an absolute URL — script.evaluate
  // resets `__pageUrl` to about:blank between calls, so relative URL
  // resolution would land on about:blank and miss the localhost cookie.
  let resolve_payload = "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"globalThis.__bidiResolveCookies('http://localhost/dashboard')\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(resolve_payload)
  let msgs = proto.take_messages()
  assert_true(msgs.length() > 0)
  let resp_json = msgs[0].to_json()
  assert_true(resp_json.contains("session=login-ok"))
}

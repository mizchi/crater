///|
/// WebSocket constructor exposure in the BiDi runtime realm (#179).
///
/// Node 22+ exposes `globalThis.WebSocket` natively (and `EventSource`).
/// The BiDi runtime keeps both in its reserved-properties set so the
/// per-evaluate window → globalThis sync doesn't drop them.
///
/// These tests pin the constructor surface so a real-time / chat /
/// live-update app can at least bootstrap. End-to-end behavior
/// (CORS gating, BiDi network event emission for the WS upgrade,
/// per-message intercept) is a larger scope tracked by #179; this
/// PR is just the "is the constructor reachable" floor.

///|
test "WebSocket constructor is exposed in the realm" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__wsType = String(typeof WebSocket); globalThis.__wsProto = String(WebSocket && WebSocket.prototype ? typeof WebSocket.prototype.send : 'no-proto');",
  )
  let ty = read_global_string(proto, 3, "__wsType")
  assert_true(ty.contains("\"function\""))
  let proto_send = read_global_string(proto, 4, "__wsProto")
  // WebSocket.prototype.send must be a function on a real WebSocket
  // class — distinguishes the native Node 22 binding from a stray
  // arrow-function stub.
  assert_true(proto_send.contains("\"function\""))
}

///|
test "WebSocket exposes the standard readyState constants" {
  let proto = make_proto_with_session()
  // CONNECTING=0, OPEN=1, CLOSING=2, CLOSED=3 per WHATWG spec.
  run_sync_in_context(
    proto, 2, "globalThis.__wsStates = String(WebSocket.CONNECTING) + ',' + String(WebSocket.OPEN) + ',' + String(WebSocket.CLOSING) + ',' + String(WebSocket.CLOSED);",
  )
  let resp = read_global_string(proto, 3, "__wsStates")
  assert_true(resp.contains("\"0,1,2,3\""))
}

// EventSource is intentionally NOT tested here. Node's exposure of
// `globalThis.EventSource` varies by minor version (it's `--experimental`
// in some releases and stable in others). The reserved-set entry above
// still protects it from being dropped by the sync — if it's there, it
// stays — but pinning a presence test would create version-coupled
// flakiness in the CI matrix. SSE consumers can rely on `typeof
// EventSource === 'function'` from page code.

///|
test "WebSocket instance construction with an invalid URL throws SyntaxError" {
  let proto = make_proto_with_session()
  // We don't actually open a WebSocket here — connecting to a real
  // server from within a wbtest would require fixture infra. Instead
  // we verify the constructor rejects malformed URLs synchronously
  // per spec (a syntactically invalid URL is a SyntaxError at
  // construction time, BEFORE any async handshake).
  run_sync_in_context(
    proto, 2, "globalThis.__wsErr = '<none>'; try { new WebSocket('not-a-valid-url'); } catch (e) { globalThis.__wsErr = String(e.name || e); }",
  )
  let resp = read_global_string(proto, 3, "__wsErr")
  // Node's native WebSocket throws SyntaxError for bare paths.
  assert_true(resp.contains("\"SyntaxError\""))
}

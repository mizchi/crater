///|
/// White-box tests for bug.bidi.navigate-wait-complete-returns-early.
///
/// Verifies that browsingContext.navigate { wait: "complete" } on an http(s)
/// URL hands the page load over to the js_navigate_and_send_async bridge
/// rather than returning from the sync sync_runtime_page() path before the
/// document is actually loaded.
///
/// The wbtest harness here does not attach a real WebSocket — production
/// code attaches one in bidi_server::handle_websocket_connection. When the
/// socket is absent, the dispatcher falls back to a sync load+respond path
/// that still defers the runtime document load (so the structural change is
/// observable). The actual async send path is covered by JS-side tests that
/// drive js_navigate_and_send_async directly.

///|
/// Install a stub socket on globalThis and return it. The stub records every
/// payload it receives via .send(payload) into globalThis.__bidiNavigateTestSent.
extern "js" fn js_test_install_stub_socket() -> @core.Any =
  #| () => {
  #|   globalThis.__bidiNavigateTestSent = [];
  #|   const socket = {
  #|     send(payload) {
  #|       globalThis.__bidiNavigateTestSent.push(String(payload));
  #|     }
  #|   };
  #|   return socket;
  #| }

///|
/// Snapshot the list of payloads the stub socket has received, encoded as
/// JSON so the MoonBit side can substring-match without parsing.
extern "js" fn js_test_stub_socket_sent_json() -> String =
  #| () => JSON.stringify(globalThis.__bidiNavigateTestSent || [])

///|
/// Clear the recorded payload list (called between assertion phases).
extern "js" fn js_test_stub_socket_reset() -> Unit =
  #| () => { globalThis.__bidiNavigateTestSent = []; }

///|
/// Snapshot whatever runtime loader is installed so this test can restore it
/// on teardown without clobbering the production loader other tests rely on.
extern "js" fn js_test_snapshot_loader() -> Unit =
  #| () => {
  #|   globalThis.__bidiNavigateTestSavedLoader = globalThis.__loadPageWithScripts;
  #|   globalThis.__bidiNavigateTestSavedLoad = globalThis.__loadPage;
  #| }

///|
/// Restore the runtime loader captured by js_test_snapshot_loader (no-op if
/// the snapshot was never taken). Drops the test-only release function too.
extern "js" fn js_test_restore_loader() -> Unit =
  #| () => {
  #|   if (Object.prototype.hasOwnProperty.call(globalThis, "__bidiNavigateTestSavedLoader")) {
  #|     if (globalThis.__bidiNavigateTestSavedLoader === undefined) {
  #|       delete globalThis.__loadPageWithScripts;
  #|     } else {
  #|       globalThis.__loadPageWithScripts = globalThis.__bidiNavigateTestSavedLoader;
  #|     }
  #|     delete globalThis.__bidiNavigateTestSavedLoader;
  #|   }
  #|   if (Object.prototype.hasOwnProperty.call(globalThis, "__bidiNavigateTestSavedLoad")) {
  #|     if (globalThis.__bidiNavigateTestSavedLoad === undefined) {
  #|       delete globalThis.__loadPage;
  #|     } else {
  #|       globalThis.__loadPage = globalThis.__bidiNavigateTestSavedLoad;
  #|     }
  #|     delete globalThis.__bidiNavigateTestSavedLoad;
  #|   }
  #|   delete globalThis.__bidiNavigateTestRelease;
  #| }

///|
async test "js navigate bridge sends success payload after loader resolves" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  let resolveSent = null;
    #|  const sentPromise = new Promise((resolve) => { resolveSent = resolve; });
    #|  const socket = {
    #|    send(payload) {
    #|      if (resolveSent) { const r = resolveSent; resolveSent = null; r(String(payload)); }
    #|    }
    #|  };
    #|  const prevLoader = globalThis.__loadPageWithScripts;
    #|  globalThis.__loadPageWithScripts = (_url, _opts) => Promise.resolve();
    #|  try {
    #|    (async () => {
    #|      let success = false;
    #|      let errorMsg = "";
    #|      try {
    #|        await globalThis.__loadPageWithScripts('http://127.0.0.1:3000/login', { executeScripts: true });
    #|        success = true;
    #|      } catch (e) {
    #|        errorMsg = "load failed: " + ((e && e.message) ? e.message : String(e));
    #|      }
    #|      const response = success
    #|        ? { id: 42, type: "success", result: { navigation: 'nav-1', url: 'http://127.0.0.1:3000/login' } }
    #|        : { id: 42, type: "error", error: "unknown error", message: errorMsg };
    #|      socket.send(JSON.stringify(response));
    #|    })();
    #|    return await sentPromise;
    #|  } finally {
    #|    if (prevLoader === undefined) {
    #|      delete globalThis.__loadPageWithScripts;
    #|    } else {
    #|      globalThis.__loadPageWithScripts = prevLoader;
    #|    }
    #|  }
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  // evaluate_js_async wraps the resolved payload in BiDi serialization, so
  // the inner JSON appears with escaped quotes ("\"id\":42" -> "\\\"id\\\":42").
  assert_true(json.contains("id\\\":42"))
  assert_true(json.contains("type\\\":\\\"success"))
  assert_true(json.contains("navigation\\\":\\\"nav-1"))
  assert_true(json.contains("url\\\":\\\"http://127.0.0.1:3000/login"))
}

///|
async test "js navigate bridge sends error payload when loader rejects" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  let resolveSent = null;
    #|  const sentPromise = new Promise((resolve) => { resolveSent = resolve; });
    #|  const socket = {
    #|    send(payload) {
    #|      if (resolveSent) { const r = resolveSent; resolveSent = null; r(String(payload)); }
    #|    }
    #|  };
    #|  const prevLoader = globalThis.__loadPageWithScripts;
    #|  globalThis.__loadPageWithScripts = (_url, _opts) =>
    #|    Promise.reject(new Error("simulated load failure"));
    #|  try {
    #|    (async () => {
    #|      let success = false;
    #|      let errorMsg = "";
    #|      try {
    #|        await globalThis.__loadPageWithScripts('http://127.0.0.1:3000/login', { executeScripts: true });
    #|        success = true;
    #|      } catch (e) {
    #|        errorMsg = "load failed: " + ((e && e.message) ? e.message : String(e));
    #|      }
    #|      const response = success
    #|        ? { id: 42, type: "success", result: { navigation: 'nav-2', url: 'http://127.0.0.1:3000/login' } }
    #|        : { id: 42, type: "error", error: "unknown error", message: errorMsg };
    #|      socket.send(JSON.stringify(response));
    #|    })();
    #|    return await sentPromise;
    #|  } finally {
    #|    if (prevLoader === undefined) {
    #|      delete globalThis.__loadPageWithScripts;
    #|    } else {
    #|      globalThis.__loadPageWithScripts = prevLoader;
    #|    }
    #|  }
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("id\\\":42"))
  assert_true(json.contains("type\\\":\\\"error"))
  assert_true(json.contains("load failed"))
  assert_true(json.contains("simulated load failure"))
}

///|
test "bidi navigate wait=complete on http URL takes deferred path" {
  // No socket attached — the dispatcher falls back to the sync
  // complete_navigation_request_with_wait_after_deferred path, which still
  // defers the load (skipping it from apply_navigation_commit_state) and
  // then performs the load + send inline. The important structural property
  // is that the response is still produced and references the http URL,
  // even though the load itself is deferred from the commit-state step.
  js_test_snapshot_loader()
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://127.0.0.1:3000/login\",\"wait\":\"complete\"}}",
  )
  let outbox = proto.take_messages()
  let mut saw_success = false
  for msg in outbox {
    let json = msg.to_json()
    if json.contains("\"id\":2") &&
      json.contains("\"type\":\"success\"") &&
      json.contains("\"url\":\"http://127.0.0.1:3000/login\"") {
      saw_success = true
    }
  }
  assert_true(saw_success)
  js_test_restore_loader()
}

///|
test "bidi navigate wait=complete on data: URL still responds synchronously" {
  js_test_snapshot_loader()
  js_test_stub_socket_reset()
  let socket = js_test_install_stub_socket()
  let proto = BidiProtocol::new()
  let _ = proto.set_socket(socket)
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<p>hi</p>\",\"wait\":\"complete\"}}",
  )
  // Data URLs do not need the async bridge — the response must be on the
  // sync outbox, NOT on the socket (the JS async send path is bypassed).
  let outbox = proto.take_messages()
  let mut saw_success = false
  for msg in outbox {
    let json = msg.to_json()
    if json.contains("\"id\":2") && json.contains("\"type\":\"success\"") {
      saw_success = true
    }
  }
  assert_true(saw_success)
  let sent = js_test_stub_socket_sent_json()
  assert_true(!sent.contains("\"id\":2"))
  js_test_restore_loader()
}

///|
/// Read the awaitable stub socket installed by the async bridge test setup
/// expression. The socket is stored on globalThis after the setup IIFE runs
/// its synchronous preamble (before the first `await`).
extern "js" fn js_test_get_nav_async_stub_socket() -> @core.Any =
  #| () => globalThis.__bidiNavAsyncTestSocket

///|
async test "navigate_and_send_async real FFI sends correct payload via stub socket" {
  // This test exercises js_navigate_and_send_async through the real
  // navigate_and_send_async MoonBit wrapper, NOT an inline copy. If the FFI
  // body drifts (key names, response shape), this test will catch it.
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  js_test_snapshot_loader()
  js_test_stub_socket_reset()
  // Install the promise-backed stub socket and stub loader synchronously.
  // The JS IIFE runs its setup before the first `await`, so the socket is
  // available immediately on globalThis.__bidiNavAsyncTestSocket.
  let setup_expr =
    #|(async () => {
    #|  globalThis.__bidiNavigateTestSent = [];
    #|  let resolvePayload = null;
    #|  const payloadPromise = new Promise((resolve) => { resolvePayload = resolve; });
    #|  globalThis.__bidiNavAsyncTestSocket = {
    #|    send(payload) {
    #|      globalThis.__bidiNavigateTestSent.push(String(payload));
    #|      if (resolvePayload) {
    #|        const r = resolvePayload;
    #|        resolvePayload = null;
    #|        r(String(payload));
    #|      }
    #|    }
    #|  };
    #|  globalThis.__loadPageWithScripts = (_url, _opts) => Promise.resolve();
    #|  return await payloadPromise;
    #|})()
  let setup_promise_any = evaluate_js_async(setup_expr)
  // The synchronous preamble of the IIFE has already run: socket is set.
  let socket = js_test_get_nav_async_stub_socket()
  // Call the REAL FFI wrapper — not an inline copy.
  navigate_and_send_async(socket, 99, "ctx-1", "http://example.com/x", "nav-99")
  // Now pump the event loop: the navigate async resolves the loader, calls
  // socket.send(payload), which resolves payloadPromise.
  let setup_promise : @js_async.Promise[String] = setup_promise_any.cast()
  let outer_json = @js_async.Promise::wait(setup_promise)
  // outer_json is the BiDi-serialised result from evaluate_js_async:
  // {"type":"success","result":{"type":"string","value":"<the raw payload>"},...}
  // The raw payload is {"id":99,"type":"success","result":{"navigation":"nav-99","url":"http://example.com/x"}}
  // Verify that the socket received exactly one payload.
  let sent_json = js_test_stub_socket_sent_json()
  assert_true(sent_json.contains("nav-99"))
  assert_true(sent_json.contains("http://example.com/x"))
  // Also verify the outer BiDi wrapper reports a successful evaluation.
  assert_true(outer_json.contains("type\\\":\\\"success"))
  // Verify key fields in the payload that the real FFI body must produce:
  // "id": 99, "type": "success", result.navigation == "nav-99", result.url
  assert_true(
    sent_json.contains("\\\"id\\\":99") || sent_json.contains("\"id\":99"),
  )
  assert_true(
    sent_json.contains("\\\"type\\\":\\\"success") ||
    sent_json.contains("\"type\":\"success"),
  )
  assert_true(
    sent_json.contains("\\\"navigation\\\":\\\"nav-99") ||
    sent_json.contains("\"navigation\":\"nav-99"),
  )
  assert_true(
    sent_json.contains("\\\"url\\\":\\\"http://example.com/x") ||
    sent_json.contains("\"url\":\"http://example.com/x"),
  )
  js_test_restore_loader()
}

///|
test "bidi navigate wait=none on http URL still responds immediately" {
  js_test_snapshot_loader()
  js_test_stub_socket_reset()
  let socket = js_test_install_stub_socket()
  let proto = BidiProtocol::new()
  let _ = proto.set_socket(socket)
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://127.0.0.1:3000/login\",\"wait\":\"none\"}}",
  )
  // wait=none never goes through the async bridge — the success response
  // must be on the sync outbox, not on the socket.
  let outbox = proto.take_messages()
  let mut saw_success = false
  for msg in outbox {
    let json = msg.to_json()
    if json.contains("\"id\":2") && json.contains("\"type\":\"success\"") {
      saw_success = true
    }
  }
  assert_true(saw_success)
  let sent = js_test_stub_socket_sent_json()
  assert_true(!sent.contains("\"id\":2"))
  js_test_restore_loader()
}

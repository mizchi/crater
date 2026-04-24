///|
/// White-box tests for BiDi server JS sandbox/CORS hooks

///|
extern "js" fn js_test_install_readonly_navigator(ctx_id : String) -> Unit =
  #| (ctxId) => {
  #|   const nav = {};
  #|   Object.defineProperty(nav, "userAgent", {
  #|     get() { return "OLD-UA"; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(nav, "language", {
  #|     get() { return "en-US"; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(nav, "languages", {
  #|     get() { return ["en-US"]; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(nav, "onLine", {
  #|     get() { return true; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(nav, "platform", {
  #|     get() { return "Crater"; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(nav, "cookieEnabled", {
  #|     get() { return false; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(nav, "userActivation", {
  #|     get() { return { isActive: false, hasBeenActive: false }; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   const win = {};
  #|   Object.defineProperty(win, "navigator", {
  #|     get() { return nav; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   Object.defineProperty(globalThis, "navigator", {
  #|     get() { return nav; },
  #|     configurable: true,
  #|     enumerable: true,
  #|   });
  #|   globalThis.__bidiCurrentContext = String(ctxId);
  #|   globalThis.__bidiContextWindows = new Map([[String(ctxId), win]]);
  #| }

///|
extern "js" fn js_test_runtime_navigator_snapshot(ctx_id : String) -> String =
  #| (ctxId) => JSON.stringify({
  #|   globalUserAgent: String(globalThis.navigator.userAgent),
  #|   globalLanguage: String(globalThis.navigator.language),
  #|   globalLanguages: Array.isArray(globalThis.navigator.languages)
  #|     ? Array.from(globalThis.navigator.languages)
  #|     : [],
  #|   globalOnline: globalThis.navigator.onLine !== false,
  #|   windowUserAgent: String(globalThis.__bidiContextWindows.get(String(ctxId)).navigator.userAgent),
  #|   windowLanguage: String(globalThis.__bidiContextWindows.get(String(ctxId)).navigator.language),
  #|   windowLanguages: Array.isArray(globalThis.__bidiContextWindows.get(String(ctxId)).navigator.languages)
  #|     ? Array.from(globalThis.__bidiContextWindows.get(String(ctxId)).navigator.languages)
  #|     : [],
  #|   windowOnline: globalThis.__bidiContextWindows.get(String(ctxId)).navigator.onLine !== false,
  #| })

///|
test "runtime navigator patches readonly userAgent and locale surfaces" {
  reset_runtime_js_state()
  js_test_install_readonly_navigator("ctx-1")

  set_runtime_context_user_agent("ctx-1", "NEW-UA")
  set_runtime_context_locale("ctx-1", "fr-CA")

  let snapshot = js_test_runtime_navigator_snapshot("ctx-1")
  assert_true(snapshot.contains("\"globalUserAgent\":\"NEW-UA\""))
  assert_true(snapshot.contains("\"windowUserAgent\":\"NEW-UA\""))
  assert_true(snapshot.contains("\"globalLanguage\":\"fr-CA\""))
  assert_true(snapshot.contains("\"windowLanguage\":\"fr-CA\""))
  assert_true(snapshot.contains("\"globalLanguages\":[\"fr-CA\"]"))
  assert_true(snapshot.contains("\"windowLanguages\":[\"fr-CA\"]"))
}

///|
test "runtime navigator patches readonly online surface" {
  reset_runtime_js_state()
  js_test_install_readonly_navigator("ctx-1")

  set_runtime_context_network_online("ctx-1", false)

  let snapshot = js_test_runtime_navigator_snapshot("ctx-1")
  assert_true(snapshot.contains("\"globalOnline\":false"))
  assert_true(snapshot.contains("\"windowOnline\":false"))
}

///|
async test "bidi fetch blocked by same-origin sandbox" {
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  globalThis.__pageUrl = 'https://example.test/';
    #|  globalThis.__setRequestSandbox({ mode: 'same-origin' });
    #|  try {
    #|    await fetch('https://other.test/resource', { mode: 'cors' });
    #|    return 'no-error';
    #|  } catch (e) {
    #|    return 'error:' + e.message;
    #|  }
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("Blocked by request sandbox"))
}

///|
async test "bidi module import blocked by same-origin sandbox" {
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  globalThis.__pageUrl = 'https://example.test/';
    #|  globalThis.__setRequestSandbox({ mode: 'same-origin' });
    #|  const script = document.createElement('script');
    #|  script.setAttribute('type', 'module');
    #|  script.setAttribute('src', 'https://other.test/module.js');
    #|  document.body.appendChild(script);
    #|  const results = await globalThis.__executeScripts({ baseUrl: globalThis.__pageUrl });
    #|  const msg = results && results[0] && results[0].message ? results[0].message : '';
    #|  return msg || 'ok';
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("Blocked by request sandbox"))
}

///|
test "bidi status response includes tokenized websocket url when auth is enabled" {
  let config : BidiServerConfig = {
    host: "127.0.0.1",
    port: 9222,
    auth_token: "token-123",
  }
  let body = bidi_status_response_body(config)
  assert_true(body.contains("\"ready\":true"))
  assert_true(body.contains("\"authEnabled\":true"))
  assert_true(
    body.contains("\"webSocketUrl\":\"ws://127.0.0.1:9222/session/token-123\""),
  )
}

///|
test "bidi status response uses bare websocket url when auth is disabled" {
  let config : BidiServerConfig = {
    host: "127.0.0.1",
    port: 9222,
    auth_token: "",
  }
  let body = bidi_status_response_body(config)
  assert_true(body.contains("\"authEnabled\":false"))
  assert_true(body.contains("\"webSocketUrl\":\"ws://127.0.0.1:9222\""))
}

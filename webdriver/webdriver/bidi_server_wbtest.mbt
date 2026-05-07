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
extern "js" fn js_test_install_stale_context_document(ctx_id : String) -> Unit =
  #| (ctxId) => {
  #|   const id = String(ctxId);
  #|   const staleDocument = {
  #|     body: { appendChild(node) { return node; } },
  #|     createElement(tagName) {
  #|       const name = String(tagName || "div");
  #|       return {
  #|         tagName: name.toUpperCase(),
  #|         localName: name.toLowerCase(),
  #|         nodeType: 1,
  #|         _attrs: {},
  #|         _children: [],
  #|         childNodes: [],
  #|         setAttribute(name, value) { this._attrs[String(name)] = String(value); },
  #|       };
  #|     },
  #|     createTextNode(text) { return { nodeType: 3, textContent: String(text) }; },
  #|     createDocumentFragment() {
  #|       return {
  #|         nodeType: 11,
  #|         nodeName: "#document-fragment",
  #|         _children: [],
  #|         childNodes: [],
  #|       };
  #|     },
  #|   };
  #|   globalThis.__bidiCurrentContext = id;
  #|   globalThis.__bidiContextWindows = new Map([
  #|     [id, { __bidiContextId: id, window: null, document: staleDocument }]
  #|   ]);
  #|   Object.defineProperty(globalThis, "document", {
  #|     configurable: true,
  #|     enumerable: true,
  #|     writable: true,
  #|     value: staleDocument,
  #|   });
  #| }

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
  reset_runtime_js_state()
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
async test "bidi loadPage navigation bypasses same-origin sandbox" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  globalThis.__pageUrl = 'https://previous.test/page';
    #|  globalThis.__setRequestSandbox({ mode: 'same-origin' });
    #|  const html = '<!doctype html><html><body><h1>Loaded from navigation</h1></body></html>';
    #|  const result = await globalThis.__loadPage('data:text/html,' + encodeURIComponent(html));
    #|  const h1 = document.querySelector('h1');
    #|  return [
    #|    'status=' + result.status,
    #|    'pageUrl=' + globalThis.__pageUrl,
    #|    'location=' + (globalThis.location ? globalThis.location.href : ''),
    #|    'h1=' + (h1 ? h1.textContent : '')
    #|  ].join(';');
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("status=200"))
  assert_true(json.contains("pageUrl=data:text/html,"))
  assert_true(json.contains("location=data:text/html,"))
  assert_true(json.contains("h1=Loaded from navigation"))
}

///|
async test "bidi loadHTML keeps noscript styles inert" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  const html = '<!doctype html><html><head><noscript><style>img[data-sd-img]{display:none}</style></noscript><style>.hero{display:flex}</style></head><body><img class="hero" data-sd-img></body></html>';
    #|  globalThis.__loadHTML(html);
    #|  const styles = Array.from(document.querySelectorAll('style')).map((style) => style.textContent);
    #|  return 'styles=' + styles.length + ';hasData=' + styles.some((css) => css.includes('data-sd-img')) + ';hasHero=' + styles.some((css) => css.includes('.hero'));
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("styles=1"))
  assert_true(json.contains("hasData=false"))
  assert_true(json.contains("hasHero=true"))
}

///|
async test "bidi document createRange parses contextual fragments" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  globalThis.__loadHTML('<!doctype html><html><body><main id="app"></main></body></html>');
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const range = document.createRange();
    #|  range.selectNode(host);
    #|  const fragment = range.createContextualFragment('<p id="embed">Hello <strong>Studio</strong></p><script src="/embed.js"></script>');
    #|  const children = Array.from(fragment.childNodes);
    #|  let scriptLoad = 'none';
    #|  for (const child of children) {
    #|    host.appendChild(child);
    #|    if (child instanceof HTMLScriptElement && child.src) {
    #|      const loaded = new Promise((resolve) => child.addEventListener('load', () => resolve('load'), { once: true }));
    #|      scriptLoad = await Promise.race([loaded, new Promise((resolve) => setTimeout(() => resolve('timeout'), 20))]);
    #|    }
    #|  }
    #|  const p = host.querySelector('#embed');
    #|  const script = host.querySelector('script');
    #|  return [
    #|    'children=' + children.length,
    #|    'p=' + (p ? p.textContent : ''),
    #|    'scriptInstance=' + (script instanceof HTMLScriptElement),
    #|    'scriptSrc=' + (script ? script.getAttribute('src') : ''),
    #|    'scriptLoad=' + scriptLoad
    #|  ].join(';');
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("children=2"))
  assert_true(json.contains("p=Hello Studio"))
  assert_true(json.contains("scriptInstance=true"))
  assert_true(json.contains("scriptSrc=/embed.js"))
  assert_true(json.contains("scriptLoad=load"))
}

///|
async test "bidi loadHTML keeps context window document in sync for scripts" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(async () => {
    #|  globalThis.__bidiCurrentContext = 'ctx-range-sync';
    #|  globalThis.__bidiContextWindows = new Map([
    #|    ['ctx-range-sync', { __bidiContextId: 'ctx-range-sync', window: null, document: { createRange: undefined } }]
    #|  ]);
    #|  globalThis.__loadHTML('<!doctype html><html><body><script>document.body.setAttribute("data-range", typeof document.createRange);</script></body></html>');
    #|  await globalThis.__executeScripts({ baseUrl: 'https://example.test/' });
    #|  return 'range=' + document.body.getAttribute('data-range');
    #|})()
  let promise_any = evaluate_js_async(expr)
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  assert_true(json.contains("range=function"))
}

///|
test "bidi sync fallback document exposes createRange" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  js_test_install_stale_context_document("default-context")
  let json = evaluate_js("typeof document.createRange")
  let _ = evaluate_js("globalThis.document = undefined")
  assert_true(json.contains("\"value\":\"function\""))
}

///|
async test "bidi async fallback document exposes createRange" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  js_test_install_stale_context_document("")
  let promise_any = evaluate_js_async("typeof document.createRange")
  let promise : @js_async.Promise[String] = promise_any.cast()
  let json = @js_async.Promise::wait(promise)
  let _ = evaluate_js("globalThis.document = undefined")
  assert_true(json.contains("\"value\":\"function\""))
}

///|
async test "bidi module import blocked by same-origin sandbox" {
  reset_runtime_js_state()
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

///|
/// White-box tests for BiDi server JS sandbox/CORS hooks

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

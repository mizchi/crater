///|
/// Form submission / document.forms tests for the BiDi runtime mock DOM.
/// Covers bug.dom.html-form-element-submit-missing and bug.dom.document-forms-missing.

///|
test "bidi document.forms returns all FORM elements in document order" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  globalThis.__loadHTML(
    #|    '<!doctype html><html><body>' +
    #|      '<form id="a" action="/one"></form>' +
    #|      '<div><form id="b" action="/two"></form></div>' +
    #|      '<form id="c" action="/three"></form>' +
    #|    '</body></html>'
    #|  );
    #|  const forms = document.forms;
    #|  return [
    #|    'len=' + forms.length,
    #|    'ids=' + forms.map((f) => f.id).join(','),
    #|    'allForms=' + forms.every((f) => f.tagName === 'FORM')
    #|  ].join(';');
    #|})()
  let json = evaluate_js(expr)
  assert_true(json.contains("len=3"))
  assert_true(json.contains("ids=a,b,c"))
  assert_true(json.contains("allForms=true"))
}

///|
test "bidi form.submit and form.requestSubmit are functions on form elements" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  globalThis.__loadHTML('<!doctype html><html><body><form id="f"></form></body></html>');
    #|  const f = document.getElementById('f');
    #|  return [
    #|    'submit=' + typeof f.submit,
    #|    'requestSubmit=' + typeof f.requestSubmit,
    #|    'reset=' + typeof f.reset
    #|  ].join(';');
    #|})()
  let json = evaluate_js(expr)
  assert_true(json.contains("submit=function"))
  assert_true(json.contains("requestSubmit=function"))
  assert_true(json.contains("reset=function"))
}

///|
test "bidi form.requestSubmit dispatches submit event and honors preventDefault" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  let navCalled = 0;
    #|  const savedWithScripts = globalThis.__loadPageWithScripts;
    #|  const savedLoadPage = globalThis.__loadPage;
    #|  globalThis.__loadPageWithScripts = () => { navCalled++; return Promise.resolve({ url: '', status: 200 }); };
    #|  globalThis.__loadPage = () => { navCalled++; return Promise.resolve({ url: '', status: 200 }); };
    #|  try {
    #|    globalThis.__loadHTML(
    #|      '<!doctype html><html><body>' +
    #|        '<form id="f" action="/blocked" method="GET">' +
    #|          '<input name="user" value="alice">' +
    #|        '</form>' +
    #|      '</body></html>'
    #|    );
    #|    const beforeHref = String(globalThis.location.href);
    #|    globalThis.__pageUrl = beforeHref;
    #|    const f = document.getElementById('f');
    #|    let fired = 0;
    #|    let sawSubmitter = 'unset';
    #|    f.addEventListener('submit', (event) => {
    #|      fired++;
    #|      sawSubmitter = (event.submitter === null) ? 'null' : (event.submitter ? 'set' : 'unset');
    #|      event.preventDefault();
    #|    });
    #|    f.requestSubmit();
    #|    const afterHref = String(globalThis.location.href);
    #|    return [
    #|      'fired=' + fired,
    #|      'submitter=' + sawSubmitter,
    #|      'navCalled=' + navCalled,
    #|      'navigated=' + (beforeHref !== afterHref)
    #|    ].join(';');
    #|  } finally {
    #|    globalThis.__loadPageWithScripts = savedWithScripts;
    #|    globalThis.__loadPage = savedLoadPage;
    #|  }
    #|})()
  let json = evaluate_js(expr)
  assert_true(json.contains("fired=1"))
  assert_true(json.contains("submitter=null"))
  assert_true(json.contains("navCalled=0"))
  assert_true(json.contains("navigated=false"))
}

///|
test "bidi form.submit ignores javascript: action (URL scheme allowlist)" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  let navCalled = 0;
    #|  let fetchCalled = 0;
    #|  let errorCalls = 0;
    #|  const savedWithScripts = globalThis.__loadPageWithScripts;
    #|  const savedLoadPage = globalThis.__loadPage;
    #|  const savedFetch = globalThis.fetch;
    #|  const savedFetchInternal = globalThis.__fetchInternal;
    #|  const savedConsoleError = (globalThis.console && globalThis.console.error) || null;
    #|  globalThis.__loadPageWithScripts = (url) => { navCalled++; return Promise.resolve({ url: String(url || ''), status: 200 }); };
    #|  globalThis.__loadPage = (url) => { navCalled++; return Promise.resolve({ url: String(url || ''), status: 200 }); };
    #|  globalThis.fetch = () => { fetchCalled++; return Promise.resolve({ status: 200, headers: { get: () => null }, text: () => Promise.resolve('') }); };
    #|  globalThis.__fetchInternal = () => { fetchCalled++; return Promise.resolve({ status: 200, headers: { get: () => null }, text: () => Promise.resolve('') }); };
    #|  if (globalThis.console) { globalThis.console.error = () => { errorCalls++; }; }
    #|  try {
    #|    globalThis.__loadHTML(
    #|      '<!doctype html><html><body>' +
    #|        '<form id="jsf" action="javascript:throw new Error(\'xss\')" method="GET"></form>' +
    #|        '<form id="vbf" action="vbscript:msgbox(1)" method="GET"></form>' +
    #|        '<form id="filef" action="ftp://example.test/bad" method="GET"></form>' +
    #|      '</body></html>'
    #|    );
    #|    const beforeHref = String(globalThis.location.href);
    #|    globalThis.__pageUrl = beforeHref;
    #|    let threw = 0;
    #|    try { document.getElementById('jsf').submit(); } catch (_e) { threw++; }
    #|    try { document.getElementById('vbf').submit(); } catch (_e) { threw++; }
    #|    try { document.getElementById('filef').submit(); } catch (_e) { threw++; }
    #|    const afterHref = String(globalThis.location.href);
    #|    return [
    #|      'threw=' + threw,
    #|      'navCalled=' + navCalled,
    #|      'fetchCalled=' + fetchCalled,
    #|      'errorCalls=' + errorCalls,
    #|      'hrefChanged=' + (beforeHref !== afterHref)
    #|    ].join(';');
    #|  } finally {
    #|    globalThis.__loadPageWithScripts = savedWithScripts;
    #|    globalThis.__loadPage = savedLoadPage;
    #|    globalThis.fetch = savedFetch;
    #|    globalThis.__fetchInternal = savedFetchInternal;
    #|    if (globalThis.console && savedConsoleError) globalThis.console.error = savedConsoleError;
    #|  }
    #|})()
  let json = evaluate_js(expr)
  // No exception should escape (silent drop), no navigation, no fetch.
  assert_true(json.contains("threw=0"))
  assert_true(json.contains("navCalled=0"))
  assert_true(json.contains("fetchCalled=0"))
  assert_true(json.contains("hrefChanged=false"))
  // All three (javascript:, vbscript:, ftp:) are blocked and each logs a
  // single console.error.
  assert_true(json.contains("errorCalls=3"))
}

///|
test "bidi form.submit serializes SELECT options correctly" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  let navTarget = '';
    #|  const savedWithScripts = globalThis.__loadPageWithScripts;
    #|  const savedLoadPage = globalThis.__loadPage;
    #|  globalThis.__loadPageWithScripts = (url) => { navTarget = String(url || ''); return Promise.resolve({ url: navTarget, status: 200 }); };
    #|  globalThis.__loadPage = (url) => { navTarget = String(url || ''); return Promise.resolve({ url: navTarget, status: 200 }); };
    #|  try {
    #|    globalThis.__loadHTML(
    #|      '<!doctype html><html><body>' +
    #|        '<form id="f" action="https://example.test/sel" method="GET">' +
    #|          '<select name="color">' +
    #|            '<option value="r">Red</option>' +
    #|            '<option value="g" selected>Green</option>' +
    #|            '<option value="b">Blue</option>' +
    #|          '</select>' +
    #|          '<select name="size">' +
    #|            '<option value="s">Small</option>' +
    #|            '<option value="m">Medium</option>' +
    #|          '</select>' +
    #|          '<select name="fruit">' +
    #|            '<option>Apple</option>' +
    #|            '<option selected>Banana</option>' +
    #|          '</select>' +
    #|        '</form>' +
    #|      '</body></html>'
    #|    );
    #|    document.getElementById('f').submit();
    #|    return [
    #|      'hasColor=' + navTarget.includes('color=g'),
    #|      'hasSize=' + navTarget.includes('size=s'),
    #|      'hasFruit=' + navTarget.includes('fruit=Banana'),
    #|      'noEmptyColor=' + !/[?&]color=(&|$)/.test(navTarget),
    #|      'navTarget=' + navTarget
    #|    ].join(';');
    #|  } finally {
    #|    globalThis.__loadPageWithScripts = savedWithScripts;
    #|    globalThis.__loadPage = savedLoadPage;
    #|  }
    #|})()
  let json = evaluate_js(expr)
  assert_true(json.contains("hasColor=true"))
  assert_true(json.contains("hasSize=true"))
  assert_true(json.contains("hasFruit=true"))
  assert_true(json.contains("noEmptyColor=true"))
}

///|
test "bidi form.requestSubmit submitter validation accepts element without _attrs" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  const savedWithScripts = globalThis.__loadPageWithScripts;
    #|  const savedLoadPage = globalThis.__loadPage;
    #|  globalThis.__loadPageWithScripts = () => Promise.resolve({ url: '', status: 200 });
    #|  globalThis.__loadPage = () => Promise.resolve({ url: '', status: 200 });
    #|  try {
    #|    globalThis.__loadHTML(
    #|      '<!doctype html><html><body>' +
    #|        '<form id="f" action="/x" method="GET">' +
    #|          '<button id="b" type="submit">Go</button>' +
    #|        '</form>' +
    #|      '</body></html>'
    #|    );
    #|    const f = document.getElementById('f');
    #|    const b = document.getElementById('b');
    #|    // Strip _attrs to simulate a host element lacking it. nodeType === 1
    #|    // + descendsFrom should still satisfy the validation.
    #|    delete b._attrs;
    #|    let sawSubmitter = 'unset';
    #|    let threwForChild = 0;
    #|    f.addEventListener('submit', (event) => {
    #|      sawSubmitter = event.submitter === b ? 'matches' : (event.submitter === null ? 'null' : 'other');
    #|      event.preventDefault();
    #|    });
    #|    try { f.requestSubmit(b); } catch (_e) { threwForChild++; }
    #|    // Non-descendant should still throw.
    #|    let threwForOutside = 0;
    #|    const outsideEl = document.createElement('button');
    #|    try { f.requestSubmit(outsideEl); } catch (_e) { threwForOutside++; }
    #|    return [
    #|      'submitter=' + sawSubmitter,
    #|      'threwForChild=' + threwForChild,
    #|      'threwForOutside=' + threwForOutside
    #|    ].join(';');
    #|  } finally {
    #|    globalThis.__loadPageWithScripts = savedWithScripts;
    #|    globalThis.__loadPage = savedLoadPage;
    #|  }
    #|})()
  let json = evaluate_js(expr)
  assert_true(json.contains("submitter=matches"))
  assert_true(json.contains("threwForChild=0"))
  assert_true(json.contains("threwForOutside=1"))
}

///|
test "bidi form.submit bypasses submit event listener and encodes GET query" {
  reset_runtime_js_state()
  let _ = evaluate_js("0")
  let expr =
    #|(() => {
    #|  let navTarget = '';
    #|  const savedWithScripts = globalThis.__loadPageWithScripts;
    #|  const savedLoadPage = globalThis.__loadPage;
    #|  globalThis.__loadPageWithScripts = (url) => { navTarget = String(url || ''); return Promise.resolve({ url: navTarget, status: 200 }); };
    #|  globalThis.__loadPage = (url) => { navTarget = String(url || ''); return Promise.resolve({ url: navTarget, status: 200 }); };
    #|  try {
    #|    globalThis.__loadHTML(
    #|      '<!doctype html><html><body>' +
    #|        '<form id="f" action="https://example.test/submit" method="GET">' +
    #|          '<input name="q" value="hello world">' +
    #|          '<input name="t" type="checkbox" checked>' +
    #|          '<input name="ignored" type="checkbox">' +
    #|        '</form>' +
    #|      '</body></html>'
    #|    );
    #|    const f = document.getElementById('f');
    #|    let fired = 0;
    #|    f.addEventListener('submit', () => { fired++; });
    #|    f.submit();
    #|    return [
    #|      'fired=' + fired,
    #|      'hasQ=' + navTarget.includes('q=hello%20world'),
    #|      'hasT=' + navTarget.includes('t=on'),
    #|      'noIgnored=' + !navTarget.includes('ignored'),
    #|      'host=' + navTarget.includes('example.test')
    #|    ].join(';');
    #|  } finally {
    #|    globalThis.__loadPageWithScripts = savedWithScripts;
    #|    globalThis.__loadPage = savedLoadPage;
    #|  }
    #|})()
  let json = evaluate_js(expr)
  assert_true(json.contains("fired=0"))
  assert_true(json.contains("hasQ=true"))
  assert_true(json.contains("hasT=true"))
  assert_true(json.contains("noIgnored=true"))
  assert_true(json.contains("host=true"))
}

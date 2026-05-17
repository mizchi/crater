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

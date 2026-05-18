///|
/// Tests for the BiDi runtime fetch shim's cookie-attach bridge and CORS
/// preflight dispatch. Covers:
///   * bug.runtime.fetch-no-partition-cookies — storage.setCookie cookies are
///     injected as the Cookie header on outbound fetches.
///   * bug.runtime.fetch-no-cors-gate — non-simple cross-origin fetches send
///     OPTIONS preflight and honor ACA-* response headers.
///
/// We drive each scenario through a sync `script.evaluate` whose JS body
/// stubs `globalThis.__rawFetch`, calls the fetch shim, and stashes captured
/// state on a globalThis side variable. Same-origin / no-CORS fetches now
/// dispatch synchronously (no Promise.resolve hop) so the captured state is
/// visible to the very next evaluate. Cross-origin / preflight scenarios
/// still defer via Promise microtasks; we flush those by switching the test
/// to `async test "..."` and calling `@async.sleep(10)` so Node's event
/// loop drains the queued .then chains before we read the side state.

///|
/// Spin up a fresh BidiProtocol with a default session.new.
fn make_proto_with_session() -> BidiProtocol {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
/// Seed a storage cookie scoped to session-1.
fn seed_storage_cookie(
  proto : BidiProtocol,
  request_id : Int,
  cookie_json : String,
) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"storage.setCookie\",\"params\":{\"cookie\":" +
    cookie_json +
    ",\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Run a JS expression in the context of session-1 without awaiting promises.
fn run_sync_in_context(
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
/// Read a globalThis string variable through script.evaluate and return the
/// raw response JSON (so tests can match against the embedded value).
fn read_global_string(
  proto : BidiProtocol,
  request_id : Int,
  global_name : String,
) -> String {
  let expr = "(typeof globalThis." +
    global_name +
    " === 'string' ? globalThis." +
    global_name +
    " : '')"
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let msgs = proto.take_messages()
  if msgs.length() == 0 {
    return ""
  }
  msgs[0].to_json()
}

///|
/// Confirm that the MoonBit-side cookie aggregator returns the expected
/// shape. Catches schema regressions in the JSON pushed to the JS bridge.
test "BidiProtocol::cookies_for_context_full_json returns name+value+domain+path+secure+sameSite" {
  let proto = make_proto_with_session()
  seed_storage_cookie(
    proto, 2, "{\"name\":\"sid\",\"value\":{\"type\":\"string\",\"value\":\"abc123\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
  )
  let cookies = proto.cookies_for_context_full_json("session-1")
  assert_eq(cookies.length(), 1)
  let s = Json::array(cookies).stringify()
  assert_true(s.contains("\"name\":\"sid\""))
  assert_true(s.contains("\"value\":\"abc123\""))
  assert_true(s.contains("\"domain\":\"localhost\""))
  assert_true(s.contains("\"path\":\"/\""))
  assert_true(s.contains("\"secure\":false"))
  assert_true(s.contains("\"sameSite\":\"lax\""))
}

///|
/// The JS-side `__bidiResolveCookies` bridge is installed by
/// `set_runtime_context_cookies`, which is invoked from
/// `apply_effective_viewport_to_runtime_context` for every script.evaluate.
/// After a no-op evaluate, the bridge must be present and return the seeded
/// cookie as a Cookie header value.
test "fetch shim cookie bridge resolves seeded cookies into a Cookie header value" {
  let proto = make_proto_with_session()
  seed_storage_cookie(
    proto, 2, "{\"name\":\"sid\",\"value\":{\"type\":\"string\",\"value\":\"abc123\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
  )
  run_sync_in_context(
    proto, 3, "globalThis.__pageUrl = 'http://localhost/'; globalThis.__lastResolveCookies = (typeof globalThis.__bidiResolveCookies === 'function' ? globalThis.__bidiResolveCookies('http://localhost/api/me') : '<no-fn>');",
  )
  let resp = read_global_string(proto, 4, "__lastResolveCookies")
  assert_true(resp.contains("sid=abc123"))
}

///|
/// Secure-only cookies must NOT match an http:// request. Pins the scheme
/// filter inside the bridge (cookie jar parity).
test "fetch shim cookie bridge filters Secure cookies from http requests" {
  let proto = make_proto_with_session()
  seed_storage_cookie(
    proto, 2, "{\"name\":\"sec\",\"value\":{\"type\":\"string\",\"value\":\"https-only\"},\"domain\":\"localhost\",\"path\":\"/\",\"secure\":true,\"sameSite\":\"strict\"}",
  )
  run_sync_in_context(
    proto, 3, "globalThis.__pageUrl = 'http://localhost/'; globalThis.__lastResolveCookies = (typeof globalThis.__bidiResolveCookies === 'function' ? globalThis.__bidiResolveCookies('http://localhost/api/me') : '<no-fn>');",
  )
  let resp = read_global_string(proto, 4, "__lastResolveCookies")
  assert_false(resp.contains("sec=https-only"))
}

///|
/// Same-origin fetch runs the shim synchronously and attaches partition
/// cookies as the Cookie header. The shim short-circuits the
/// Promise.resolve preflight chain for same-origin so the stub captures the
/// outbound headers inline.
test "fetch shim attaches partition cookies to the actual outbound request" {
  let proto = make_proto_with_session()
  seed_storage_cookie(
    proto, 2, "{\"name\":\"sid\",\"value\":{\"type\":\"string\",\"value\":\"abc123\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
  )
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__lastCaptured = '<unset>';
    #|globalThis.__rawFetch = (url, options) => {
    #|  const h = new Headers((options && options.headers) || {});
    #|  globalThis.__lastCaptured = String(h.get('Cookie') || '');
    #|  return Promise.resolve({ status: 200, headers: { get: () => '*' }, text: () => Promise.resolve('') });
    #|};
    #|globalThis.fetch('/api/me');
    #|null
  run_sync_in_context(proto, 3, setup)
  let resp = read_global_string(proto, 4, "__lastCaptured")
  assert_true(resp.contains("sid=abc123"))
}

///|
/// A caller-supplied Cookie header must win over the bridge — the shim must
/// never silently overwrite explicit per-request cookie state.
test "fetch shim respects caller-provided Cookie header over bridge" {
  let proto = make_proto_with_session()
  seed_storage_cookie(
    proto, 2, "{\"name\":\"sid\",\"value\":{\"type\":\"string\",\"value\":\"bridge\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
  )
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__lastCaptured = '<unset>';
    #|globalThis.__rawFetch = (url, options) => {
    #|  const h = new Headers((options && options.headers) || {});
    #|  globalThis.__lastCaptured = String(h.get('Cookie') || '');
    #|  return Promise.resolve({ status: 200, headers: { get: () => '*' }, text: () => Promise.resolve('') });
    #|};
    #|globalThis.fetch('/api/me', { headers: { cookie: 'override=1' } });
    #|null
  run_sync_in_context(proto, 3, setup)
  let resp = read_global_string(proto, 4, "__lastCaptured")
  assert_true(resp.contains("override=1"))
  assert_false(resp.contains("sid=bridge"))
}

///|
/// Cross-origin POST + custom header triggers preflight. We assert the
/// method order [OPTIONS, POST] via a globalThis side log.
async test "fetch shim sends CORS preflight for non-simple cross-origin requests" {
  let proto = make_proto_with_session()
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__setRequestSandbox({ mode: 'open' });
    #|globalThis.__methodLog = '<unset>';
    #|const seen = [];
    #|globalThis.__rawFetch = (url, options) => {
    #|  const o = options || {};
    #|  const m = String(o.method || 'GET').toUpperCase();
    #|  seen.push(m);
    #|  globalThis.__methodLog = seen.join(',');
    #|  if (m === 'OPTIONS') {
    #|    return Promise.resolve({
    #|      status: 204,
    #|      headers: {
    #|        get: (name) => {
    #|          const n = String(name).toLowerCase();
    #|          if (n === 'access-control-allow-origin') return 'http://localhost';
    #|          if (n === 'access-control-allow-methods') return 'POST, GET';
    #|          if (n === 'access-control-allow-headers') return 'x-custom';
    #|          return null;
    #|        },
    #|      },
    #|      text: () => Promise.resolve(''),
    #|    });
    #|  }
    #|  return Promise.resolve({
    #|    status: 200,
    #|    headers: {
    #|      get: (name) => String(name).toLowerCase() === 'access-control-allow-origin' ? 'http://localhost' : null,
    #|    },
    #|    text: () => Promise.resolve(''),
    #|  });
    #|};
    #|globalThis.fetch('http://api.example.test/v1', {
    #|  method: 'POST',
    #|  headers: { 'X-Custom': '1', 'Content-Type': 'application/json' },
    #|  body: '{}',
    #|}).catch(() => {});
    #|null
  run_sync_in_context(proto, 2, setup)
  @async.sleep(10)
  let resp = read_global_string(proto, 5, "__methodLog")
  run_sync_in_context(
    proto, 6, "globalThis.__setRequestSandbox({ mode: 'same-origin' });",
  )
  assert_true(resp.contains("OPTIONS,POST"))
}

///|
/// Cross-origin simple GET (no custom headers) must NOT send a preflight —
/// guards against over-eager preflight that would double every cross-origin
/// request.
async test "fetch shim skips preflight for simple cross-origin GET" {
  let proto = make_proto_with_session()
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__setRequestSandbox({ mode: 'open' });
    #|globalThis.__methodLog = '<unset>';
    #|const seen = [];
    #|globalThis.__rawFetch = (url, options) => {
    #|  const o = options || {};
    #|  seen.push(String(o.method || 'GET').toUpperCase());
    #|  globalThis.__methodLog = seen.join(',');
    #|  return Promise.resolve({
    #|    status: 200,
    #|    headers: {
    #|      get: (name) => String(name).toLowerCase() === 'access-control-allow-origin' ? '*' : null,
    #|    },
    #|    text: () => Promise.resolve(''),
    #|  });
    #|};
    #|globalThis.fetch('http://api.example.test/v1').catch(() => {});
    #|null
  run_sync_in_context(proto, 2, setup)
  @async.sleep(10)
  let resp = read_global_string(proto, 4, "__methodLog")
  run_sync_in_context(
    proto, 5, "globalThis.__setRequestSandbox({ mode: 'same-origin' });",
  )
  assert_true(resp.contains("GET"))
  assert_false(resp.contains("OPTIONS"))
}

///|
/// Preflight that returns no ACA-Methods must fail with a CORS preflight
/// error and never dispatch the actual request.
async test "fetch shim rejects when preflight omits ACA-Methods" {
  let proto = make_proto_with_session()
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__setRequestSandbox({ mode: 'open' });
    #|globalThis.__methodLog = '<unset>';
    #|globalThis.__rejectionMsg = '<unset>';
    #|const seen = [];
    #|globalThis.__rawFetch = (url, options) => {
    #|  const o = options || {};
    #|  const m = String(o.method || 'GET').toUpperCase();
    #|  seen.push(m);
    #|  globalThis.__methodLog = seen.join(',');
    #|  if (m === 'OPTIONS') {
    #|    return Promise.resolve({
    #|      status: 204,
    #|      headers: {
    #|        get: (name) => {
    #|          const n = String(name).toLowerCase();
    #|          if (n === 'access-control-allow-origin') return 'http://localhost';
    #|          return null;
    #|        },
    #|      },
    #|      text: () => Promise.resolve(''),
    #|    });
    #|  }
    #|  return Promise.resolve({ status: 200, headers: { get: () => '*' }, text: () => Promise.resolve('') });
    #|};
    #|globalThis.fetch('http://api.example.test/v1', {
    #|  method: 'PUT',
    #|  headers: { 'Content-Type': 'application/json' },
    #|  body: '{}',
    #|}).then(() => { globalThis.__rejectionMsg = '<resolved>'; }, (err) => { globalThis.__rejectionMsg = String(err && err.message ? err.message : err); });
    #|null
  run_sync_in_context(proto, 2, setup)
  @async.sleep(10)
  let method_log = read_global_string(proto, 5, "__methodLog")
  let rejection = read_global_string(proto, 6, "__rejectionMsg")
  run_sync_in_context(
    proto, 7, "globalThis.__setRequestSandbox({ mode: 'same-origin' });",
  )
  assert_true(method_log.contains("OPTIONS"))
  assert_false(method_log.contains("PUT"))
  assert_true(rejection.contains("CORS preflight"))
  assert_true(rejection.contains("PUT not allowed"))
}

///|
/// Repeat cross-origin POST + custom header within Max-Age must hit the
/// preflight cache and skip the second OPTIONS dispatch. Pins
/// bug.runtime.fetch-preflight-cache-not-shared: the JS-side fetch shim now
/// memoizes OPTIONS responses with the same Max-Age clamp (7200s) as the
/// MoonBit http/cors PreflightCache. Expected method log on the wire across
/// two POSTs is OPTIONS,POST,POST — *not* OPTIONS,POST,OPTIONS,POST.
///
/// Per-test target URL `cache-hit-1.test` keeps the cache key unique and
/// the `seen` log isolated even when a prior async test's microtasks drain
/// into our `__rawFetch`.
async test "fetch shim caches preflight result and skips second OPTIONS within Max-Age" {
  let proto = make_proto_with_session()
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__setRequestSandbox({ mode: 'open' });
    #|globalThis.__bidiPreflightCache = new Map();
    #|globalThis.__cacheHitMethodLog = '<unset>';
    #|const seen = [];
    #|globalThis.__rawFetch = (url, options) => {
    #|  const o = options || {};
    #|  const m = String(o.method || 'GET').toUpperCase();
    #|  // Only record requests targeting this test's URL — keeps the log
    #|  // free of late-arriving microtasks from prior tests.
    #|  if (String(url).indexOf('cache-hit-1.test') !== -1) {
    #|    seen.push(m);
    #|    globalThis.__cacheHitMethodLog = seen.join(',');
    #|  }
    #|  if (m === 'OPTIONS') {
    #|    return Promise.resolve({
    #|      status: 204,
    #|      headers: {
    #|        get: (name) => {
    #|          const n = String(name).toLowerCase();
    #|          if (n === 'access-control-allow-origin') return 'http://localhost';
    #|          if (n === 'access-control-allow-methods') return 'POST, GET';
    #|          if (n === 'access-control-allow-headers') return 'x-custom';
    #|          if (n === 'access-control-max-age') return '3600';
    #|          return null;
    #|        },
    #|      },
    #|      text: () => Promise.resolve(''),
    #|    });
    #|  }
    #|  return Promise.resolve({
    #|    status: 200,
    #|    headers: {
    #|      get: (name) => String(name).toLowerCase() === 'access-control-allow-origin' ? 'http://localhost' : null,
    #|    },
    #|    text: () => Promise.resolve(''),
    #|  });
    #|};
    #|const opts = {
    #|  method: 'POST',
    #|  headers: { 'X-Custom': '1', 'Content-Type': 'application/json' },
    #|  body: '{}',
    #|};
    #|Promise.resolve()
    #|  .then(() => globalThis.fetch('http://cache-hit-1.test/v1', opts).catch(() => {}))
    #|  .then(() => globalThis.fetch('http://cache-hit-1.test/v1', opts).catch(() => {}));
    #|null
  run_sync_in_context(proto, 2, setup)
  @async.sleep(30)
  let resp = read_global_string(proto, 5, "__cacheHitMethodLog")
  run_sync_in_context(
    proto, 6, "globalThis.__setRequestSandbox({ mode: 'same-origin' });",
  )
  // Exactly one OPTIONS and two POSTs.
  assert_true(resp.contains("OPTIONS,POST,POST"))
  assert_false(resp.contains("OPTIONS,POST,OPTIONS"))
}

///|
/// Cache hit must still validate the allow-lists against the *current*
/// request. If the cached entry doesn't cover a new header, the shim evicts
/// the entry and refetches. Guards against the cache pinning a stale
/// permissive entry while the actual server is stricter.
async test "fetch shim preflight cache evicts entry when new header is not covered" {
  let proto = make_proto_with_session()
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__setRequestSandbox({ mode: 'open' });
    #|globalThis.__bidiPreflightCache = new Map();
    #|globalThis.__cacheEvictMethodLog = '<unset>';
    #|const seen = [];
    #|globalThis.__rawFetch = (url, options) => {
    #|  const o = options || {};
    #|  const m = String(o.method || 'GET').toUpperCase();
    #|  const reqHeaders = new Headers((o && o.headers) || {});
    #|  const requested = String(reqHeaders.get('Access-Control-Request-Headers') || '').toLowerCase();
    #|  if (String(url).indexOf('cache-evict-1.test') !== -1) {
    #|    seen.push(m);
    #|    globalThis.__cacheEvictMethodLog = seen.join(',');
    #|  }
    #|  if (m === 'OPTIONS') {
    #|    return Promise.resolve({
    #|      status: 204,
    #|      headers: {
    #|        get: (name) => {
    #|          const n = String(name).toLowerCase();
    #|          if (n === 'access-control-allow-origin') return 'http://localhost';
    #|          if (n === 'access-control-allow-methods') return 'POST, GET';
    #|          // Respond with only the headers actually requested — the
    #|          // first preflight (x-custom) caches a narrow entry; the
    #|          // second (x-extra) needs a fresh roundtrip.
    #|          if (n === 'access-control-allow-headers') return requested;
    #|          if (n === 'access-control-max-age') return '3600';
    #|          return null;
    #|        },
    #|      },
    #|      text: () => Promise.resolve(''),
    #|    });
    #|  }
    #|  return Promise.resolve({
    #|    status: 200,
    #|    headers: {
    #|      get: (name) => String(name).toLowerCase() === 'access-control-allow-origin' ? 'http://localhost' : null,
    #|    },
    #|    text: () => Promise.resolve(''),
    #|  });
    #|};
    #|Promise.resolve()
    #|  .then(() => globalThis.fetch('http://cache-evict-1.test/v1', {
    #|    method: 'POST',
    #|    headers: { 'X-Custom': '1', 'Content-Type': 'application/json' },
    #|    body: '{}',
    #|  }).catch(() => {}))
    #|  .then(() => globalThis.fetch('http://cache-evict-1.test/v1', {
    #|    method: 'POST',
    #|    headers: { 'X-Extra': '2', 'Content-Type': 'application/json' },
    #|    body: '{}',
    #|  }).catch(() => {}));
    #|null
  run_sync_in_context(proto, 2, setup)
  @async.sleep(30)
  let resp = read_global_string(proto, 5, "__cacheEvictMethodLog")
  run_sync_in_context(
    proto, 6, "globalThis.__setRequestSandbox({ mode: 'same-origin' });",
  )
  // First request keys cache on x-custom, second on x-extra — different
  // cache keys, so two OPTIONS expected.
  assert_true(resp.contains("OPTIONS,POST,OPTIONS,POST"))
}

///|
/// reset_runtime_js_state must drop the realm-scoped fetch-shim install-once
/// guard so that the next js_evaluate_expression re-wraps fetch cleanly.
/// Pins bug.runtime.fetch-install-once-realm-bound: without this drop, a
/// browsingContext.create / destroy cycle that reuses the same JS realm
/// would inherit __bidiFetchShimInstalled = true and leave __rawFetch
/// pointing at the previous session's stale stub. The reinstalled shim
/// would silently dispatch every fetch through that stale stub.
///
/// The test seeds a stub __rawFetch, marks the install flag set (mimicking
/// post-bootstrap realm state), then runs reset_runtime_js_state. The next
/// js_evaluate_expression bootstrap MUST observe the flag/raw as cleared
/// and reinstall, so __rawFetch ends up pointing at the realm's native
/// fetch, not the stub. We test this by calling globalThis.fetch on a
/// `data:` URL and confirming the response is the real fetch (data URL
/// resolved by Node) rather than the stub returning 'stub'.
async test "reset_runtime_js_state lets next bootstrap rebind __rawFetch to the realm fetch" {
  // Seed stale state directly via FFI, bypassing the bootstrap so the
  // flag/__rawFetch don't get re-derived from the current realm.
  let _ = evaluate_js(
    "globalThis.__staleSentinelFetch = () => Promise.resolve({ status: 599, text: () => Promise.resolve('stale-stub') }); globalThis.__rawFetch = globalThis.__staleSentinelFetch; globalThis.__bidiFetchShimInstalled = true; 0",
  )
  // Verify the seed: the bootstrap above the eval should leave the flag
  // alone because it was already true.
  let seeded = evaluate_js(
    "(globalThis.__rawFetch === globalThis.__staleSentinelFetch ? 'stale' : 'rebound')",
  )
  assert_true(seeded.contains("stale"))
  // Reset and confirm the install-once flag and __rawFetch are dropped.
  reset_runtime_js_state()
  // Next bootstrap reinstalls: __rawFetch must now point at the realm's
  // native fetch, not the stale stub.
  let rebound = evaluate_js(
    "(globalThis.__rawFetch === globalThis.__staleSentinelFetch ? 'stale' : 'rebound')",
  )
  assert_true(rebound.contains("rebound"))
}

///|
/// Seed an Authorization header for the given origin scoped to session-1.
fn seed_origin_authorization(
  proto : BidiProtocol,
  request_id : Int,
  origin : String,
  header_value : String,
) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":" +
    Json::string(origin).stringify() +
    ",\"headerValue\":" +
    Json::string(header_value).stringify() +
    ",\"context\":\"session-1\"}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Same-origin fetch must attach the registered Authorization header for
/// the resolved origin when the caller did not provide one. Pins the
/// origin-Authorization injection bridge wiring inside the fetch shim.
test "fetch shim attaches Authorization for matching origin" {
  let proto = make_proto_with_session()
  seed_origin_authorization(proto, 2, "http://localhost", "Bearer abc123")
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__lastAuthCaptured = '<unset>';
    #|globalThis.__rawFetch = (url, options) => {
    #|  const h = new Headers((options && options.headers) || {});
    #|  const v = h.get('Authorization');
    #|  globalThis.__lastAuthCaptured = v === null || v === undefined ? '<null>' : String(v);
    #|  return Promise.resolve({ status: 200, headers: { get: () => '*' }, text: () => Promise.resolve('') });
    #|};
    #|globalThis.fetch('/api/me');
    #|null
  run_sync_in_context(proto, 3, setup)
  let resp = read_global_string(proto, 4, "__lastAuthCaptured")
  assert_true(resp.contains("Bearer abc123"))
}

///|
/// A caller-supplied Authorization header must win over the bridge — the
/// shim must never silently overwrite an explicit per-request token.
test "fetch shim respects caller-provided Authorization over bridge" {
  let proto = make_proto_with_session()
  seed_origin_authorization(proto, 2, "http://localhost", "Bearer driver-token")
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__lastAuthCaptured = '<unset>';
    #|globalThis.__rawFetch = (url, options) => {
    #|  const h = new Headers((options && options.headers) || {});
    #|  const v = h.get('Authorization');
    #|  globalThis.__lastAuthCaptured = v === null || v === undefined ? '<null>' : String(v);
    #|  return Promise.resolve({ status: 200, headers: { get: () => '*' }, text: () => Promise.resolve('') });
    #|};
    #|globalThis.fetch('/api/me', { headers: { Authorization: 'Bearer page-token' } });
    #|null
  run_sync_in_context(proto, 3, setup)
  let resp = read_global_string(proto, 4, "__lastAuthCaptured")
  assert_true(resp.contains("Bearer page-token"))
  assert_false(resp.contains("driver-token"))
}

///|
/// An Authorization registered for one origin must not leak to a fetch
/// targeting a different origin. The shim resolves per-request via
/// __bidiResolveAuth which already filters by origin; this pins the
/// end-to-end wiring through the shim's attach block.
async test "fetch shim skips Authorization for non-matching origin" {
  let proto = make_proto_with_session()
  seed_origin_authorization(
    proto, 2, "https://api.example.com", "Bearer abc123",
  )
  let setup =
    #|globalThis.__pageUrl = 'http://localhost/';
    #|globalThis.__setRequestSandbox({ mode: 'open' });
    #|globalThis.__lastAuthCaptured = '<unset>';
    #|globalThis.__rawFetch = (url, options) => {
    #|  const h = new Headers((options && options.headers) || {});
    #|  const v = h.get('Authorization');
    #|  globalThis.__lastAuthCaptured = v === null || v === undefined ? '<null>' : String(v);
    #|  return Promise.resolve({
    #|    status: 200,
    #|    headers: {
    #|      get: (name) => String(name).toLowerCase() === 'access-control-allow-origin' ? '*' : null,
    #|    },
    #|    text: () => Promise.resolve(''),
    #|  });
    #|};
    #|globalThis.fetch('https://other.test/v1').catch(() => {});
    #|null
  run_sync_in_context(proto, 3, setup)
  @async.sleep(10)
  let resp = read_global_string(proto, 4, "__lastAuthCaptured")
  run_sync_in_context(
    proto, 5, "globalThis.__setRequestSandbox({ mode: 'same-origin' });",
  )
  assert_true(resp.contains("<null>"))
  assert_false(resp.contains("Bearer"))
}

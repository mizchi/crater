///|
/// ServiceWorker registration surface (#181).
///
/// PWAs / offline-capable apps call `navigator.serviceWorker.register(url)`
/// at boot and chain off the returned `ServiceWorkerRegistration`. The
/// Crater realm exposes a minimal-but-spec-shaped container so the boot
/// promise resolves and `navigator.serviceWorker.ready` settles, even
/// though the SW script itself never executes.
///
/// What's COVERED:
///
/// - `navigator.serviceWorker` exists with the spec property surface
/// - `register(url)` returns a resolved ServiceWorkerRegistration
/// - `ready` resolves with a registration whose `active` is a non-null
///   ServiceWorker
/// - `getRegistration` / `getRegistrations` work
///
/// What's NOT covered (out of scope for #181, future work):
///
/// - Actual execution of the SW script
/// - fetch interception by the worker
/// - Push notifications (pushManager.subscribe rejects with
///   NotSupportedError, which IS the spec response when push is
///   unavailable — pin it)
/// - Lifecycle events (install / activate / fetch / message)

///|
async test "navigator.serviceWorker.register resolves with a Registration" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__swStage = '<none>'; globalThis.__swErr = '<none>'; navigator.serviceWorker.register('/sw.js').then(reg => { globalThis.__swStage = 'registered:' + String(reg.scope) + ':' + String(reg.active && reg.active.scriptURL); }, err => { globalThis.__swErr = String(err); });",
  )
  @async.sleep(30)
  let stage = read_global_string(proto, 3, "__swStage")
  // Registration carries the scope and an active worker pointing back
  // at the supplied script URL.
  assert_true(stage.contains("registered:/:"))
  assert_true(stage.contains("/sw.js"))
}

///|
async test "navigator.serviceWorker.ready resolves with an active worker" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__swReady = '<none>'; navigator.serviceWorker.ready.then(reg => { globalThis.__swReady = 'ready:' + String(reg.active && reg.active.state); });",
  )
  @async.sleep(20)
  let resp = read_global_string(proto, 3, "__swReady")
  // The ready promise pre-resolves with the default registration whose
  // active worker is in the 'activated' state.
  assert_true(resp.contains("ready:activated"))
}

///|
async test "registered scope is retrievable via getRegistration" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__swScope = '<none>'; navigator.serviceWorker.register('/sw.js', { scope: '/app/' }).then(() => navigator.serviceWorker.getRegistration('/app/')).then(reg => { globalThis.__swScope = reg ? reg.scope : 'null'; });",
  )
  @async.sleep(30)
  let resp = read_global_string(proto, 3, "__swScope")
  assert_true(resp.contains("\"/app/\""))
}

///|
async test "getRegistrations returns the registered scopes" {
  let proto = make_proto_with_session()
  // The realm-wide registrations Map persists across tests in the same
  // moon-test invocation, so we can't assert on an exact set. Instead
  // we register two distinctive scopes and check both appear in the
  // returned list.
  run_sync_in_context(
    proto, 2, "globalThis.__swAll = '<none>'; Promise.all([ navigator.serviceWorker.register('/a.js', { scope: '/p181-a/' }), navigator.serviceWorker.register('/b.js', { scope: '/p181-b/' }), ]).then(() => navigator.serviceWorker.getRegistrations()).then(regs => { globalThis.__swAll = regs.map(r => r.scope).join('|'); });",
  )
  @async.sleep(40)
  let resp = read_global_string(proto, 3, "__swAll")
  assert_true(resp.contains("/p181-a/"))
  assert_true(resp.contains("/p181-b/"))
}

///|
async test "Registration.unregister resolves true" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__swUnreg = '<none>'; navigator.serviceWorker.register('/sw.js').then(reg => reg.unregister()).then(ok => { globalThis.__swUnreg = String(ok); });",
  )
  @async.sleep(30)
  let resp = read_global_string(proto, 3, "__swUnreg")
  assert_true(resp.contains("\"true\""))
}

///|
async test "pushManager.subscribe rejects with NotSupportedError" {
  let proto = make_proto_with_session()
  // The spec response when push is unavailable. Pinned so apps that
  // gracefully feature-detect via try/catch around subscribe() get a
  // consistent rejection rather than a hang.
  run_sync_in_context(
    proto, 2, "globalThis.__pushErr = '<none>'; navigator.serviceWorker.register('/sw.js').then(reg => reg.pushManager.subscribe()).then(() => { globalThis.__pushErr = 'unexpected-success'; }, err => { globalThis.__pushErr = String(err.name || err); });",
  )
  @async.sleep(30)
  let resp = read_global_string(proto, 3, "__pushErr")
  assert_true(resp.contains("\"NotSupportedError\""))
}

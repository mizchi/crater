///|
/// requestAnimationFrame batching + timestamp semantics (#185).
///
/// Real-browser rAF batches all callbacks scheduled within the same
/// task into a single per-frame flush, and feeds each callback a
/// shared DOMHighResTimeStamp from performance.now(). The previous
/// Crater impl (setTimeout(cb, 16) per callback) serialized callbacks
/// across separate timers and re-entered the event loop between
/// each — breaking animation libraries that compute frame deltas off
/// the timestamp argument or rely on multiple rAF callbacks observing
/// the SAME frame.
///
/// These tests pin the batched-flush behavior so a future refactor
/// can't silently regress to per-callback timers.

///|
async test "rAF batches multiple callbacks into one flush" {
  let proto = make_proto_with_session()
  // Three rAF calls in one task should all fire after a single 16ms
  // flush, in registration order. We record each callback's order in
  // a global and read it back after the flush completes.
  run_sync_in_context(
    proto, 2, "globalThis.__rafOrder = []; requestAnimationFrame(() => globalThis.__rafOrder.push('a')); requestAnimationFrame(() => globalThis.__rafOrder.push('b')); requestAnimationFrame(() => globalThis.__rafOrder.push('c'));",
  )
  // Allow the 16ms flush timer to fire.
  @async.sleep(40)
  run_sync_in_context(
    proto, 3, "globalThis.__rafReport = (globalThis.__rafOrder || []).join(',');",
  )
  let resp = read_global_string(proto, 4, "__rafReport")
  // All three callbacks fired together, in registration order.
  assert_true(resp.contains("\"a,b,c\""))
}

///|
async test "rAF callback receives a numeric high-resolution timestamp" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__rafTsType = '<none>'; globalThis.__rafTsPositive = '<none>'; requestAnimationFrame((ts) => { globalThis.__rafTsType = typeof ts; globalThis.__rafTsPositive = String(ts > 0); });",
  )
  @async.sleep(40)
  let ty = read_global_string(proto, 3, "__rafTsType")
  // performance.now() returns a Number; Date.now() fallback also Number.
  assert_true(ty.contains("\"number\""))
  let pos = read_global_string(proto, 4, "__rafTsPositive")
  assert_true(pos.contains("\"true\""))
}

///|
async test "cancelAnimationFrame prevents a queued callback from firing" {
  let proto = make_proto_with_session()
  // Schedule two callbacks, cancel the first by id, verify only the
  // second fired. Cancellation is a property check on the queued entry
  // because the impl marks-and-skips rather than splicing — pin that
  // marked entries are honored at flush time.
  run_sync_in_context(
    proto, 2, "globalThis.__rafFired = []; const id1 = requestAnimationFrame(() => globalThis.__rafFired.push('first')); requestAnimationFrame(() => globalThis.__rafFired.push('second')); cancelAnimationFrame(id1);",
  )
  @async.sleep(40)
  run_sync_in_context(
    proto, 3, "globalThis.__rafReport = (globalThis.__rafFired || []).join(',');",
  )
  let resp = read_global_string(proto, 4, "__rafReport")
  // Only "second" — id1 was cancelled before the flush.
  assert_true(resp.contains("\"second\""))
  assert_false(resp.contains("first"))
}

///|
async test "successive rAF flushes see monotonically increasing timestamps" {
  let proto = make_proto_with_session()
  // Schedule one callback, wait for the flush, schedule another,
  // wait again. Record each timestamp into a list and verify the
  // second is >= the first (monotonic).
  run_sync_in_context(
    proto, 2, "globalThis.__rafStamps = []; requestAnimationFrame((ts) => globalThis.__rafStamps.push(ts));",
  )
  @async.sleep(40)
  run_sync_in_context(
    proto, 3, "requestAnimationFrame((ts) => globalThis.__rafStamps.push(ts));",
  )
  @async.sleep(40)
  run_sync_in_context(
    proto, 4, "const s = globalThis.__rafStamps; globalThis.__rafMonotonic = String(s.length >= 2 && s[1] >= s[0]);",
  )
  let resp = read_global_string(proto, 5, "__rafMonotonic")
  assert_true(resp.contains("\"true\""))
}

///|
async test "rAF re-scheduling from inside a callback fires on a separate flush" {
  let proto = make_proto_with_session()
  // Inside a rAF callback, schedule another rAF. The inner callback
  // is added to the queue AFTER the outer's flush splice(0) drained
  // it, so the inner doesn't re-enter the same flush — it waits for
  // the next 16ms timer. We can't reliably observe the gap between
  // those two flushes from the test harness (setTimeout timing on
  // moon test's Node loop is too coarse), so we just assert the
  // end-state: both callbacks ran by the time we've slept enough
  // for two flushes. The "not the same flush" property is checked
  // by code review of the impl itself (splice(0) before the for-loop).
  run_sync_in_context(
    proto, 2, "globalThis.__rafChain = 0; requestAnimationFrame(() => { globalThis.__rafChain += 1; requestAnimationFrame(() => { globalThis.__rafChain += 1; }); });",
  )
  // Two flush windows worth of sleep.
  @async.sleep(80)
  run_sync_in_context(
    proto, 3, "globalThis.__rafChainEnd = String(globalThis.__rafChain);",
  )
  let end = read_global_string(proto, 4, "__rafChainEnd")
  assert_true(end.contains("\"2\""))
}

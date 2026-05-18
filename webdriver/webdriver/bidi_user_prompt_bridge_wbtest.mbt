///|
/// User-prompt bridge coverage. Pins the in-realm alert/confirm/prompt
/// shims to (a) resolve their return values from the per-context
/// `unhandledPromptBehavior` snapshot and (b) push observable
/// `browsingContext.userPromptOpened` events through the JS → MoonBit
/// drain at every script.evaluate boundary.
///
/// The flush hook fires from `apply_effective_viewport_to_runtime_context`,
/// which these tests trigger via the synthetic `__craterApplyViewport()`
/// expression (the same path used by the cookie-ingest tests).

///|
/// Helper: subscribe to a BiDi event on a specific context. Returns after
/// draining the success response from the outbox.
fn subscribe_event(
  proto : BidiProtocol,
  request_id : Int,
  event_name : String,
  ctx_id : String,
) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"session.subscribe\",\"params\":{\"events\":[\"" +
    event_name +
    "\"],\"contexts\":[\"" +
    ctx_id +
    "\"]}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Helper: build a session with a user-context-level
/// `unhandledPromptBehavior` set on `default`, returning the proto after
/// the session.new + setUnhandledPromptBehavior dance.
fn session_with_prompt_handlers(handlers_json_inner : String) -> BidiProtocol {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{\"alwaysMatch\":{\"unhandledPromptBehavior\":" +
    handlers_json_inner +
    "}}}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
/// Helper: drive the runtime-context lifecycle hook so the user-prompt
/// queue gets drained into BiDi events. Mirrors the cookie-ingest pattern.
fn fire_drain_hook(proto : BidiProtocol, ctx_id : String) -> Unit {
  proto.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
}

///|
/// Filter messages for events matching the given method name. Returns
/// the array of raw JSON strings.
fn collect_events(proto : BidiProtocol, ev : String) -> Array[String] {
  let out : Array[String] = []
  for msg in proto.take_messages() {
    let json = msg.to_json()
    if json.contains("\"method\":\"" + ev + "\"") {
      out.push(json)
    }
  }
  out
}

///|
/// Like `run_sync_in_context` but DOES NOT drain the outbox after sending
/// the script.evaluate payload, so the caller can inspect any events the
/// evaluate emitted (e.g. userPromptOpened from the in-realm bridge).
fn run_sync_in_context_keep(
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
}

///|
test "alert() in default-behavior session emits userPromptOpened with dismiss handler" {
  let proto = make_proto_with_session()
  subscribe_event(proto, 2, "browsingContext.userPromptOpened", "session-1")
  let _ = proto.take_messages()
  // The synthetic handler at try_handle_synthetic_user_prompt intercepts
  // expressions that START with `alert(` / `confirm(` / `prompt(` and
  // parks the request waiting for `browsingContext.handleUserPrompt`.
  // Wrap the call in a leading no-op so the in-realm bridge fires
  // instead — that's the path real pages hit when alert() is called
  // from event handlers, async callbacks, or library code.
  //
  // The bridge drain runs at the START of every script.evaluate
  // (apply_effective_viewport), so any events queued by this alert()
  // call fire at the NEXT script.evaluate, not this one. Trigger a
  // no-op second evaluate (kept so messages remain in the outbox)
  // to flush.
  run_sync_in_context(proto, 3, "void 0; alert('hello');")
  let _ = proto.take_messages()
  run_sync_in_context_keep(proto, 4, "void 0;")
  let events = collect_events(proto, "browsingContext.userPromptOpened")
  assert_true(events.length() >= 1)
  let payload = events[events.length() - 1]
  assert_true(payload.contains("\"type\":\"alert\""))
  assert_true(payload.contains("\"handler\":\"dismiss\""))
  assert_true(payload.contains("\"message\":\"hello\""))
}

///|
test "confirm() with default-dismiss behavior returns false synchronously" {
  let proto = make_proto_with_session()
  fire_drain_hook(proto, "session-1")
  let _ = proto.take_messages()
  run_sync_in_context(
    proto, 2, "globalThis.__confirmResult = String(confirm('proceed?'));",
  )
  let result = read_global_string(proto, 3, "__confirmResult")
  // Spec: dismiss → confirm returns false.
  assert_true(result.contains("\"false\""))
}

///|
test "prompt() with default-dismiss behavior returns null synchronously" {
  let proto = make_proto_with_session()
  fire_drain_hook(proto, "session-1")
  let _ = proto.take_messages()
  run_sync_in_context(
    proto, 2, "globalThis.__promptResult = String(prompt('name?', 'mizchi'));",
  )
  let result = read_global_string(proto, 3, "__promptResult")
  // Spec: dismiss → prompt returns null; String(null) = "null".
  assert_true(result.contains("\"null\""))
}

///|
test "confirm() with accept behavior returns true synchronously" {
  let proto = session_with_prompt_handlers(
    "{\"confirm\":\"accept\",\"default\":\"dismiss\"}",
  )
  fire_drain_hook(proto, "session-1")
  let _ = proto.take_messages()
  run_sync_in_context(
    proto, 2, "globalThis.__confirmResult = String(confirm('proceed?'));",
  )
  let result = read_global_string(proto, 3, "__confirmResult")
  assert_true(result.contains("\"true\""))
}

///|
test "prompt() with accept behavior returns the default value" {
  let proto = session_with_prompt_handlers(
    "{\"prompt\":\"accept\",\"default\":\"dismiss\"}",
  )
  fire_drain_hook(proto, "session-1")
  let _ = proto.take_messages()
  run_sync_in_context(
    proto, 2, "globalThis.__promptResult = String(prompt('name?', 'mizchi'));",
  )
  let result = read_global_string(proto, 3, "__promptResult")
  // accept + default value present → returns the default value string.
  assert_true(result.contains("\"mizchi\""))
}

///|
test "userPromptOpened event reports the resolved handler chosen at queue time" {
  let proto = session_with_prompt_handlers(
    "{\"confirm\":\"accept\",\"alert\":\"dismiss\",\"default\":\"dismiss\"}",
  )
  subscribe_event(proto, 2, "browsingContext.userPromptOpened", "session-1")
  let _ = proto.take_messages()
  // Wrap in `void` so the synthetic handler at script_eval.mbt:284
  // doesn't preempt the in-realm bridge. Flush via a follow-up no-op
  // evaluate (drain runs at apply_effective_viewport, which is the
  // START of every script.evaluate).
  run_sync_in_context(proto, 3, "void confirm('proceed?');")
  let _ = proto.take_messages()
  run_sync_in_context_keep(proto, 4, "void 0;")
  let events = collect_events(proto, "browsingContext.userPromptOpened")
  assert_true(events.length() >= 1)
  let payload = events[events.length() - 1]
  assert_true(payload.contains("\"type\":\"confirm\""))
  // The event records the handler the bridge actually applied — not
  // the global default — so observability matches the resolution.
  assert_true(payload.contains("\"handler\":\"accept\""))
}

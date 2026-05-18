///|
/// User-prompt bridge between the BiDi JS realm and MoonBit-side BiDi event
/// emission. Two responsibilities:
///
/// 1. Push the active `unhandledPromptBehavior` snapshot into the JS realm
///    so `globalThis.alert/confirm/prompt` can synchronously resolve a
///    return value matching the driver-configured policy.
/// 2. Drain the JS-side `__bidiPendingUserPrompts` queue at every
///    script.evaluate boundary and emit one `browsingContext.userPromptOpened`
///    BiDi event per queued entry, so consumers like Playwright's
///    `page.on('dialog')` observe the dialog.
///
/// Resolution semantics: Crater's headless realm cannot synchronously park
/// the page while it waits for an out-of-realm decision. The JS-side
/// alert/confirm/prompt therefore RESOLVE IMMEDIATELY based on the snapshot,
/// then queue a deferred event. Drivers that need control over the
/// resolution set unhandledPromptBehavior on session.new before any
/// page-side prompt fires.

///|
/// Build the JSON snapshot pushed to `globalThis.__bidiPromptHandlers` for
/// the given browsing context. The result is the resolved per-type handler
/// (alert / confirm / prompt) plus a `default` fallback, all selected via
/// `resolve_unhandled_prompt_handler` so the JS side never has to walk the
/// MoonBit-side user-context lookup itself.
fn BidiProtocol::serialize_prompt_handlers_snapshot_for_runtime(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let entries : Map[String, Json] = Map([], capacity=4)
  entries["alert"] = Json::string(
    self.resolve_unhandled_prompt_handler(ctx_id, "alert"),
  )
  entries["confirm"] = Json::string(
    self.resolve_unhandled_prompt_handler(ctx_id, "confirm"),
  )
  entries["prompt"] = Json::string(
    self.resolve_unhandled_prompt_handler(ctx_id, "prompt"),
  )
  entries["default"] = Json::string(
    self.resolve_unhandled_prompt_handler(ctx_id, "default"),
  )
  make_object(entries).stringify()
}

///|
/// Push the per-context prompt-handler snapshot to the JS realm.
fn BidiProtocol::push_prompt_handlers_snapshot(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let snapshot = self.serialize_prompt_handlers_snapshot_for_runtime(ctx_id)
  set_runtime_prompt_handlers(snapshot)
}

///|
/// Drain the JS-side pending-user-prompt buffer and emit one
/// `browsingContext.userPromptOpened` event per queued entry. Called at
/// every script.evaluate boundary so consumers see dialog observations
/// promptly (BiDi events are emitted on the next message dispatch).
///
/// The page-side return value was already resolved synchronously when
/// alert/confirm/prompt fired; this drain is purely observational.
fn BidiProtocol::flush_pending_user_prompts(self : BidiProtocol) -> Unit {
  let drained = drain_pending_user_prompts()
  if drained.length() == 0 || drained == "[]" {
    return
  }
  let parsed = @json.parse(drained) catch { _ => return }
  let entries = match parsed {
    Json::Array(items) => items
    _ => return
  }
  for entry in entries {
    let map = match entry {
      Json::Object(map) => map
      _ => continue
    }
    let ctx_id = match map.get("ctx") {
      Some(Json::String(value)) => value
      _ => continue
    }
    if !self.manager.has_session(ctx_id) {
      continue
    }
    let prompt_type = match map.get("type") {
      Some(Json::String(value)) => value
      _ => continue
    }
    let message = match map.get("message") {
      Some(Json::String(value)) => value
      _ => ""
    }
    let default_value : String? = match map.get("defaultValue") {
      Some(Json::String(value)) => Some(value)
      Some(Json::Null) => None
      _ => None
    }
    let handler = match map.get("handler") {
      Some(Json::String(value)) => value
      _ => self.resolve_unhandled_prompt_handler(ctx_id, prompt_type)
    }
    self.emit_user_prompt_opened(
      ctx_id, prompt_type, handler, message, default_value,
    )
  }
}

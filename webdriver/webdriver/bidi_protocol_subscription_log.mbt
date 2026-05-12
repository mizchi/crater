///|
/// Check whether events contain log subscriptions.
fn has_log_subscription(events : Array[String]) -> Bool {
  for evt in events {
    if evt == "log.entryAdded" || get_subscription_key(evt) == "log" {
      return true
    }
  }
  false
}

///|
/// Check whether console output should be captured for this context.
fn BidiProtocol::should_capture_console(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  if self.is_subscribed_for_context("log.entryAdded", ctx_id) ||
    self.subscription_state.has_any_log_subscription() {
    return true
  }
  // Keep capturing even when not currently subscribed so log.entryAdded
  // can be buffered and delivered after a later session.subscribe call.
  true
}

///|
/// Flush buffered log.entryAdded events that are now subscribed.
fn BidiProtocol::flush_pending_log_entries(self : BidiProtocol) -> Unit {
  let contexts : Array[String] = []
  for ctx_id, _ in self.subscription_state.pending_log_entries {
    contexts.push(ctx_id)
  }
  for ctx_id in contexts {
    if !self.is_subscribed_for_context("log.entryAdded", ctx_id) {
      continue
    }
    match self.subscription_state.pending_log_entries.get(ctx_id) {
      Some(entries) =>
        for params in entries {
          self.outbox.push(Event({ event_method: "log.entryAdded", params }))
        }
      None => ()
    }
    self.subscription_state.remove_pending_log_entries(ctx_id)
  }
}

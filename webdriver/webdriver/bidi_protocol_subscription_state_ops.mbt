///|
/// Remove a single stored subscription by id.
fn BidiProtocol::remove_subscription_by_id(
  self : BidiProtocol,
  subscription_id : String,
) -> Unit {
  let events = self.subscription_state.subscription_events
    .get(subscription_id)
    .unwrap_or([])
  let contexts = self.subscription_state.subscription_contexts
    .get(subscription_id)
    .unwrap_or([])
  let user_contexts = self.subscription_state.subscription_user_contexts
    .get(subscription_id)
    .unwrap_or([])
  if events.length() == 0 {
    self.subscription_state.subscription_events.remove(subscription_id)
    self.subscription_state.subscription_contexts.remove(subscription_id)
    self.subscription_state.subscription_user_contexts.remove(subscription_id)
    return
  }
  if contexts.length() > 0 {
    for ctx_id in contexts {
      match self.subscription_state.context_subscriptions.get(ctx_id) {
        Some(existing) => {
          let filtered = array_remove_events_once(existing, events)
          if filtered.length() == 0 {
            self.subscription_state.context_subscriptions.remove(ctx_id)
          } else {
            self.subscription_state.context_subscriptions[ctx_id] = filtered
          }
        }
        None => ()
      }
    }
  } else if user_contexts.length() > 0 {
    for user_ctx_id in user_contexts {
      match
        self.subscription_state.user_context_subscriptions.get(user_ctx_id) {
        Some(existing) => {
          let filtered = array_remove_events_once(existing, events)
          if filtered.length() == 0 {
            self.subscription_state.user_context_subscriptions.remove(
              user_ctx_id,
            )
          } else {
            self.subscription_state.user_context_subscriptions[user_ctx_id] = filtered
          }
        }
        None => ()
      }
    }
  } else {
    for evt in events {
      self.subscription_state.global_subscriptions = array_remove_first(
        self.subscription_state.global_subscriptions,
        evt,
      )
      let module_key = get_subscription_key(evt)
      self.subscription_state.update_legacy_module_subscription(module_key)
    }
  }
  self.subscription_state.subscription_events.remove(subscription_id)
  self.subscription_state.subscription_contexts.remove(subscription_id)
  self.subscription_state.subscription_user_contexts.remove(subscription_id)
}

///|
/// Normalize a subscribed context to its top-level browsing context.
fn BidiProtocol::normalize_subscription_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => self.normalize_subscription_context(parent_ctx_id)
    None => ctx_id
  }
}

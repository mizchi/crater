///|
/// Handle session.unsubscribe params
fn BidiProtocol::handle_unsubscribe(
  self : BidiProtocol,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(map)) => {
      // Subscription-based unsubscription takes precedence over event filters.
      let subscriptions_to_unsub : Array[String] = []
      match map.get("subscriptions") {
        Some(Array(subscriptions)) =>
          for sub in subscriptions {
            match sub {
              String(subscription_id) =>
                subscriptions_to_unsub.push(subscription_id)
              _ => ()
            }
          }
        _ => ()
      }
      if subscriptions_to_unsub.length() > 0 {
        for subscription_id in subscriptions_to_unsub {
          self.remove_subscription_by_id(subscription_id)
        }
        return
      }
      // Get events to unsubscribe from
      let events_to_unsub : Array[String] = []
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => events_to_unsub.push(s)
              _ => ()
            }
          }
        _ => ()
      }
      let contexts_to_unsub : Array[String] = []
      match map.get("contexts") {
        Some(Array(contexts)) =>
          for ctx in contexts {
            match ctx {
              String(ctx_id) =>
                contexts_to_unsub.push(
                  self.normalize_subscription_context(ctx_id),
                )
              _ => ()
            }
          }
        _ => ()
      }
      let user_contexts_to_unsub : Array[String] = []
      match get_map_field_with_alias(map, "userContexts", "user_contexts") {
        Some(Array(user_contexts)) =>
          for user_ctx in user_contexts {
            match user_ctx {
              String(user_ctx_id) => user_contexts_to_unsub.push(user_ctx_id)
              _ => ()
            }
          }
        _ => ()
      }
      let has_context_targets = contexts_to_unsub.length() > 0
      let has_user_context_targets = user_contexts_to_unsub.length() > 0
      if has_context_targets {
        for ctx_id in contexts_to_unsub {
          match self.subscription_state.context_subscriptions.get(ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, events_to_unsub)
              self.subscription_state.context_subscriptions[ctx_id] = filtered
            }
            None => ()
          }
        }
      }
      if has_user_context_targets {
        for user_ctx_id in user_contexts_to_unsub {
          match
            self.subscription_state.user_context_subscriptions.get(user_ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, events_to_unsub)
              self.subscription_state.user_context_subscriptions[user_ctx_id] = filtered
            }
            None => ()
          }
        }
      }
      if !has_context_targets && !has_user_context_targets {
        self.subscription_state.global_subscriptions = array_filter_not(
          self.subscription_state.global_subscriptions,
          events_to_unsub,
        )
        for evt in events_to_unsub {
          let module_key = get_subscription_key(evt)
          if module_key == evt {
            self.subscription_state.global_unsubscribed_events = array_filter_by_module(
              self.subscription_state.global_unsubscribed_events,
              module_key,
            )
          } else if !array_contains(
              self.subscription_state.global_unsubscribed_events,
              evt,
            ) {
            self.subscription_state.global_unsubscribed_events.push(evt)
          }
          self.subscription_state.update_legacy_module_subscription(module_key)
        }
      }
    }
    _ => ()
  }
}

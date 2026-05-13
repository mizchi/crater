///|
/// Handle session.subscribe params
fn BidiProtocol::handle_subscribe(
  self : BidiProtocol,
  params : Json?,
) -> String {
  let events_to_sub : Array[String] = []
  let contexts_to_sub : Array[String] = []
  let user_contexts_to_sub : Array[String] = []
  match params {
    Some(Object(map)) => {
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => events_to_sub.push(s)
              _ => ()
            }
          }
        _ => ()
      }
      match map.get("contexts") {
        Some(Array(contexts)) =>
          for ctx in contexts {
            match ctx {
              String(ctx_id) =>
                contexts_to_sub.push(
                  self.normalize_subscription_context(ctx_id),
                )
              _ => ()
            }
          }
        _ => ()
      }
      match get_map_field_with_alias(map, "userContexts", "user_contexts") {
        Some(Array(user_contexts)) =>
          for user_ctx in user_contexts {
            match user_ctx {
              String(user_ctx_id) => user_contexts_to_sub.push(user_ctx_id)
              _ => ()
            }
          }
        _ => ()
      }
      let mut wants_realm_created = false
      let mut wants_context_created = false
      for evt in events_to_sub {
        if evt == "script.realmCreated" || get_subscription_key(evt) == "script" {
          wants_realm_created = true
        }
        if evt == "browsingContext.contextCreated" ||
          get_subscription_key(evt) == "browsingContext" {
          wants_context_created = true
        }
      }
      let has_context_targets = contexts_to_sub.length() > 0
      let has_user_context_targets = user_contexts_to_sub.length() > 0
      if has_context_targets {
        for ctx_id in contexts_to_sub {
          let existing = self.subscription_state.context_subscriptions
            .get(ctx_id)
            .unwrap_or([])
          for evt in events_to_sub {
            existing.push(evt)
          }
          self.subscription_state.context_subscriptions[ctx_id] = existing
          if wants_realm_created {
            self.emit_existing_realms_for_context(ctx_id)
          }
          if wants_context_created {
            self.emit_existing_context_created_tree(ctx_id)
          }
        }
      }
      if has_user_context_targets {
        for user_ctx_id in user_contexts_to_sub {
          let existing = self.subscription_state.user_context_subscriptions
            .get(user_ctx_id)
            .unwrap_or([])
          for evt in events_to_sub {
            existing.push(evt)
          }
          self.subscription_state.user_context_subscriptions[user_ctx_id] = existing
          if wants_realm_created {
            for ctx_id in self.manager.list_sessions() {
              let ctx_user_ctx = self.context_user_context
                .get(ctx_id)
                .unwrap_or("default")
              if ctx_user_ctx == user_ctx_id &&
                self.context_parent.get(ctx_id) == None {
                self.emit_existing_realms_for_context(ctx_id)
              }
            }
          }
          if wants_context_created {
            for ctx_id in self.manager.list_sessions() {
              let ctx_user_ctx = self.context_user_context
                .get(ctx_id)
                .unwrap_or("default")
              if ctx_user_ctx == user_ctx_id &&
                self.context_parent.get(ctx_id) == None {
                self.emit_existing_context_created_tree(ctx_id)
              }
            }
          }
        }
      }
      if !has_context_targets && !has_user_context_targets {
        for evt in events_to_sub {
          let module_key = get_subscription_key(evt)
          if module_key == evt {
            self.subscription_state.global_unsubscribed_events = array_filter_by_module(
              self.subscription_state.global_unsubscribed_events,
              module_key,
            )
          } else {
            self.subscription_state.global_unsubscribed_events = array_filter_not(
              self.subscription_state.global_unsubscribed_events,
              [evt],
            )
          }
          self.subscription_state.global_subscriptions.push(evt)
          self.subscription_state.update_legacy_module_subscription(module_key)
        }
        if wants_realm_created {
          for ctx_id in self.manager.list_sessions() {
            if self.context_parent.get(ctx_id) == None {
              self.emit_existing_realms_for_context(ctx_id)
            }
          }
        }
        // For global subscriptions we do not eagerly replay existing
        // browsingContext.contextCreated events. Replaying here leaves stale
        // contextCreated entries queued before later create/window.open events
        // and breaks WPT ordering expectations for wait_for_event.
      }
      if has_log_subscription(events_to_sub) {
        self.flush_pending_log_entries()
      }
    }
    _ => ()
  }
  let subscription_id = self.subscription_state.generate_subscription_id()
  self.subscription_state.subscription_events[subscription_id] = events_to_sub
  self.subscription_state.subscription_contexts[subscription_id] = contexts_to_sub
  self.subscription_state.subscription_user_contexts[subscription_id] = user_contexts_to_sub
  subscription_id
}

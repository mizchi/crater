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

///|
/// Check if subscribed to event for a specific context
fn BidiProtocol::is_subscribed_for_context(
  self : BidiProtocol,
  event : String,
  ctx_id : String,
) -> Bool {
  let module_key = get_subscription_key(event)
  let blocked_global = array_contains(
    self.subscription_state.global_unsubscribed_events,
    event,
  )
  // Check legacy module-level subscription
  if !blocked_global &&
    self.subscription_state.subscriptions.get(module_key).unwrap_or(false) {
    return true
  }
  // Check global subscriptions (exact event match or module match)
  for sub in self.subscription_state.global_subscriptions {
    if sub == event {
      return true
    }
    if !blocked_global && sub == module_key {
      return true
    }
  }
  // Check context-specific subscriptions (including ancestors).
  if self.is_subscribed_for_context_chain(event, module_key, ctx_id) {
    return true
  }
  // Check user-context subscriptions for this browsing context.
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  match self.subscription_state.user_context_subscriptions.get(user_ctx) {
    Some(events) =>
      for sub in events {
        if sub == event || sub == module_key {
          return true
        }
      }
    None => ()
  }
  false
}

///|
/// Check context-specific subscriptions for context and its ancestors.
fn BidiProtocol::is_subscribed_for_context_chain(
  self : BidiProtocol,
  event : String,
  module_key : String,
  ctx_id : String,
) -> Bool {
  match self.subscription_state.context_subscriptions.get(ctx_id) {
    Some(events) =>
      for sub in events {
        if sub == event || sub == module_key {
          return true
        }
      }
    None => ()
  }
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) =>
      self.is_subscribed_for_context_chain(event, module_key, parent_ctx_id)
    None => false
  }
}

///|
/// Normalize subscription key
fn get_subscription_key(name : String) -> String {
  let buf = StringBuilder::new()
  for c in name.iter() {
    if c == '.' {
      break
    }
    buf.write_char(c)
  }
  let key = buf.to_string()
  if key.length() == 0 {
    name
  } else {
    key
  }
}

///|
/// Check whether module is globally subscribed as a module key.
fn BidiProtocol::has_global_module_subscription(
  self : BidiProtocol,
  module_key : String,
) -> Bool {
  array_contains(self.subscription_state.global_subscriptions, module_key)
}

///|
/// Check whether event is effectively globally subscribed.
fn BidiProtocol::has_global_event_subscription(
  self : BidiProtocol,
  event_name : String,
) -> Bool {
  if array_contains(
      self.subscription_state.global_unsubscribed_events,
      event_name,
    ) {
    return false
  }
  let module_key = get_subscription_key(event_name)
  for sub in self.subscription_state.global_subscriptions {
    if sub == event_name || sub == module_key {
      return true
    }
  }
  false
}

///|
/// Check whether module has any event-level global overrides.
fn BidiProtocol::has_global_event_override_for_module(
  self : BidiProtocol,
  module_key : String,
) -> Bool {
  for event_name in self.subscription_state.global_unsubscribed_events {
    if get_subscription_key(event_name) == module_key {
      return true
    }
  }
  false
}

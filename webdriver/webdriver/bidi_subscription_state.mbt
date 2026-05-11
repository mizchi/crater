///|
/// WebDriver BiDi session subscription state.
///
/// This keeps event subscriptions and buffered event delivery state outside of
/// the protocol command dispatcher.
priv struct BidiSubscriptionState {
  subscriptions : Map[String, Bool] // module-level subscriptions (legacy)
  context_subscriptions : Map[String, Array[String]] // context -> events
  user_context_subscriptions : Map[String, Array[String]] // user context -> events
  mut global_subscriptions : Array[String] // events subscribed globally
  mut global_unsubscribed_events : Array[String] // event-level overrides for module subscriptions
  subscription_events : Map[String, Array[String]] // subscription id -> events
  subscription_contexts : Map[String, Array[String]] // subscription id -> contexts
  subscription_user_contexts : Map[String, Array[String]] // subscription id -> user contexts
  mut next_subscription_id : Int
  pending_log_entries : Map[String, Array[Json]] // context -> buffered log.entryAdded params
}

///|
fn BidiSubscriptionState::new() -> BidiSubscriptionState {
  {
    subscriptions: {},
    context_subscriptions: {},
    user_context_subscriptions: {},
    global_subscriptions: [],
    global_unsubscribed_events: [],
    subscription_events: {},
    subscription_contexts: {},
    subscription_user_contexts: {},
    next_subscription_id: 1,
    pending_log_entries: {},
  }
}

///|
fn BidiSubscriptionState::reset(self : BidiSubscriptionState) -> Unit {
  let legacy_keys : Array[String] = []
  for key, _ in self.subscriptions {
    legacy_keys.push(key)
  }
  for key in legacy_keys {
    self.subscriptions.remove(key)
  }

  let context_keys : Array[String] = []
  for key, _ in self.context_subscriptions {
    context_keys.push(key)
  }
  for key in context_keys {
    self.context_subscriptions.remove(key)
  }

  let user_context_keys : Array[String] = []
  for key, _ in self.user_context_subscriptions {
    user_context_keys.push(key)
  }
  for key in user_context_keys {
    self.user_context_subscriptions.remove(key)
  }

  let subscription_keys : Array[String] = []
  for key, _ in self.subscription_events {
    subscription_keys.push(key)
  }
  for key in subscription_keys {
    self.subscription_events.remove(key)
    self.subscription_contexts.remove(key)
    self.subscription_user_contexts.remove(key)
  }

  let pending_log_keys : Array[String] = []
  for key, _ in self.pending_log_entries {
    pending_log_keys.push(key)
  }
  for key in pending_log_keys {
    self.pending_log_entries.remove(key)
  }

  self.global_subscriptions = []
  self.global_unsubscribed_events = []
  self.next_subscription_id = 1
}

///|
fn BidiSubscriptionState::has_subscription_id(
  self : BidiSubscriptionState,
  subscription_id : String,
) -> Bool {
  self.subscription_events.contains(subscription_id)
}

///|
fn BidiSubscriptionState::buffer_log_entry(
  self : BidiSubscriptionState,
  ctx_id : String,
  params : Json,
) -> Unit {
  let pending = self.pending_log_entries.get(ctx_id).unwrap_or([])
  pending.push(params)
  self.pending_log_entries[ctx_id] = pending
}

///|
fn BidiSubscriptionState::remove_pending_log_entries(
  self : BidiSubscriptionState,
  ctx_id : String,
) -> Unit {
  self.pending_log_entries.remove(ctx_id)
}

///|
fn BidiSubscriptionState::has_any_log_subscription(
  self : BidiSubscriptionState,
) -> Bool {
  if self.subscriptions.get("log").unwrap_or(false) {
    return true
  }
  if has_log_subscription(self.global_subscriptions) {
    return true
  }
  for _, events in self.context_subscriptions {
    if has_log_subscription(events) {
      return true
    }
  }
  for _, events in self.user_context_subscriptions {
    if has_log_subscription(events) {
      return true
    }
  }
  false
}

///|
fn BidiSubscriptionState::update_legacy_module_subscription(
  self : BidiSubscriptionState,
  module_key : String,
) -> Unit {
  let mut has_same_module = false
  for sub in self.global_subscriptions {
    if sub == module_key {
      has_same_module = true
      break
    }
  }
  if has_same_module {
    self.subscriptions[module_key] = true
  } else {
    self.subscriptions.remove(module_key)
  }
}

///|
fn BidiSubscriptionState::generate_subscription_id(
  self : BidiSubscriptionState,
) -> String {
  let id_num = self.next_subscription_id
  self.next_subscription_id += 1
  left_pad_with_zero(id_num.to_string(), 32)
}

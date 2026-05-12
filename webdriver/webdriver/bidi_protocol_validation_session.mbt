///|
/// Validate session.subscribe params.
/// Returns Some(()) when an error response was already sent.
fn BidiProtocol::validate_session_subscribe_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  match map.get("events") {
    Some(Array(raw_events)) => {
      if raw_events.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "events must not be an empty array",
        )
        return Some(())
      }
      for raw_event in raw_events {
        match raw_event {
          String(event_name) =>
            if !is_valid_session_subscription_event_name(event_name) {
              self.send_error(
                request_id,
                "invalid argument",
                "Unknown event name: " + event_name,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "events entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "events must be an array")
      return Some(())
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing events")
      return Some(())
    }
  }

  let mut has_context_targets = false
  match map.get("contexts") {
    Some(Array(raw_contexts)) => {
      has_context_targets = true
      if raw_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return Some(())
      }
      for raw_context in raw_contexts {
        match raw_context {
          String(ctx_id) =>
            if !self.manager.has_session(ctx_id) {
              self.send_error(
                request_id,
                "no such frame",
                "Unknown context: " + ctx_id,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  let mut has_user_context_targets = false
  match get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Array(raw_user_contexts)) => {
      has_user_context_targets = true
      if raw_user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in raw_user_contexts {
        match raw_user_context {
          String(user_context_id) =>
            if !self.user_contexts.get(user_context_id).unwrap_or(false) {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  if has_context_targets && has_user_context_targets {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return Some(())
  }

  None
}

///|
/// Validate session.unsubscribe params.
/// Returns Some(()) when an error response was already sent.
fn BidiProtocol::validate_session_unsubscribe_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  let mut has_subscriptions_field = false
  match map.get("subscriptions") {
    Some(Array(raw_subscriptions)) => {
      has_subscriptions_field = true
      if raw_subscriptions.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "subscriptions must not be an empty array",
        )
        return Some(())
      }
      for raw_subscription in raw_subscriptions {
        match raw_subscription {
          String(subscription_id) => {
            if !is_valid_subscription_id_format(subscription_id) {
              self.send_error(
                request_id,
                "invalid argument",
                "Invalid subscription id format: " + subscription_id,
              )
              return Some(())
            }
            if !self.subscription_state.has_subscription_id(subscription_id) {
              self.send_error(
                request_id,
                "invalid argument",
                "Unknown subscription id: " + subscription_id,
              )
              return Some(())
            }
          }
          _ => {
            self.send_error(
              request_id, "invalid argument", "subscriptions entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "subscriptions must be an array",
      )
      return Some(())
    }
    None => ()
  }

  if has_subscriptions_field {
    // When subscriptions are provided they take precedence over event filters.
    return None
  }

  let events_to_unsub : Array[String] = []
  match map.get("events") {
    Some(Array(raw_events)) => {
      if raw_events.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "events must not be an empty array",
        )
        return Some(())
      }
      for raw_event in raw_events {
        match raw_event {
          String(event_name) =>
            if !is_valid_session_subscription_event_name(event_name) {
              self.send_error(
                request_id,
                "invalid argument",
                "Unknown event name: " + event_name,
              )
              return Some(())
            } else {
              events_to_unsub.push(event_name)
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "events entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "events must be an array")
      return Some(())
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Either events or subscriptions must be provided",
      )
      return Some(())
    }
  }

  let mut has_context_targets = false
  match map.get("contexts") {
    Some(Array(raw_contexts)) => {
      has_context_targets = true
      if raw_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return Some(())
      }
      for raw_context in raw_contexts {
        match raw_context {
          String(_) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  let mut has_user_context_targets = false
  match get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Array(raw_user_contexts)) => {
      has_user_context_targets = true
      if raw_user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in raw_user_contexts {
        match raw_user_context {
          String(_) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  if !has_context_targets && !has_user_context_targets {
    for event_name in events_to_unsub {
      let module_key = get_subscription_key(event_name)
      if module_key == event_name {
        if !self.has_global_module_subscription(module_key) {
          self.send_error(
            request_id,
            "invalid argument",
            "No global subscription for module: " + module_key,
          )
          return Some(())
        }
        if self.has_global_event_override_for_module(module_key) {
          self.send_error(
            request_id,
            "invalid argument",
            "Cannot unsubscribe module after partial event unsubscription: " +
            module_key,
          )
          return Some(())
        }
      } else if !self.has_global_event_subscription(event_name) {
        self.send_error(
          request_id,
          "invalid argument",
          "No global subscription for event: " + event_name,
        )
        return Some(())
      }
    }
  }

  None
}

///|
/// Supported event/module names accepted by session.{subscribe,unsubscribe}.
fn is_valid_session_subscription_event_name(name : String) -> Bool {
  if name == "browsingContext" ||
    name == "script" ||
    name == "log" ||
    name == "network" ||
    name == "input" ||
    name == "storage" ||
    name == "browser" ||
    name == "bluetooth" ||
    name == "permissions" ||
    name == "session" ||
    name == "webExtension" ||
    name == "speculation" {
    return true
  }

  match name {
    "browsingContext.contextCreated" => true
    "browsingContext.contextDestroyed" => true
    "browsingContext.domContentLoaded" => true
    "browsingContext.load" => true
    "browsingContext.navigationStarted" => true
    "browsingContext.navigationFailed" => true
    "browsingContext.navigationAborted" => true
    "browsingContext.navigationCommitted" => true
    "browsingContext.fragmentNavigated" => true
    "browsingContext.historyUpdated" => true
    "browsingContext.downloadWillBegin" => true
    "browsingContext.downloadEnd" => true
    "browsingContext.userPromptOpened" => true
    "browsingContext.userPromptClosed" => true
    "log.entryAdded" => true
    "script.realmCreated" => true
    "script.realmDestroyed" => true
    "script.message" => true
    "network.beforeRequestSent" => true
    "network.responseStarted" => true
    "network.responseCompleted" => true
    "network.fetchError" => true
    "network.authRequired" => true
    "input.fileDialogOpened" => true
    "bluetooth.requestDevicePromptUpdated" => true
    "bluetooth.gattConnectionAttempted" => true
    "bluetooth.characteristicEventGenerated" => true
    "bluetooth.descriptorEventGenerated" => true
    "speculation.prefetchStatusUpdated" => true
    _ => false
  }
}

///|
/// Validate 32-char hex subscription id format.
fn is_valid_subscription_id_format(subscription_id : String) -> Bool {
  if subscription_id.length() != 32 {
    return false
  }
  for c in subscription_id.iter() {
    if !((c >= '0' && c <= '9') ||
      (c >= 'a' && c <= 'f') ||
      (c >= 'A' && c <= 'F')) {
      return false
    }
  }
  true
}

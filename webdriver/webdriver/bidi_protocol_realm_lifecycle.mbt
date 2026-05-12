///|
/// Assign a new realm id for a browsing context.
fn BidiProtocol::assign_new_realm(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_realm.get(ctx_id) {
    Some(old_realm) => {
      let owner_ctx = self.realm_context.get(old_realm).unwrap_or(ctx_id)
      self.emit_realm_destroyed_for_context(old_realm, owner_ctx)
      self.realm_context.remove(old_realm)
      self.realm_sandbox.remove(old_realm)
    }
    None => ()
  }
  let realm_id = "realm-" + self.next_realm_id.to_string()
  self.next_realm_id += 1
  self.context_realm[ctx_id] = realm_id
  self.realm_context[realm_id] = ctx_id
  realm_id
}

///|
/// Compute key for sandbox realm mapping.
fn make_sandbox_key(ctx_id : String, sandbox_name : String) -> String {
  ctx_id + "::" + sandbox_name
}

///|
/// Clear sandbox realms for a context.
fn BidiProtocol::clear_context_sandbox_realms(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.clear_context_sandbox_realms_with_events(ctx_id, false)
}

///|
/// Clear sandbox realms for a context and optionally emit realmDestroyed.
fn BidiProtocol::clear_context_sandbox_realms_with_events(
  self : BidiProtocol,
  ctx_id : String,
  emit_events : Bool,
) -> Unit {
  let prefix = ctx_id + "::"
  let to_remove : Array[String] = []
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      to_remove.push(key)
      if emit_events {
        self.emit_realm_destroyed_for_context(realm_id, ctx_id)
      }
      self.realm_context.remove(realm_id)
      self.realm_sandbox.remove(realm_id)
    }
  }
  for key in to_remove {
    self.context_sandbox_realm.remove(key)
  }
}

///|
/// Remove all realms owned by a context and emit realmDestroyed events.
fn BidiProtocol::remove_all_realms_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let owned_realms : Array[String] = []
  match self.context_realm.get(ctx_id) {
    Some(realm_id) => owned_realms.push(realm_id)
    None => ()
  }
  let prefix = ctx_id + "::"
  let sandbox_keys : Array[String] = []
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      sandbox_keys.push(key)
      let mut found = false
      for existing in owned_realms {
        if existing == realm_id {
          found = true
          break
        }
      }
      if !found {
        owned_realms.push(realm_id)
      }
    }
  }
  for key in sandbox_keys {
    self.context_sandbox_realm.remove(key)
  }
  match self.context_worker_realms.get(ctx_id) {
    Some(worker_realms) =>
      for realm_id in worker_realms {
        let mut found = false
        for existing in owned_realms {
          if existing == realm_id {
            found = true
            break
          }
        }
        if !found {
          owned_realms.push(realm_id)
        }
      }
    None => ()
  }
  for realm_id, owner_ctx in self.realm_context {
    if owner_ctx == ctx_id {
      let mut found = false
      for existing in owned_realms {
        if existing == realm_id {
          found = true
          break
        }
      }
      if !found {
        owned_realms.push(realm_id)
      }
    }
  }
  for realm_id in owned_realms {
    self.emit_realm_destroyed_for_context(realm_id, ctx_id)
    self.realm_context.remove(realm_id)
    self.realm_sandbox.remove(realm_id)
  }
  self.context_worker_realms.remove(ctx_id)
  self.context_realm.remove(ctx_id)
}

///|
/// Get or create a sandbox realm for a context.
fn BidiProtocol::get_or_create_sandbox_realm(
  self : BidiProtocol,
  ctx_id : String,
  sandbox_name : String,
) -> String {
  let key = make_sandbox_key(ctx_id, sandbox_name)
  match self.context_sandbox_realm.get(key) {
    Some(realm_id) => realm_id
    None => {
      let realm_id = "realm-" + self.next_realm_id.to_string()
      self.next_realm_id += 1
      self.context_sandbox_realm[key] = realm_id
      self.realm_context[realm_id] = ctx_id
      self.realm_sandbox[realm_id] = sandbox_name
      self.emit_realm_created(ctx_id, realm_id, Some(sandbox_name))
      realm_id
    }
  }
}

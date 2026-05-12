///|
/// Emit worker realmCreated event derived from script source.
fn BidiProtocol::emit_worker_realm_created(
  self : BidiProtocol,
  owner_ctx_id : String,
  worker_type : String,
  worker_origin : String,
  owner_realm_id : String,
) -> String? {
  let event_name = "script.realmCreated"
  if !self.is_subscribed_for_context(event_name, owner_ctx_id) {
    return None
  }
  let worker_realm_id = "realm-" + self.next_realm_id.to_string()
  self.next_realm_id += 1
  self.realm_context[worker_realm_id] = owner_ctx_id
  let worker_realms = self.context_worker_realms.get(owner_ctx_id).unwrap_or([])
  worker_realms.push(worker_realm_id)
  self.context_worker_realms[owner_ctx_id] = worker_realms
  let params = if worker_type == "dedicated-worker" {
    let owners : Array[Json] = []
    owners.push(Json::string(owner_realm_id))
    make_object({
      "realm": Json::string(worker_realm_id),
      "type": Json::string(worker_type),
      "origin": Json::string(worker_origin),
      "owners": Json::array(owners),
    })
  } else {
    make_object({
      "realm": Json::string(worker_realm_id),
      "type": Json::string(worker_type),
      "origin": Json::string(worker_origin),
    })
  }
  self.outbox.push(Event({ event_method: event_name, params }))
  Some(worker_realm_id)
}

///|
/// Emit worker realms discovered in script tags after navigation.
fn BidiProtocol::emit_worker_realms_from_scripts(
  self : BidiProtocol,
  ctx_id : String,
  window_realm_id : String,
) -> Unit {
  let scripts = self.collect_script_texts(ctx_id)
  let mut dedicated_worker_realm : String? = None
  for script_source in scripts {
    match extract_quoted_after_marker(script_source, "new Worker(") {
      Some(worker_url) =>
        dedicated_worker_realm = self.emit_worker_realm_created(
          ctx_id, "dedicated-worker", worker_url, window_realm_id,
        )
      None => ()
    }
    match extract_quoted_after_marker(script_source, "new SharedWorker(") {
      Some(worker_url) => {
        let _ = self.emit_worker_realm_created(
          ctx_id, "shared-worker", worker_url, window_realm_id,
        )
      }
      None => ()
    }
    match
      extract_quoted_after_marker(script_source, "serviceWorker.register(") {
      Some(worker_url) => {
        let _ = self.emit_worker_realm_created(
          ctx_id, "service-worker", worker_url, window_realm_id,
        )
      }
      None => ()
    }
    if script_source.contains("terminate(") {
      match dedicated_worker_realm {
        Some(realm_id) => {
          self.emit_realm_destroyed_for_context(realm_id, ctx_id)
          self.realm_context.remove(realm_id)
          self.realm_sandbox.remove(realm_id)
          match self.context_worker_realms.get(ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, [realm_id])
              if filtered.length() == 0 {
                self.context_worker_realms.remove(ctx_id)
              } else {
                self.context_worker_realms[ctx_id] = filtered
              }
            }
            None => ()
          }
          dedicated_worker_realm = None
        }
        None => ()
      }
    }
  }
}

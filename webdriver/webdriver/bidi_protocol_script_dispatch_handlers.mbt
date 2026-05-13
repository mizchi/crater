///|
/// Handle script.disown.
fn BidiProtocol::handle_script_disown(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.validate_script_target(request_id, params) {
    Some(_) => return
    None => ()
  }
  let raw_handles = match get_param_raw(params, "handles") {
    Some(Array(handles)) => handles
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "handles must be an array",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing handles")
      return
    }
  }
  let handles : Array[String] = []
  for raw_handle in raw_handles {
    match raw_handle {
      String(handle_id) => handles.push(handle_id)
      _ => {
        self.send_error(
          request_id, "invalid argument", "handles entries must be strings",
        )
        return
      }
    }
  }
  let (ctx_id_disown, realm_id_disown) = self.resolve_target_context_realm(
    params,
  )
  let runtime_ctx_id_disown = resolve_runtime_context_id(
    params,
    ctx_id_disown,
    realm_id_disown,
    self.realm_sandbox.get(realm_id_disown) != None,
  )
  set_runtime_context(runtime_ctx_id_disown)
  self.apply_effective_viewport_to_runtime_context(
    runtime_ctx_id_disown, ctx_id_disown,
  )
  for handle_id in handles {
    delete_runtime_handle(handle_id)
  }
  self.send_success(request_id, Some(make_object({})))
}

///|
/// Handle script.removePreloadScript.
fn BidiProtocol::handle_script_remove_preload_script(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let script_id = match get_param_raw(params, "script") {
    Some(String(script_id)) => script_id
    Some(Object(map)) =>
      match map.get("script") {
        Some(String(script_id)) => script_id
        _ => {
          self.send_error(
            request_id, "invalid argument", "script must be a string",
          )
          return
        }
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "script must be a string")
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing script")
      return
    }
  }
  let remaining_entries : Array[PreloadScriptEntry] = []
  let mut removed = false
  let mut removed_entry : PreloadScriptEntry? = None
  for entry in self.preload_scripts {
    if !removed && entry.script_id == script_id {
      removed = true
      removed_entry = Some(entry)
    } else {
      remaining_entries.push(entry)
    }
  }
  if !removed {
    self.send_error(
      request_id,
      "no such script",
      "Unknown preload script: " + script_id,
    )
    return
  }
  self.preload_scripts = remaining_entries
  match removed_entry {
    Some(entry) => self.cleanup_removed_preload_entry(entry)
    None => ()
  }
  self.send_success(request_id, Some(make_object({})))
}

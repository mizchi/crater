///|
fn BidiProtocol::handle_network_resolve_matching_intercepts(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let phase = match map.get("phase") {
    Some(String(phase)) =>
      if is_valid_network_intercept_phase(phase) {
        phase
      } else {
        self.send_error(request_id, "invalid argument", "phase is invalid")
        return
      }
    _ => {
      self.send_error(request_id, "invalid argument", "phase must be a string")
      return
    }
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let intercepts : Array[Json] = []
  for
    intercept_id in self.resolve_matching_network_intercepts_internal(
      context_id, phase, url,
    ) {
    intercepts.push(Json::string(intercept_id))
  }
  self.send_success(
    request_id,
    Some(make_object({ "intercepts": Json::array(intercepts) })),
  )
}

///|
fn BidiProtocol::list_active_network_intercept_ids(
  self : BidiProtocol,
) -> Array[String] {
  let ids : Array[String] = []
  for i = 1; i < self.network_state.next_network_intercept_id; i = i + 1 {
    let intercept_id = left_pad_with_zero(i.to_string(), 32)
    if self.network_state.network_intercepts.contains(intercept_id) {
      ids.push(intercept_id)
    }
  }
  ids
}

///|
fn BidiProtocol::build_context_scope_ancestry_for_matching(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  let ancestry = if self.manager.has_session(ctx_id) {
    self.build_context_ancestry(ctx_id)
  } else {
    []
  }
  if ctx_id != "" && !array_contains_string(ancestry, ctx_id) {
    ancestry.push(ctx_id)
  }
  ancestry
}

///|
fn BidiProtocol::resolve_matching_network_intercepts_internal(
  self : BidiProtocol,
  context_id : String,
  phase : String,
  url : String,
) -> Array[String] {
  let intercepts : Array[String] = []
  let ancestry = self.build_context_scope_ancestry_for_matching(context_id)
  for intercept_id in self.list_active_network_intercept_ids() {
    match self.network_state.network_intercepts.get(intercept_id) {
      Some(Object(options)) =>
        if @crater_network.network_intercept_matches_phase(options, phase) &&
          @crater_network.network_option_contexts_match(options, ancestry) &&
          @crater_network.network_url_patterns_match(options, url) {
          intercepts.push(intercept_id)
        }
      _ => ()
    }
  }
  intercepts
}

///|
fn array_contains_string(items : Array[String], target : String) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}

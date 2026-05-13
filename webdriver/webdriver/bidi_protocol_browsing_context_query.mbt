///|
fn BidiProtocol::handle_browsing_context_get_context_scope_info(
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
  self.send_success(
    request_id,
    Some(self.build_context_scope_info_json(context_id)),
  )
}

///|
fn BidiProtocol::handle_browsing_context_is_known_context(
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
  self.send_success(
    request_id,
    Some(Json::boolean(self.manager.has_session(context_id))),
  )
}

///|
fn BidiProtocol::handle_browsing_context_get_requested_navigation_url(
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
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return
  }
  self.send_success(
    request_id,
    Some(
      make_object({
        "url": Json::string(self.requested_navigation_url(context_id)),
      }),
    ),
  )
}

///|
fn BidiProtocol::handle_browsing_context_get_context_info(
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
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return
  }
  match self.build_context_entry(context_id, true, 0, Some(0)) {
    Some(entry) => self.send_success(request_id, Some(entry))
    None =>
      self.send_error(
        request_id,
        "no such frame",
        "Unknown context: " + context_id,
      )
  }
}

///|
fn BidiProtocol::handle_browsing_context_get_tree_contexts(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_tree_contexts(request_id, params) {
    Some(contexts) => self.send_success(request_id, Some(Json::array(contexts)))
    None => ()
  }
}

///|
fn BidiProtocol::handle_browsing_context_get_current_url(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_current_context_url(request_id, params) {
    Some((context_id, url)) =>
      self.send_success(
        request_id,
        Some(
          make_object({
            "context": Json::string(context_id),
            "url": Json::string(url),
          }),
        ),
      )
    None => ()
  }
}

///|
fn BidiProtocol::handle_browsing_context_get_current_url_value(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_current_context_url(request_id, params) {
    Some((_, url)) => self.send_success(request_id, Some(Json::string(url)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_current_context_url(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> (String, String)? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return None
  }
  Some((context_id, self.current_context_url(context_id)))
}

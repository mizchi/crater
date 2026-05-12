///|
/// Emit contextCreated event
fn BidiProtocol::emit_context_created(
  self : BidiProtocol,
  ctx_id : String,
  ctx_type : String,
  url : String,
  original_opener : String?,
  parent_ctx_id : String?,
) -> Unit {
  let event_name = "browsingContext.contextCreated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  let opener_json = match original_opener {
    Some(opener) => Json::string(opener)
    None => Json::null()
  }
  let parent_json = match parent_ctx_id {
    Some(parent_id) => Json::string(parent_id)
    None => Json::null()
  }
  let client_window = self.context_client_window
    .get(ctx_id)
    .unwrap_or("client-window-" + ctx_id)
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "type": Json::string(ctx_type),
    "children": Json::null(),
    "parent": parent_json,
    "clientWindow": Json::string(client_window),
    "userContext": Json::string(user_ctx),
    "originalOpener": opener_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit contextDestroyed event
fn BidiProtocol::emit_context_destroyed(
  self : BidiProtocol,
  ctx_id : String,
  original_opener : String?,
) -> Unit {
  let event_name = "browsingContext.contextDestroyed"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  let children_json : Array[Json] = []
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    children_json.push(Json::string(child_ctx_id))
  }
  let parent_json = match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => Json::string(parent_ctx_id)
    None => Json::null()
  }
  let client_window = self.context_client_window
    .get(ctx_id)
    .unwrap_or("client-window-" + ctx_id)
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  let opener_json = match original_opener {
    Some(opener) => Json::string(opener)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "children": Json::array(children_json),
    "parent": parent_json,
    "clientWindow": Json::string(client_window),
    "userContext": Json::string(user_ctx),
    "originalOpener": opener_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit userPromptOpened event for the given context.
fn BidiProtocol::emit_user_prompt_opened(
  self : BidiProtocol,
  ctx_id : String,
  prompt_type : String,
  handler : String,
  message : String,
  default_value : String?,
) -> Unit {
  let event_name = "browsingContext.userPromptOpened"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params_map : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "type": Json::string(prompt_type),
    "handler": Json::string(handler),
    "message": Json::string(message),
  }
  match default_value {
    Some(value) => params_map["defaultValue"] = Json::string(value)
    None => ()
  }
  let params = make_object(params_map)
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit userPromptClosed event for the given context.
fn BidiProtocol::emit_user_prompt_closed(
  self : BidiProtocol,
  ctx_id : String,
  prompt_type : String,
  accepted : Bool,
  user_text : String?,
) -> Unit {
  let event_name = "browsingContext.userPromptClosed"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params_map : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "type": Json::string(prompt_type),
    "accepted": Json::boolean(accepted),
  }
  if prompt_type == "prompt" && accepted {
    match user_text {
      Some(value) => params_map["userText"] = Json::string(value)
      None => ()
    }
  }
  let params = make_object(params_map)
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit downloadWillBegin event for the given context.
fn BidiProtocol::emit_download_will_begin(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  suggested_filename : String,
  url : String,
) -> Unit {
  let event_name = "browsingContext.downloadWillBegin"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let navigation_json = match navigation_id {
    Some(nav_id) => Json::string(nav_id)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": navigation_json,
    "suggestedFilename": Json::string(suggested_filename),
    "timestamp": Json::number(input_now_ms()),
    "url": Json::string(url),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit downloadEnd event for the given context.
fn BidiProtocol::emit_download_end(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  status : String,
  filepath : String?,
  url : String,
) -> Unit {
  let event_name = "browsingContext.downloadEnd"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let navigation_json = match navigation_id {
    Some(nav_id) => Json::string(nav_id)
    None => Json::null()
  }
  let filepath_json = match filepath {
    Some(path) => Json::string(path)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": navigation_json,
    "status": Json::string(status),
    "filepath": filepath_json,
    "timestamp": Json::number(input_now_ms()),
    "url": Json::string(url),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit realmDestroyed event for a realm scoped to a context.
fn BidiProtocol::emit_realm_destroyed_for_context(
  self : BidiProtocol,
  realm_id : String,
  ctx_id : String,
) -> Unit {
  let event_name = "script.realmDestroyed"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params = make_object({ "realm": Json::string(realm_id) })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit realmCreated event for a context realm.
fn BidiProtocol::emit_realm_created(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  sandbox_name : String?,
) -> Unit {
  let event_name = "script.realmCreated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let sandbox_json = match sandbox_name {
    Some(name) => Json::string(name)
    None => Json::null()
  }
  let params = make_object({
    "realm": Json::string(realm_id),
    "type": Json::string("window"),
    "context": Json::string(ctx_id),
    "origin": Json::string(self.get_context_origin(ctx_id)),
    "sandbox": sandbox_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit default realmCreated event for a context.
fn BidiProtocol::emit_default_realm(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  self.emit_realm_created(ctx_id, realm_id, None)
}

///|
/// Emit all existing realms for a context subtree.
fn BidiProtocol::emit_existing_realms_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  if !self.manager.has_session(ctx_id) {
    return
  }
  self.emit_default_realm(ctx_id)
  let prefix = ctx_id + "::"
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      let sandbox_name = key.unsafe_substring(
        start=prefix.length(),
        end=key.length(),
      )
      self.emit_realm_created(ctx_id, realm_id, Some(sandbox_name))
    }
  }
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    self.emit_existing_realms_for_context(child_ctx_id)
  }
}

///|
/// Resolve top-level browsing context id for a context (frame or top-level).
fn BidiProtocol::resolve_top_level_context_id(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => self.resolve_top_level_context_id(parent_ctx_id)
    None => ctx_id
  }
}

///|
/// Resolve prompt context visible from given browsing context.
fn BidiProtocol::resolve_pending_prompt_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String? {
  if self.pending_prompt_type.get(ctx_id) != None {
    return Some(ctx_id)
  }
  let top_ctx_id = self.resolve_top_level_context_id(ctx_id)
  for prompt_ctx_id, _ in self.pending_prompt_type {
    if self.resolve_top_level_context_id(prompt_ctx_id) == top_ctx_id {
      return Some(prompt_ctx_id)
    }
  }
  None
}

///|
/// Determine whether a context or any of its descendant contexts has beforeunload prompt state.
fn BidiProtocol::has_beforeunload_prompt_in_scope(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  if self.context_has_beforeunload.get(ctx_id).unwrap_or(false) {
    return true
  }
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    if self.has_beforeunload_prompt_in_scope(child_ctx_id) {
      return true
    }
  }
  false
}

///|
/// Determine whether context is currently active/visible.
fn BidiProtocol::is_context_active(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  let top_ctx_id = self.resolve_top_level_context_id(ctx_id)
  let active_top_ctx = match self.active_context_id {
    Some(active_ctx_id) => self.resolve_top_level_context_id(active_ctx_id)
    None =>
      match self.default_context_id {
        Some(default_ctx_id) =>
          self.resolve_top_level_context_id(default_ctx_id)
        None => top_ctx_id
      }
  }
  top_ctx_id == active_top_ctx
}

///|
/// Determine whether context is visible.
/// Contexts in non-active client windows remain visible.
fn BidiProtocol::is_context_visible(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  let top_ctx_id = self.resolve_top_level_context_id(ctx_id)
  let active_top_ctx = match self.active_context_id {
    Some(active_ctx_id) => self.resolve_top_level_context_id(active_ctx_id)
    None =>
      match self.default_context_id {
        Some(default_ctx_id) =>
          self.resolve_top_level_context_id(default_ctx_id)
        None => top_ctx_id
      }
  }
  if top_ctx_id == active_top_ctx {
    return true
  }
  let top_window = self.context_client_window
    .get(top_ctx_id)
    .unwrap_or("client-window-" + top_ctx_id)
  let active_window = self.context_client_window
    .get(active_top_ctx)
    .unwrap_or("client-window-" + active_top_ctx)
  top_window != active_window
}

///|
/// Default viewport width used when no override is configured.
fn default_viewport_width() -> Int {
  1024
}

///|
/// Default viewport height used when no override is configured.
fn default_viewport_height() -> Int {
  768
}

///|
/// Default devicePixelRatio used when no override is configured.
fn default_device_pixel_ratio() -> Double {
  1.0
}

///|
/// Resolve effective viewport width for a context.
fn BidiProtocol::resolve_effective_viewport_width(
  self : BidiProtocol,
  ctx_id : String,
) -> Int {
  match self.context_viewport_width.get(ctx_id) {
    Some(width) => width
    None => {
      let user_context_id = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      self.user_context_viewport_width
      .get(user_context_id)
      .unwrap_or(default_viewport_width())
    }
  }
}

///|
/// Resolve effective viewport height for a context.
fn BidiProtocol::resolve_effective_viewport_height(
  self : BidiProtocol,
  ctx_id : String,
) -> Int {
  match self.context_viewport_height.get(ctx_id) {
    Some(height) => height
    None => {
      let user_context_id = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      self.user_context_viewport_height
      .get(user_context_id)
      .unwrap_or(default_viewport_height())
    }
  }
}

///|
/// Resolve effective devicePixelRatio for a context.
fn BidiProtocol::resolve_effective_device_pixel_ratio(
  self : BidiProtocol,
  ctx_id : String,
) -> Double {
  match self.context_device_pixel_ratio.get(ctx_id) {
    Some(dpr) => dpr
    None => {
      let user_context_id = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      self.user_context_device_pixel_ratio
      .get(user_context_id)
      .unwrap_or(default_device_pixel_ratio())
    }
  }
}

///|
/// Build capabilities response
fn build_capabilities() -> Json {
  make_object({
    "browserName": Json::string("crater"),
    "browserVersion": Json::string("0.1.0"),
    "platformName": Json::string("MoonBit"),
    "acceptInsecureCerts": Json::boolean(false),
    "userAgent": Json::string("Crater"),
  })
}

///|
/// Build a single context entry recursively.
fn BidiProtocol::build_context_entry(
  self : BidiProtocol,
  ctx_id : String,
  include_parent : Bool,
  depth : Int,
  max_depth : Int?,
) -> Json? {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let truncate_children = match max_depth {
        Some(max_d) => depth >= max_d
        None => false
      }
      let children_json = if truncate_children {
        Json::null()
      } else {
        let children : Array[Json] = []
        for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
          match
            self.build_context_entry(child_ctx_id, false, depth + 1, max_depth) {
            Some(child_entry) => children.push(child_entry)
            None => ()
          }
        }
        Json::array(children)
      }
      let original_opener = match self.context_original_opener.get(ctx_id) {
        Some(opener) => Json::string(opener)
        None => Json::null()
      }
      let parent_json = match self.context_parent.get(ctx_id) {
        Some(parent_ctx_id) => Json::string(parent_ctx_id)
        None => Json::null()
      }
      let client_window = self.context_client_window
        .get(ctx_id)
        .unwrap_or("client-window-" + ctx_id)
      let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
      let entry = if include_parent {
        make_object({
          "context": Json::string(ctx_id),
          "url": Json::string(session.get_url()),
          "children": children_json,
          "parent": parent_json,
          "clientWindow": Json::string(client_window),
          "userContext": Json::string(user_ctx),
          "originalOpener": original_opener,
        })
      } else {
        make_object({
          "context": Json::string(ctx_id),
          "url": Json::string(session.get_url()),
          "children": children_json,
          "clientWindow": Json::string(client_window),
          "userContext": Json::string(user_ctx),
          "originalOpener": original_opener,
        })
      }
      Some(entry)
    }
    None => None
  }
}

///|
/// Resolve the realm origin for a browsing context.
fn BidiProtocol::get_context_origin(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.manager.get_session(ctx_id) {
    Some(session) => derive_realm_origin(session.get_url())
    None => "null"
  }
}

///|
/// Convert a context URL into a realm origin string.
fn derive_realm_origin(url : String) -> String {
  if url.has_prefix("about:") {
    return "null"
  }
  if url.has_prefix("data:") {
    if url.contains("#domain=alt") {
      return "http://alt.localhost:8000/"
    }
    return "http://localhost:8000/"
  }
  if url.has_prefix("http://") {
    return extract_http_origin(url, "http://", 7)
  }
  if url.has_prefix("https://") {
    return extract_http_origin(url, "https://", 8)
  }
  "null"
}

///|
/// Extract scheme + host + slash origin from an absolute HTTP(S) URL.
fn extract_http_origin(url : String, scheme : String, start : Int) -> String {
  let chars = url.to_array()
  let mut end = chars.length()
  for i = start; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  let host = url.unsafe_substring(start~, end~)
  if host.length() == 0 {
    "null"
  } else {
    scheme + host + "/"
  }
}

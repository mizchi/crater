///|
/// Emit browsingContext.contextCreated events for an existing context tree.
fn BidiProtocol::emit_existing_context_created_tree(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  let parent_ctx_id = self.context_parent.get(ctx_id)
  let original_opener = self.context_original_opener.get(ctx_id)
  let ctx_type = if self.context_parent.contains(ctx_id) {
    "tab"
  } else {
    "window"
  }
  self.emit_context_created(
    ctx_id, ctx_type, url, original_opener, parent_ctx_id,
  )
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    self.emit_existing_context_created_tree(child_ctx_id)
  }
}

///|
/// Rebuild child contexts from iframe elements under a parent context.
fn BidiProtocol::refresh_child_contexts_from_iframes(
  self : BidiProtocol,
  parent_ctx_id : String,
) -> Unit {
  self.refresh_child_contexts_from_iframes_with_depth(parent_ctx_id, 0)
}

///|
/// Register iframe elements that were inserted by an already-completed
/// script.evaluate call. This intentionally avoids
/// apply_effective_viewport_to_runtime_context: evaluate applies it at the
/// start of the command, and applying it again here would drain deferred
/// runtime bridges (notably userPromptOpened) too early.
fn BidiProtocol::refresh_child_contexts_from_runtime_iframes_after_eval(
  self : BidiProtocol,
  parent_ctx_id : String,
) -> Unit {
  set_runtime_context(parent_ctx_id)
  let frame_sources = get_runtime_iframe_sources()
  if frame_sources.length() == 0 {
    return
  }
  self.refresh_child_contexts_from_iframe_sources_with_depth(
    parent_ctx_id, frame_sources, 0,
  )
}

///|
/// Rebuild child contexts from iframe elements with recursion guard.
fn BidiProtocol::refresh_child_contexts_from_iframes_with_depth(
  self : BidiProtocol,
  parent_ctx_id : String,
  depth : Int,
) -> Unit {
  if depth >= 8 {
    return
  }
  let frame_sources = self.collect_iframe_sources(parent_ctx_id)
  self.refresh_child_contexts_from_iframe_sources_with_depth(
    parent_ctx_id, frame_sources, depth,
  )
}

///|
fn BidiProtocol::refresh_child_contexts_from_iframe_sources_with_depth(
  self : BidiProtocol,
  parent_ctx_id : String,
  frame_sources : Array[String],
  depth : Int,
) -> Unit {
  let existing_children = self.context_children.get(parent_ctx_id).unwrap_or([])
  let user_ctx = self.context_user_context
    .get(parent_ctx_id)
    .unwrap_or("default")
  let mut frame_index = 0
  for src in frame_sources {
    if frame_index < existing_children.length() {
      frame_index += 1
      continue
    }
    let child_ctx_id = self.create_child_context(parent_ctx_id, user_ctx)
    self.emit_context_created(
      child_ctx_id,
      "tab",
      "about:blank",
      None,
      Some(parent_ctx_id),
    )
    let child_nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    if self.is_iframe_navigation_blocked(child_ctx_id, src) {
      self.emit_default_realm(child_ctx_id)
      self.emit_navigation_started_event(child_ctx_id, src, child_nav_id)
      self.emit_navigation_failed_event(child_ctx_id, src, child_nav_id)
      continue
    }
    match self.manager.get_session(child_ctx_id) {
      Some(child_session) => {
        let _ = child_session.navigate_to(src)
      }
      None => ()
    }
    self.load_data_url_content(child_ctx_id, src)
    let window_realm_id = self.assign_new_realm(child_ctx_id)
    self.emit_default_realm(child_ctx_id)
    self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
    self.apply_preload_scripts_for_context(child_ctx_id)
    self.execute_inline_scripts_for_context(child_ctx_id)
    self.emit_navigation_events(child_ctx_id, src, child_nav_id)
    // about:blank fallback frames can mirror parent runtime and recurse infinitely.
    // Avoid deep expansion until frame documents diverge via explicit navigation/src.
    if src != "about:blank" {
      self.refresh_child_contexts_from_iframes_with_depth(
        child_ctx_id,
        depth + 1,
      )
    }
    frame_index += 1
  }
}

///|
/// Set a custom JS runtime for script execution (e.g. V8 for native).
/// Must be called before any script execution (before navigate/load_html).
pub fn Browser::set_js_runtime(
  self : Browser,
  runtime : &@js.JsRuntime,
) -> Unit {
  self.js_runtime_override = Some(runtime)
  self.enable_js = true
}

///|
fn decode_js_string_result(value : String) -> String? {
  let parsed = @json.parse(value) catch { _ => return None }
  match parsed {
    String(text) => Some(text)
    _ => None
  }
}

///|
fn Browser::flush_js_logs(self : Browser) -> Unit {
  match self.script_executor {
    Some(executor) => {
      for log in executor.get_logs() {
        println("[JS] " + log)
      }
      executor.clear_logs()
    }
    None => ()
  }
}

///|
fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '\\' => buf.write_string("\\\\")
      '\'' => buf.write_string("\\'")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn Browser::execute_inline_js(self : Browser, source : String) -> String? {
  if !self.enable_js {
    return None
  }
  if self.dom_tree is None {
    self.init_js_execution()
  }
  match self.script_executor {
    Some(executor) =>
      try {
        let result = executor.execute_source(source)
        self.flush_js_logs()
        let _ = self.drain_pending_form_submission_navigation_sync()
        Some(result.value)
      } catch {
        err => {
          println("[JS] Error: " + err.to_string())
          self.flush_js_logs()
          None
        }
      }
    None => None
  }
}

///|
pub async fn Browser::execute_inline_js_async(
  self : Browser,
  source : String,
) -> String? raise @http.HttpError {
  let result = self.execute_inline_js(source)
  let navigated = self.drain_pending_form_submission_navigation()
  if !navigated {
    let _ = self.sync_render_state_from_dom_tree()
  }
  result
}

///|
fn Browser::process_pending_script_tasks(self : Browser) -> Int {
  let ready_tasks = self.scheduler.poll_ready()
  let mut processed = 0
  for task in ready_tasks {
    match task.action {
      @scheduler.ExecuteScript(_) =>
        match self.script_executor {
          Some(executor) => {
            let result = executor.execute(task)
            let _ = self.scheduler.complete(task.id, result)
            processed = processed + 1
          }
          None => ()
        }
      _ => ()
    }
  }
  processed
}

///|
pub fn Browser::tick_js(self : Browser) -> Bool {
  if !self.enable_js {
    return false
  }
  if self.dom_tree is None {
    self.init_js_execution()
  }
  let processed = self.process_pending_script_tasks()
  if processed > 0 {
    self.flush_js_logs()
    if self.drain_pending_form_submission_navigation_sync() {
      return true
    }
    return self.sync_render_state_from_dom_tree()
  }
  let ticked = match self.script_executor {
    Some(executor) =>
      executor.tick() catch {
        err => {
          println("[JS] Error: " + err.to_string())
          false
        }
      }
    None => false
  }
  if !ticked {
    return false
  }
  self.flush_js_logs()
  if self.drain_pending_form_submission_navigation_sync() {
    return true
  }
  self.sync_render_state_from_dom_tree()
}

///|
/// Script info extracted from HTML
priv struct ScriptInfo {
  /// Inline script source (empty if external)
  source : String
  /// External script URL (empty if inline)
  src : String
  /// Whether script is async
  is_async : Bool
  /// Whether script is deferred
  is_defer : Bool
  /// Script type attribute (empty for default JavaScript)
  script_type : String
}

///|
/// Check if a script type is executable as JavaScript
fn is_executable_script_type(script_type : String) -> Bool {
  // Empty type or module/javascript types are executable
  if script_type.length() == 0 {
    return true
  }
  let lower = script_type.to_lower()
  // Standard JavaScript MIME types
  lower == "text/javascript" ||
  lower == "application/javascript" ||
  lower == "module"
}

///|
/// Extract script tags from HTML
fn extract_scripts(html : String) -> Array[ScriptInfo] {
  let scripts : Array[ScriptInfo] = []
  let len = html.length()
  let mut i = 0
  while i < len {
    // Look for <script
    if i + 7 < len &&
      char_at(html, i) == '<' &&
      (char_at(html, i + 1) == 's' || char_at(html, i + 1) == 'S') &&
      (char_at(html, i + 2) == 'c' || char_at(html, i + 2) == 'C') &&
      (char_at(html, i + 3) == 'r' || char_at(html, i + 3) == 'R') &&
      (char_at(html, i + 4) == 'i' || char_at(html, i + 4) == 'I') &&
      (char_at(html, i + 5) == 'p' || char_at(html, i + 5) == 'P') &&
      (char_at(html, i + 6) == 't' || char_at(html, i + 6) == 'T') &&
      (
        char_at(html, i + 7) == ' ' ||
        char_at(html, i + 7) == '>' ||
        char_at(html, i + 7) == '\t' ||
        char_at(html, i + 7) == '\n'
      ) {
      // Parse script tag attributes
      let mut j = i + 7
      let mut src = ""
      let mut script_type = ""
      let mut is_async = false
      let mut is_defer = false
      // Find end of opening tag
      while j < len && char_at(html, j) != '>' {
        // Check for src="..."
        if j + 5 < len &&
          (char_at(html, j) == 's' || char_at(html, j) == 'S') &&
          (char_at(html, j + 1) == 'r' || char_at(html, j + 1) == 'R') &&
          (char_at(html, j + 2) == 'c' || char_at(html, j + 2) == 'C') &&
          char_at(html, j + 3) == '=' {
          let quote = char_at(html, j + 4)
          if quote == '"' || quote == '\'' {
            let mut k = j + 5
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            src = html.unsafe_substring(start=j + 5, end=k)
            j = k
          }
        }
        // Check for type="..."
        if j + 6 < len &&
          (char_at(html, j) == 't' || char_at(html, j) == 'T') &&
          (char_at(html, j + 1) == 'y' || char_at(html, j + 1) == 'Y') &&
          (char_at(html, j + 2) == 'p' || char_at(html, j + 2) == 'P') &&
          (char_at(html, j + 3) == 'e' || char_at(html, j + 3) == 'E') &&
          char_at(html, j + 4) == '=' {
          let quote = char_at(html, j + 5)
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            script_type = html.unsafe_substring(start=j + 6, end=k)
            j = k
          }
        }
        // Check for async
        if j + 5 < len &&
          (char_at(html, j) == 'a' || char_at(html, j) == 'A') &&
          (char_at(html, j + 1) == 's' || char_at(html, j + 1) == 'S') &&
          (char_at(html, j + 2) == 'y' || char_at(html, j + 2) == 'Y') &&
          (char_at(html, j + 3) == 'n' || char_at(html, j + 3) == 'N') &&
          (char_at(html, j + 4) == 'c' || char_at(html, j + 4) == 'C') {
          is_async = true
        }
        // Check for defer
        if j + 5 < len &&
          (char_at(html, j) == 'd' || char_at(html, j) == 'D') &&
          (char_at(html, j + 1) == 'e' || char_at(html, j + 1) == 'E') &&
          (char_at(html, j + 2) == 'f' || char_at(html, j + 2) == 'F') &&
          (char_at(html, j + 3) == 'e' || char_at(html, j + 3) == 'E') &&
          (char_at(html, j + 4) == 'r' || char_at(html, j + 4) == 'R') {
          is_defer = true
        }
        j = j + 1
      }
      // Extract inline script content if no src
      let mut source = ""
      if src.length() == 0 && j < len && char_at(html, j) == '>' {
        let content_start = j + 1
        // Find </script>
        let mut content_end = content_start
        while content_end + 8 < len {
          if char_at(html, content_end) == '<' &&
            char_at(html, content_end + 1) == '/' &&
            (
              char_at(html, content_end + 2) == 's' ||
              char_at(html, content_end + 2) == 'S'
            ) &&
            (
              char_at(html, content_end + 3) == 'c' ||
              char_at(html, content_end + 3) == 'C'
            ) &&
            (
              char_at(html, content_end + 4) == 'r' ||
              char_at(html, content_end + 4) == 'R'
            ) &&
            (
              char_at(html, content_end + 5) == 'i' ||
              char_at(html, content_end + 5) == 'I'
            ) &&
            (
              char_at(html, content_end + 6) == 'p' ||
              char_at(html, content_end + 6) == 'P'
            ) &&
            (
              char_at(html, content_end + 7) == 't' ||
              char_at(html, content_end + 7) == 'T'
            ) {
            break
          }
          content_end = content_end + 1
        }
        source = html
          .unsafe_substring(start=content_start, end=content_end)
          .trim()
          .to_string()
        i = content_end
      }
      // Add script info if we have source or src
      if source.length() > 0 || src.length() > 0 {
        scripts.push({ source, src, is_async, is_defer, script_type })
      }
    }
    i = i + 1
  }
  scripts
}

///|
/// Initialize DOM tree and script executor
fn Browser::init_js_execution(self : Browser) -> Unit {
  // Build from parsed_doc/html_content when available so scripts can mutate
  // existing DOM and those mutations can be reflected back to rendering.
  let shadow_source_html = if html_source_requires_runtime_rebuild(
      self.source_html,
    ) {
    self.source_html
  } else if html_source_requires_runtime_rebuild(self.dom_snapshot_html) {
    self.dom_snapshot_html
  } else if html_source_requires_runtime_rebuild(self.html_content) {
    self.html_content
  } else {
    ""
  }
  let dom = if shadow_source_html.length() > 0 {
    match build_dom_tree_from_source_html(shadow_source_html) {
      Some(dom) => dom
      None =>
        match self.parsed_doc {
          Some(doc) => build_dom_tree_from_document(doc)
          None =>
            if self.html_content.length() > 0 {
              let doc = @html.assign_synthetic_ids(
                @html.parse_document(self.html_content),
              )
              self.parsed_doc = Some(doc)
              build_dom_tree_from_document(doc)
            } else {
              create_empty_html_dom_tree()
            }
        }
    }
  } else {
    match self.parsed_doc {
      Some(doc) => build_dom_tree_from_document(doc)
      None =>
        if self.html_content.length() > 0 {
          let doc = @html.assign_synthetic_ids(
            @html.parse_document(self.html_content),
          )
          self.parsed_doc = Some(doc)
          build_dom_tree_from_document(doc)
        } else {
          create_empty_html_dom_tree()
        }
    }
  }
  self.dom_tree = Some(dom)
  self.script_executor = Some(
    match self.js_runtime_override {
      Some(runtime) => @js.ScriptExecutor::new_with_runtime(dom, runtime)
      None => @js.ScriptExecutor::new_deferred(dom)
    },
  )
  match self.script_executor {
    Some(executor) =>
      ignore(executor.execute_source(browser_form_submit_bridge_source())) catch {
        err => println("[JS] Error: " + err.to_string())
      }
    None => ()
  }
}

///|
/// Execute scripts from the page (inline only, sync version)
/// Requires enable_js to be set to true (use --enable-js flag)
pub fn Browser::execute_scripts(self : Browser) -> Int {
  // Check if JS execution is enabled
  if !self.enable_js {
    return 0
  }
  // Ensure JS execution is initialized
  if self.dom_tree is None {
    self.init_js_execution()
  }
  // Extract scripts from HTML
  let scripts = extract_scripts(self.html_content)
  if scripts.length() == 0 {
    return 0
  }
  println("Found " + scripts.length().to_string() + " script(s)")
  let mut executed = 0
  for script in scripts {
    // Skip external scripts (use execute_scripts_async for external)
    if script.src.length() > 0 {
      println("  [SKIP] External script: " + script.src)
      continue
    }
    // Queue script for execution
    let blocking = !script.is_async && !script.is_defer
    let task_id = @js.enqueue_script(self.scheduler, script.source, blocking)
    println(
      "  [QUEUED] Inline script (task " +
      task_id.to_string() +
      ", blocking=" +
      blocking.to_string() +
      ")",
    )
  }
  // Process queued scripts
  executed = self.process_pending_script_tasks()
  if executed > 0 {
    if self.drain_pending_form_submission_navigation_sync() {
      self.flush_js_logs()
      println("Executed " + executed.to_string() + " script(s)")
      return executed
    }
    let _ = self.sync_render_state_from_dom_tree()
  }
  self.flush_js_logs()
  println("Executed " + executed.to_string() + " script(s)")
  executed
}

///|
/// Execute scripts from the page (including external scripts, async version)
/// Requires enable_js to be set to true (use --enable-js flag)
async fn Browser::execute_scripts_async(self : Browser) -> Int {
  // Check if JS execution is enabled
  if !self.enable_js {
    return 0
  }
  // Ensure JS execution is initialized
  if self.dom_tree is None {
    self.init_js_execution()
  }
  // Extract scripts from HTML
  let scripts = extract_scripts(self.html_content)
  if scripts.length() == 0 {
    return 0
  }
  println("Found " + scripts.length().to_string() + " script(s)")
  let mut executed = 0
  for script in scripts {
    // Skip non-JavaScript scripts (e.g., type="application/json")
    if !is_executable_script_type(script.script_type) {
      println("  [SKIP] Non-JS script type: " + script.script_type)
      continue
    }
    // Determine script source
    let mut source = ""
    let mut script_kind = "Inline"
    if script.src.length() > 0 {
      // Fetch external script
      let script_url = resolve_url(self.current_url, script.src)
      if script_url.length() == 0 {
        println("  [SKIP] Invalid script URL: " + script.src)
        continue
      }
      println("  [FETCH] External script: " + script_url)
      try {
        let script_options = {
          ..@http.FetchOptions::default(),
          mode: @http.RequestMode::NoCors,
          origin: self.current_url,
          sandbox: self.request_sandbox,
        }
        let response = @http.cached_fetch_async(
          url=script_url,
          options=script_options,
          cache=self.http_cache,
          fetcher=http_fetch_adapter,
        )
        println("    -> OK (" + response.body.length().to_string() + " bytes)")
        source = response.body
        script_kind = "External"
      } catch {
        err => {
          println("    -> Error: " + err.to_string())
          continue
        }
      }
    } else {
      source = script.source
    }
    // Skip empty scripts
    if source.length() == 0 {
      continue
    }
    // Queue script for execution
    let blocking = !script.is_async && !script.is_defer
    let task_id = @js.enqueue_script(self.scheduler, source, blocking)
    println(
      "  [QUEUED] " +
      script_kind +
      " script (task " +
      task_id.to_string() +
      ", blocking=" +
      blocking.to_string() +
      ")",
    )
  }
  // Process queued scripts
  executed = self.process_pending_script_tasks()
  if executed > 0 {
    let navigated = self.drain_pending_form_submission_navigation() catch {
      _ => false
    }
    if !navigated {
      let _ = self.sync_render_state_from_dom_tree()
    }
  }
  self.flush_js_logs()
  println("Executed " + executed.to_string() + " script(s)")
  executed
}

///|
/// Apply JS-mutated DomTree back to renderer inputs and invalidate caches
fn Browser::sync_render_state_from_dom_tree(self : Browser) -> Bool {
  match self.dom_tree {
    Some(dom) => {
      let next_html = @js.serialize_dom_to_html(dom)
      let next_snapshot_html = @js.serialize_dom_to_snapshot_html(dom)
      if next_html.length() == 0 {
        return false
      }
      let render_changed = next_html != self.html_content
      let snapshot_changed = next_snapshot_html != self.dom_snapshot_html
      if !render_changed && !snapshot_changed {
        return false
      }
      self.dom_snapshot_html = next_snapshot_html
      self.source_html = next_snapshot_html
      if !render_changed {
        return false
      }
      self.html_content = next_html
      self.html_has_declarative_shadow_dom = html_source_has_declarative_shadow_dom(
        self.html_content,
      )
      let next_doc = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(next_doc)
      self.refresh_links_from_render_source()
      if self.links.length() == 0 {
        self.focused_link = 0
      } else if self.focused_link >= self.links.length() {
        self.focused_link = self.links.length() - 1
      }
      self.clear_render_cache()
      self.content_height = @renderer.get_content_height_with_document(
        next_doc,
        self.viewport_width,
        self.viewport_height,
        self.external_css,
      )
      self.build_accessibility_tree()
      true
    }
    None => false
  }
}

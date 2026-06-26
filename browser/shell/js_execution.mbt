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
/// Inject crater's real layout into the JS realm so page-JS DOM measurement
/// (`getBoundingClientRect` / `offset*` / `getComputedStyle`) reads it instead
/// of the inline-style heuristic. Computes (or reuses the cached) render node +
/// layout for the current viewport and evaluates the bridge payload (see
/// `renderer/vrt` `layout_bridge_init_js`) in the page realm before scripts run,
/// defining `globalThis.__craterLayoutBoxes` / `__craterComputedStyles`. This is
/// the "initial-layout" path of the dynamic-rendering JS bridge: reads before a
/// mutation see real geometry; reads after a mutation see the last injected
/// layout until the next injection. Best-effort — any failure leaves the mock
/// DOM on its existing fallback behavior.
fn Browser::inject_layout_bridge(self : Browser) -> Unit {
  if !self.enable_js || self.html_content.length() == 0 {
    return
  }
  match self.script_executor {
    Some(executor) => {
      let ctx = @browser_helpers.create_render_context(
        self.viewport_width,
        self.viewport_height,
        false,
      )
      // Compute layout directly (do NOT use the cached graphics node/layout):
      // the graphics cache is keyed for the paint path and may be populated
      // with an image provider installed; reusing it here would either pollute
      // or read a paint-specific cache.
      let (node, layout) = match self.parsed_doc {
        Some(doc) => self.render_node_and_layout_from_document(doc, ctx, false)
        None =>
          @renderer.render_to_node_and_layout_with_external_css(
            self.html_content,
            ctx,
            self.external_css,
          )
      }
      let js = @vrt.layout_bridge_init_js(
        @vrt.collect_layout_boxes(layout),
        @vrt.collect_computed_styles(node),
      )
      try {
        let _ = executor.execute_source(js)
      } catch {
        _ => ()
      }
    }
    None => ()
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
        self.inject_layout_bridge()
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
  // Make crater's real layout visible to page JS before the batch runs.
  if ready_tasks.length() > 0 {
    self.inject_layout_bridge()
  }
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
  // Refresh the injected layout before timer / rAF callbacks run so they can
  // measure the geometry produced by the previous iteration's mutations.
  self.inject_layout_bridge()
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
/// Drive the JS event loop to quiescence: repeatedly run pending script / event
/// tasks, drain microtasks, apply the batched DOM ops, re-render, and run one
/// timer + requestAnimationFrame callback per iteration — looping until nothing
/// is left to do (no pending tasks and no timer/rAF fired) or `max_iterations`
/// is hit. The layout bridge is refreshed each iteration so timer / rAF
/// callbacks measure the geometry of the latest render (`setState -> re-render`,
/// effects, and animation steps run without an external pump).
///
/// Returns `true` when the loop settled, `false` when it stopped at the
/// iteration cap (a runaway timer chain). A navigation triggered mid-loop ends
/// the loop and reports settled.
pub fn Browser::run_event_loop(
  self : Browser,
  max_iterations? : Int = 1000,
) -> Bool {
  if !self.enable_js {
    return true
  }
  if self.dom_tree is None {
    self.init_js_execution()
  }
  for i = 0; i < max_iterations; i = i + 1 {
    let mut worked = false
    // 1. Pending script / event-handler tasks (injects the bridge internally).
    let processed = self.process_pending_script_tasks()
    if processed > 0 {
      worked = true
      self.flush_js_logs()
      if self.drain_pending_form_submission_navigation_sync() {
        return true
      }
      let _ = self.sync_render_state_from_dom_tree()
    }
    // 2. One macrotask (timer) + rAF + microtask drain, with fresh geometry.
    self.inject_layout_bridge()
    let ticked = match self.script_executor {
      Some(executor) => executor.tick() catch { _ => false }
      None => false
    }
    if ticked {
      worked = true
      self.flush_js_logs()
      if self.drain_pending_form_submission_navigation_sync() {
        return true
      }
      let _ = self.sync_render_state_from_dom_tree()
    }
    if !worked {
      return true
    }
  }
  false
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
      match self.fetch_external_script_source(script.src) {
        Some(fetched_source) => {
          source = fetched_source
          script_kind = "External"
        }
        None => continue
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

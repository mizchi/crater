///|
/// JavaScript Runtime - V8 implementation (native target)
///
/// Uses mizchi/v8 (rusty_v8 bindings) for real JavaScript execution
/// with full mock DOM support.

///|
pub struct V8JsRuntime {
  mut initialized : Bool
  mut dom_initialized : Bool
  mut dom_synced : Bool
  mut runtime : @v8.Runtime?
  mock_dom_source : String?
  id_map : Map[Int, @dom.NodeId]
}

///|
/// Create a V8JsRuntime without mock DOM (basic eval only).
pub fn V8JsRuntime::new() -> V8JsRuntime {
  {
    initialized: false,
    dom_initialized: false,
    dom_synced: false,
    runtime: None,
    mock_dom_source: None,
    id_map: {},
  }
}

///|
/// Create a V8JsRuntime with mock DOM source code.
/// The mock DOM JS will be evaluated on first execute() call.
pub fn V8JsRuntime::new_with_mock_dom(mock_dom_js : String) -> V8JsRuntime {
  {
    initialized: false,
    dom_initialized: false,
    dom_synced: false,
    runtime: None,
    mock_dom_source: Some(mock_dom_js),
    id_map: {},
  }
}

///|
/// Get V8JsRuntime as a JsRuntime trait object for use with JsContext.
pub fn V8JsRuntime::as_js_runtime(self : V8JsRuntime) -> &@js.JsRuntime {
  self as &@js.JsRuntime
}

///|
/// Console setup for no-mock-DOM mode (basic eval only)
let console_setup_js : String = "const __logs = [];\nconst console = {\n  log: (...args) => __logs.push(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')),\n  warn: (...args) => __logs.push('[WARN] ' + args.map(a => String(a)).join(' ')),\n  error: (...args) => __logs.push('[ERROR] ' + args.map(a => String(a)).join(' ')),\n  info: (...args) => __logs.push(args.map(a => String(a)).join(' ')),\n  debug: (...args) => {},\n};\nfunction __getLogs() { const l = [...__logs]; __logs.length = 0; return JSON.stringify(l); }"

///|
/// Logs setup for mock-DOM mode (mock DOM defines its own console that writes to `logs`)
let logs_bridge_js : String = "function __getLogs() { const l = [...logs]; logs.length = 0; return JSON.stringify(l); }"

///|
impl @js.JsRuntime for V8JsRuntime with init(self : V8JsRuntime) -> Unit {
  if not(self.initialized) {
    match @v8.runtime_new() {
      Ok(rt) => {
        self.runtime = Some(rt)
        self.initialized = true
        // If mock DOM source is provided, it defines its own console/logs.
        // Otherwise, set up basic console capture.
        match self.mock_dom_source {
          Some(_) => () // Console setup deferred to mock DOM init
          None => ignore(rt.eval_string(console_setup_js))
        }
      }
      Err(_) => ()
    }
  }
}

///|
impl @js.JsRuntime for V8JsRuntime with execute(
  self : V8JsRuntime,
  _context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : @js.AsyncExecutionMode,
) -> @js.JsResult raise @js.JsError {
  let rt = match self.runtime {
    Some(rt) => rt
    None => raise @js.JsError::execution_error("V8 runtime not initialized")
  }
  // Initialize mock DOM on first execute if source is available
  if not(self.dom_initialized) {
    match self.mock_dom_source {
      Some(src) =>
        match rt.eval_string(src) {
          Ok(_) => {
            self.dom_initialized = true
            // Bridge: mock DOM uses `logs` array, __getLogs reads from it
            ignore(rt.eval_string(logs_bridge_js))
          }
          Err(e) =>
            raise @js.JsError::execution_error(
              "mock DOM init failed: " + e.to_string(),
            )
        }
      None => ()
    }
  }
  // If mock DOM is loaded, initialize DOM on first call only
  if self.dom_initialized {
    // Reset logs and domOps for this execution
    ignore(rt.eval_string("logs.length = 0; domOps.length = 0;"))
    // Serialize DomTree into JS DOM only on first execute (avoid duplicating nodes)
    if not(self.dom_synced) {
      let init_code = @js.create_dom_init_code(dom)
      match rt.eval_string(init_code) {
        Ok(_) => ()
        Err(e) => println("[V8 initCode error] " + e.to_string())
      }
      populate_id_map(dom, self.id_map)
      self.dom_synced = true
    }
  }
  // Execute user code
  let flush = match async_mode {
    @js.ImmediateFlush => true
    @js.DeferredFlush => false
  }
  // Step 1: Execute user code and capture result
  let exec_code = "try {\n  globalThis.__lastResult = (function() { " +
    code +
    "\n})();\n  globalThis.__lastSuccess = true;\n} catch(e) {\n  globalThis.__lastError = e.message || String(e);\n  globalThis.__lastSuccess = false;\n}"
  ignore(rt.eval_string(exec_code))
  // Step 2: Flush microtasks (mock DOM's _SyncPromise + V8 native)
  // Mock DOM replaces Promise with _SyncPromise which uses _flushMicrotasks()
  if self.dom_initialized {
    ignore(rt.eval_string("_flushMicrotasks()"))
  }
  ignore(rt.perform_microtask_checkpoint())
  // Step 3: Flush mock DOM timers (setTimeout) with microtask interleaving
  if flush && self.dom_initialized {
    for i = 0; i < 100; i = i + 1 {
      match rt.eval_string("_runOneTimeout()") {
        Ok(v) => if v != "true" { break }
        Err(_) => break
      }
      ignore(rt.perform_microtask_checkpoint())
    }
  }
  // Step 4: Collect results
  let collect_code = if self.dom_initialized {
    "(function() {\n  const __logsResult = __getLogs();\n  const v = globalThis.__lastSuccess\n    ? JSON.stringify({ success: true, value: globalThis.__lastResult === undefined ? 'undefined' : String(globalThis.__lastResult), logs: JSON.parse(__logsResult), domOps: domOps || [] })\n    : JSON.stringify({ success: false, error: globalThis.__lastError || 'unknown', logs: JSON.parse(__logsResult), domOps: domOps || [] });\n  return v;\n})()"
  } else {
    "(function() {\n  const __logsResult = __getLogs();\n  const v = globalThis.__lastSuccess\n    ? JSON.stringify({ success: true, value: globalThis.__lastResult === undefined ? 'undefined' : String(globalThis.__lastResult), logs: JSON.parse(__logsResult) })\n    : JSON.stringify({ success: false, error: globalThis.__lastError || 'unknown', logs: JSON.parse(__logsResult) });\n  return v;\n})()"
  }
  match rt.eval_string(collect_code) {
    Ok(result_json) =>
      if self.dom_initialized {
        let (result, dom_ops) = parse_result_with_ops(result_json)
        if dom_ops.length() > 0 {
          apply_dom_ops(dom, dom_ops, self.id_map)
        }
        result
      } else {
        parse_v8_result(result_json)
      }
    Err(v8_err) => {
      let logs = collect_logs(rt)
      @js.JsResult::new(v8_err.to_string(), logs, false)
    }
  }
}

///|
impl @js.JsRuntime for V8JsRuntime with tick(
  self : V8JsRuntime,
  _context_id : Int,
  dom : @dom.DomTree,
) -> @js.JsResult raise @js.JsError {
  match self.runtime {
    Some(rt) => {
      ignore(rt.perform_microtask_checkpoint())
      if self.dom_initialized {
        // Run one timer + flush microtasks
        let tick_code = "logs.length = 0; domOps.length = 0;\nconst __hadWork = _runOneTimeout() || _runOneAnimationFrame();\n_flushMicrotasks();\nJSON.stringify({ success: true, value: String(__hadWork), logs: logs.slice(), domOps: domOps.slice() })"
        match rt.eval_string(tick_code) {
          Ok(json) => {
            let (result, dom_ops) = parse_result_with_ops(json)
            apply_dom_ops(dom, dom_ops, self.id_map)
            result
          }
          Err(_) => @js.JsResult::new("false", [], true)
        }
      } else {
        let logs = collect_logs(rt)
        @js.JsResult::new("false", logs, true)
      }
    }
    None => @js.JsResult::new("false", [], true)
  }
}

// ============================================================
// ID map management
// ============================================================

///|
/// Populate id_map with identity mappings for all existing DomTree nodes.
/// The mock DOM's `create_dom_init_code` sets `_mockId = domtree_id` for
/// serialized elements, so existing nodes have mock_id == domtree_id.
fn populate_id_map(dom : @dom.DomTree, id_map : Map[Int, @dom.NodeId]) -> Unit {
  // Clear previous mappings
  id_map.clear()
  // Traverse all existing nodes by walking the tree from document root
  populate_id_map_recursive(dom, dom.get_document(), id_map)
}

///|
fn populate_id_map_recursive(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  id_map : Map[Int, @dom.NodeId],
) -> Unit {
  let id_int = node_id.to_int()
  id_map[id_int] = node_id
  match dom.get_children(node_id) {
    Ok(children) =>
      for child in children {
        populate_id_map_recursive(dom, child, id_map)
      }
    Err(_) => ()
  }
}

// ============================================================
// DOM operation parsing and application
// ============================================================

///|
priv struct DomOp {
  op : String
  id : Int
  parent_id : Int
  child_id : Int
  ref_id : Int
  tag_name : String
  text : String
  name : String
  value : String
}

///|
fn parse_result_with_ops(json : String) -> (@js.JsResult, Array[DomOp]) {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  let dom_ops = parse_dom_ops(json)
  (@js.JsResult::new(value, logs, success), dom_ops)
}

///|
fn parse_dom_ops(json : String) -> Array[DomOp] {
  let ops : Array[DomOp] = []
  let pattern = "\"domOps\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      let chars = json.to_array()
      let mut i = array_start
      let mut depth = 0
      let mut obj_start = -1
      while i < chars.length() {
        let c = chars[i]
        if c == '{' {
          if depth == 0 {
            obj_start = c.to_int()
            ignore(obj_start)
            obj_start = i
          }
          depth += 1
        } else if c == '}' {
          depth -= 1
          if depth == 0 && obj_start >= 0 {
            let obj_str = json[obj_start:i + 1].to_string()
            ops.push(parse_single_dom_op(obj_str))
            obj_start = -1
          }
        } else if c == ']' && depth == 0 {
          break
        }
        i += 1
      }
    }
    None => ()
  }
  ops
}

///|
fn parse_single_dom_op(json : String) -> DomOp {
  {
    op: extract_json_field(json, "op"),
    id: parse_json_int(json, "id"),
    parent_id: parse_json_int(json, "parentId"),
    child_id: parse_json_int(json, "childId"),
    ref_id: parse_json_int(json, "refId"),
    tag_name: extract_json_field(json, "tagName"),
    text: extract_json_field(json, "text"),
    name: extract_json_field(json, "name"),
    value: extract_json_field(json, "value"),
  }
}

///|
fn parse_json_int(json : String, field : String) -> Int {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut i = value_start
      // Skip whitespace
      while i < chars.length() && (chars[i] == ' ' || chars[i] == '\t') {
        i += 1
      }
      let mut result = 0
      let mut neg = false
      if i < chars.length() && chars[i] == '-' {
        neg = true
        i += 1
      }
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        result = result * 10 + (chars[i].to_int() - '0'.to_int())
        i += 1
      }
      if neg {
        -result
      } else {
        result
      }
    }
    None => 0
  }
}

///|
fn apply_dom_ops(
  dom : @dom.DomTree,
  ops : Array[DomOp],
  id_map : Map[Int, @dom.NodeId],
) -> Unit {
  for op in ops {
    match op.op {
      "createElement" => {
        let node_id = dom.create_element(op.tag_name)
        // Map mock DOM id to actual DomTree id
        id_map[op.id] = node_id
      }
      "createTextNode" => {
        let node_id = dom.create_text(op.text)
        id_map[op.id] = node_id
      }
      "appendChild" => {
        let parent = id_map.get(op.parent_id)
        let child = id_map.get(op.child_id)
        match (parent, child) {
          (Some(p), Some(c)) => ignore(dom.append_child(p, c))
          _ => ()
        }
      }
      "removeChild" => {
        let parent = id_map.get(op.parent_id)
        let child = id_map.get(op.child_id)
        match (parent, child) {
          (Some(p), Some(c)) => ignore(dom.remove_child(p, c))
          _ => ()
        }
      }
      "insertBefore" => {
        let parent = id_map.get(op.parent_id)
        let child = id_map.get(op.child_id)
        let ref_node = if op.ref_id != 0 { id_map.get(op.ref_id) } else { None }
        match (parent, child) {
          (Some(p), Some(c)) => ignore(dom.insert_before(p, c, ref_node))
          _ => ()
        }
      }
      "replaceChild" => {
        // replaceChild: parentId, childId (new), refId (old)
        let parent = id_map.get(op.parent_id)
        let new_child = id_map.get(op.child_id)
        let old_child = id_map.get(op.ref_id)
        match (parent, new_child, old_child) {
          (Some(p), Some(nc), Some(oc)) => {
            // Insert new before old, then remove old
            ignore(dom.insert_before(p, nc, Some(oc)))
            ignore(dom.remove_child(p, oc))
          }
          _ => ()
        }
      }
      "setAttribute" =>
        match id_map.get(op.id) {
          Some(node) => ignore(dom.set_attribute(node, op.name, op.value))
          None => ()
        }
      "removeAttribute" =>
        match id_map.get(op.id) {
          Some(node) => ignore(dom.remove_attribute(node, op.name))
          None => ()
        }
      "setTextContent" =>
        match id_map.get(op.id) {
          Some(node) => {
            let text = if op.value.length() > 0 { op.value } else { op.text }
            ignore(dom.set_text_content(node, text))
          }
          None => ()
        }
      _ => () // Unknown op, skip
    }
  }
}

// ============================================================
// JSON parsing helpers
// ============================================================

///|
fn collect_logs(rt : @v8.Runtime) -> Array[String] {
  match rt.eval_string("__getLogs()") {
    Ok(json) => parse_string_array(json)
    Err(_) => []
  }
}

///|
fn parse_v8_result(json : String) -> @js.JsResult {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  @js.JsResult::new(value, logs, success)
}

///|
fn extract_json_field(json : String, field : String) -> String {
  let pattern = "\"" + field + "\":\""
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut i = value_start
      while i < chars.length() {
        if chars[i] == '"' && (i == value_start || chars[i - 1] != '\\') {
          break
        }
        i += 1
      }
      json[value_start:i].to_string()
    }
    None => ""
  }
}

///|
fn extract_json_array(json : String, field : String) -> Array[String] {
  let pattern = "\"" + field + "\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      let chars = json.to_array()
      let result : Array[String] = []
      let mut i = array_start
      while i < chars.length() && chars[i] != ']' {
        if chars[i] == '"' {
          let str_start = i + 1
          let mut str_end = str_start
          while str_end < chars.length() {
            if chars[str_end] == '"' &&
              (str_end == str_start || chars[str_end - 1] != '\\') {
              break
            }
            str_end += 1
          }
          result.push(json[str_start:str_end].to_string())
          i = str_end + 1
        } else {
          i += 1
        }
      }
      result
    }
    None => []
  }
}

///|
fn parse_string_array(json : String) -> Array[String] {
  if json.length() < 2 {
    return []
  }
  let result : Array[String] = []
  let chars = json.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] != '[' {
    i += 1
  }
  i += 1
  while i < chars.length() && chars[i] != ']' {
    if chars[i] == '"' {
      i += 1
      let start = i
      while i < chars.length() {
        if chars[i] == '"' && (i == start || chars[i - 1] != '\\') {
          break
        }
        i += 1
      }
      result.push(json[start:i].to_string())
      i += 1
    } else {
      i += 1
    }
  }
  result
}

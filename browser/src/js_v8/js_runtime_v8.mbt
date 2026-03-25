///|
/// JavaScript Runtime - V8 implementation (native target)
///
/// Uses mizchi/v8 (rusty_v8 bindings) for real JavaScript execution
/// with full mock DOM support.

///|
pub struct V8JsRuntime {
  mut initialized : Bool
  mut dom_initialized : Bool
  mut runtime : @v8.Runtime?
  mock_dom_source : String?
}

///|
/// Create a V8JsRuntime without mock DOM (basic eval only).
pub fn V8JsRuntime::new() -> V8JsRuntime {
  { initialized: false, dom_initialized: false, runtime: None, mock_dom_source: None }
}

///|
/// Create a V8JsRuntime with mock DOM source code.
/// The mock DOM JS will be evaluated on first execute() call.
pub fn V8JsRuntime::new_with_mock_dom(mock_dom_js : String) -> V8JsRuntime {
  {
    initialized: false,
    dom_initialized: false,
    runtime: None,
    mock_dom_source: Some(mock_dom_js),
  }
}

///|
/// Get V8JsRuntime as a JsRuntime trait object for use with JsContext.
pub fn V8JsRuntime::as_js_runtime(self : V8JsRuntime) -> &@js.JsRuntime {
  self as &@js.JsRuntime
}

///|
let console_setup_js : String = "const __logs = [];\nconst console = {\n  log: (...args) => __logs.push(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')),\n  warn: (...args) => __logs.push('[WARN] ' + args.map(a => String(a)).join(' ')),\n  error: (...args) => __logs.push('[ERROR] ' + args.map(a => String(a)).join(' ')),\n  info: (...args) => __logs.push(args.map(a => String(a)).join(' ')),\n  debug: (...args) => {},\n};\nfunction __getLogs() { const l = [...__logs]; __logs.length = 0; return JSON.stringify(l); }"

///|
impl @js.JsRuntime for V8JsRuntime with init(self : V8JsRuntime) -> Unit {
  if not(self.initialized) {
    match @v8.runtime_new() {
      Ok(rt) => {
        self.runtime = Some(rt)
        self.initialized = true
        ignore(rt.eval_string(console_setup_js))
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
      Some(src) => {
        match rt.eval_string(src) {
          Ok(_) => self.dom_initialized = true
          Err(e) =>
            raise @js.JsError::execution_error(
              "mock DOM init failed: " + e.to_string(),
            )
        }
      }
      None => ()
    }
  }
  // If mock DOM is loaded, serialize current DomTree and inject
  if self.dom_initialized {
    // Reset logs and domOps for this execution
    ignore(rt.eval_string("logs.length = 0; domOps.length = 0;"))
    // Serialize DomTree into JS DOM initialization code
    let init_code = @js.serialize_dom_for_mock(dom)
    ignore(rt.eval_string(init_code))
  }
  // Execute user code
  let flush = match async_mode {
    @js.ImmediateFlush => true
    @js.DeferredFlush => false
  }
  let flush_code = if flush && self.dom_initialized {
    "\n_flushMicrotasks();\nfor(let __i=0;__i<100;__i++){if(!_runOneTimeout())break;_flushMicrotasks();}"
  } else if flush {
    ""
  } else {
    ""
  }
  let wrapped = if self.dom_initialized {
    // With mock DOM: collect domOps in result
    "try {\n  const __result = (function() { " +
    code +
    "\n})();" +
    flush_code +
    "\n  const __logsResult = __getLogs();\n  JSON.stringify({ success: true, value: __result === undefined ? 'undefined' : String(__result), logs: JSON.parse(__logsResult), domOps: domOps || [] });\n} catch(e) {\n  const __logsResult = __getLogs();\n  JSON.stringify({ success: false, error: e.message || String(e), logs: JSON.parse(__logsResult), domOps: domOps || [] });\n}"
  } else {
    // Without mock DOM: simple eval
    "try {\n  const __result = (function() { " +
    code +
    "\n})();\n  const __logsResult = __getLogs();\n  JSON.stringify({ success: true, value: __result === undefined ? 'undefined' : String(__result), logs: JSON.parse(__logsResult) });\n} catch(e) {\n  const __logsResult = __getLogs();\n  JSON.stringify({ success: false, error: e.message || String(e), logs: JSON.parse(__logsResult) });\n}"
  }
  match rt.eval_string(wrapped) {
    Ok(result_json) => {
      if self.dom_initialized {
        let (result, dom_ops) = parse_result_with_ops(result_json)
        apply_dom_ops(dom, dom_ops)
        result
      } else {
        parse_v8_result(result_json)
      }
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
            apply_dom_ops(dom, dom_ops)
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
      if neg { -result } else { result }
    }
    None => 0
  }
}

///|
fn apply_dom_ops(dom : @dom.DomTree, ops : Array[DomOp]) -> Unit {
  for op in ops {
    match op.op {
      "createElement" => {
        let node_id = dom.create_element(op.tag_name)
        // Map mock DOM id to actual DomTree id
        ignore(node_id)
      }
      "createTextNode" => {
        let node_id = dom.create_text(op.text)
        ignore(node_id)
      }
      "appendChild" => {
        let parent = @dom.NodeId::from_int(op.parent_id)
        let child = @dom.NodeId::from_int(op.child_id)
        ignore(dom.append_child(parent, child))
      }
      "removeChild" => {
        let parent = @dom.NodeId::from_int(op.parent_id)
        let child = @dom.NodeId::from_int(op.child_id)
        ignore(dom.remove_child(parent, child))
      }
      "setAttribute" => {
        let node = @dom.NodeId::from_int(op.id)
        ignore(dom.set_attribute(node, op.name, op.value))
      }
      "removeAttribute" => {
        let node = @dom.NodeId::from_int(op.id)
        ignore(dom.remove_attribute(node, op.name))
      }
      "setTextContent" => {
        let node = @dom.NodeId::from_int(op.id)
        ignore(dom.set_text_content(node, op.text))
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

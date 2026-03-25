///|
/// JavaScript Runtime - V8 implementation (native target)
///
/// Uses mizchi/v8 (rusty_v8 bindings) for real JavaScript execution.
/// Implements the @js.JsRuntime trait.

///|
pub struct V8JsRuntime {
  mut initialized : Bool
  mut runtime : @v8.Runtime?
}

///|
pub fn V8JsRuntime::new() -> V8JsRuntime {
  { initialized: false, runtime: None }
}

///|
/// Get V8JsRuntime as a JsRuntime trait object for use with JsContext.
pub fn V8JsRuntime::as_js_runtime(self : V8JsRuntime) -> &@js.JsRuntime {
  self as &@js.JsRuntime
}

///|
impl @js.JsRuntime for V8JsRuntime with init(self : V8JsRuntime) -> Unit {
  if not(self.initialized) {
    match @v8.runtime_new() {
      Ok(rt) => {
        self.runtime = Some(rt)
        self.initialized = true
        // Install console.log capture
        ignore(rt.eval_string(
          "const __logs = [];\nconst console = {\n  log: (...args) => __logs.push(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')),\n  warn: (...args) => __logs.push('[WARN] ' + args.map(a => String(a)).join(' ')),\n  error: (...args) => __logs.push('[ERROR] ' + args.map(a => String(a)).join(' ')),\n  info: (...args) => __logs.push(args.map(a => String(a)).join(' ')),\n  debug: (...args) => {},\n};\nfunction __getLogs() { const l = [...__logs]; __logs.length = 0; return JSON.stringify(l); }",
        ))
      }
      Err(_) => ()
    }
  }
}

///|
impl @js.JsRuntime for V8JsRuntime with execute(
  self : V8JsRuntime,
  _context_id : Int,
  _dom : @dom.DomTree,
  code : String,
  _async_mode : @js.AsyncExecutionMode,
) -> @js.JsResult raise @js.JsError {
  let rt = match self.runtime {
    Some(rt) => rt
    None => raise @js.JsError::execution_error("V8 runtime not initialized")
  }
  // Execute user code wrapped in try-catch, return JSON result
  let wrapped =
    "try {\n  const __result = (function() { " +
    code +
    "\n})();\n  const __logsResult = __getLogs();\n  JSON.stringify({ success: true, value: __result === undefined ? 'undefined' : String(__result), logs: JSON.parse(__logsResult) });\n} catch(e) {\n  const __logsResult = __getLogs();\n  JSON.stringify({ success: false, error: e.message || String(e), logs: JSON.parse(__logsResult) });\n}"
  match rt.eval_string(wrapped) {
    Ok(result_json) => parse_v8_result(result_json)
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
  _dom : @dom.DomTree,
) -> @js.JsResult raise @js.JsError {
  match self.runtime {
    Some(rt) => {
      ignore(rt.perform_microtask_checkpoint())
      let logs = collect_logs(rt)
      @js.JsResult::new("false", logs, true)
    }
    None => @js.JsResult::new("false", [], true)
  }
}

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

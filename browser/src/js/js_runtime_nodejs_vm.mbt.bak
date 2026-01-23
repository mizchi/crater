///|
/// JavaScript Runtime - Node.js vm implementation (PoC)
///
/// Uses Node.js vm module to execute JavaScript.
/// DOM operations are queued and executed after JS completes.
/// WARNING: This is a PoC - vm is not a security sandbox!

///|
/// Global state for context management
priv struct RuntimeState {
  mut counter : Int
  contexts : Map[Int, @dom.DomTree]
  mut initialized : Bool
}

///|
/// Global runtime state
let runtime_state : RuntimeState = {
  counter: 0,
  contexts: {},
  initialized: false,
}

///|
/// Register a context and return its ID
fn register_context(dom : @dom.DomTree) -> Int {
  let id = runtime_state.counter
  runtime_state.counter = runtime_state.counter + 1
  runtime_state.contexts.set(id, dom)
  id
}

///|
/// Unregister a context
fn unregister_context(id : Int) -> Unit {
  runtime_state.contexts.remove(id)
}

///|
/// FFI: Execute JavaScript code with DOM mock
/// DOM operations are tracked and returned for batch processing
/// Returns JSON: { success, value, logs, domOps, error? }
extern "js" fn js_execute_with_mock_dom(code : String) -> String =
  #| (code) => {
  #|   const vm = require('vm');
  #|   const logs = [];
  #|   const domOps = [];
  #|   let nodeIdCounter = 1000; // Start high to avoid conflicts
  #|
  #|   // Track created elements by their mock ID
  #|   const mockElements = new Map();
  #|
  #|   // Create mock element
  #|   function createMockElement(tagName, mockId) {
  #|     const el = {
  #|       _mockId: mockId,
  #|       _tagName: tagName.toUpperCase(),
  #|       _attrs: {},
  #|       _textContent: '',
  #|       _children: [],
  #|       _parent: null,
  #|
  #|       get tagName() { return this._tagName; },
  #|
  #|       setAttribute(name, value) {
  #|         this._attrs[name] = String(value);
  #|         domOps.push({ op: 'setAttribute', id: this._mockId, name, value: String(value) });
  #|       },
  #|
  #|       getAttribute(name) {
  #|         return this._attrs[name] || null;
  #|       },
  #|
  #|       removeAttribute(name) {
  #|         delete this._attrs[name];
  #|         domOps.push({ op: 'removeAttribute', id: this._mockId, name });
  #|       },
  #|
  #|       get id() { return this._attrs.id || ''; },
  #|       set id(v) { this.setAttribute('id', v); },
  #|
  #|       get className() { return this._attrs.class || ''; },
  #|       set className(v) { this.setAttribute('class', v); },
  #|
  #|       get textContent() { return this._textContent; },
  #|       set textContent(v) {
  #|         this._textContent = String(v);
  #|         domOps.push({ op: 'setTextContent', id: this._mockId, value: String(v) });
  #|       },
  #|
  #|       appendChild(child) {
  #|         if (child && child._mockId !== undefined) {
  #|           this._children.push(child);
  #|           child._parent = this;
  #|           domOps.push({ op: 'appendChild', parentId: this._mockId, childId: child._mockId });
  #|         }
  #|         return child;
  #|       },
  #|
  #|       removeChild(child) {
  #|         const idx = this._children.indexOf(child);
  #|         if (idx >= 0) {
  #|           this._children.splice(idx, 1);
  #|           child._parent = null;
  #|           domOps.push({ op: 'removeChild', parentId: this._mockId, childId: child._mockId });
  #|         }
  #|         return child;
  #|       },
  #|
  #|       get parentNode() { return this._parent; },
  #|       get firstChild() { return this._children[0] || null; },
  #|       get children() { return [...this._children]; },
  #|       get nextSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children;
  #|         const idx = siblings.indexOf(this);
  #|         return siblings[idx + 1] || null;
  #|       }
  #|     };
  #|     mockElements.set(mockId, el);
  #|     return el;
  #|   }
  #|
  #|   // Create text node mock
  #|   function createMockTextNode(text, mockId) {
  #|     const node = {
  #|       _mockId: mockId,
  #|       _tagName: '#text',
  #|       _textContent: text,
  #|       _parent: null,
  #|       get textContent() { return this._textContent; },
  #|       set textContent(v) {
  #|         this._textContent = String(v);
  #|         domOps.push({ op: 'setTextContent', id: this._mockId, value: String(v) });
  #|       }
  #|     };
  #|     mockElements.set(mockId, node);
  #|     return node;
  #|   }
  #|
  #|   // Create document mock with body/html pre-created
  #|   const htmlEl = createMockElement('html', 1);
  #|   const bodyEl = createMockElement('body', 2);
  #|   htmlEl.appendChild(bodyEl);
  #|
  #|   const document = {
  #|     _mockElements: mockElements,
  #|
  #|     createElement(tagName) {
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createElement', id, tagName });
  #|       return createMockElement(tagName, id);
  #|     },
  #|
  #|     createTextNode(text) {
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createTextNode', id, text });
  #|       return createMockTextNode(text, id);
  #|     },
  #|
  #|     get body() { return bodyEl; },
  #|     get documentElement() { return htmlEl; },
  #|
  #|     getElementById(id) {
  #|       // Search in mock elements
  #|       for (const el of mockElements.values()) {
  #|         if (el._attrs && el._attrs.id === id) return el;
  #|       }
  #|       return null;
  #|     },
  #|
  #|     querySelector(selector) {
  #|       // Very basic selector support for PoC
  #|       if (selector === 'body') return bodyEl;
  #|       if (selector === 'html') return htmlEl;
  #|       if (selector.startsWith('#')) {
  #|         return this.getElementById(selector.slice(1));
  #|       }
  #|       // Tag name search
  #|       for (const el of mockElements.values()) {
  #|         if (el._tagName === selector.toUpperCase()) return el;
  #|       }
  #|       return null;
  #|     },
  #|
  #|     querySelectorAll(selector) {
  #|       const results = [];
  #|       if (selector === 'body') return [bodyEl];
  #|       if (selector === 'html') return [htmlEl];
  #|       for (const el of mockElements.values()) {
  #|         if (el._tagName === selector.toUpperCase()) results.push(el);
  #|       }
  #|       return results;
  #|     }
  #|   };
  #|
  #|   // Create sandbox
  #|   const sandbox = {
  #|     document,
  #|     console: {
  #|       log(...args) { logs.push(args.map(String).join(' ')); },
  #|       warn(...args) { logs.push('[WARN] ' + args.map(String).join(' ')); },
  #|       error(...args) { logs.push('[ERROR] ' + args.map(String).join(' ')); },
  #|       info(...args) { logs.push('[INFO] ' + args.map(String).join(' ')); }
  #|     },
  #|     setTimeout: (fn, ms) => setTimeout(fn, ms),
  #|     clearTimeout: (id) => clearTimeout(id)
  #|   };
  #|
  #|   try {
  #|     vm.createContext(sandbox);
  #|     const result = vm.runInContext(code, sandbox, { timeout: 5000 });
  #|     return JSON.stringify({
  #|       success: true,
  #|       value: result === undefined ? 'undefined' : String(result),
  #|       logs,
  #|       domOps
  #|     });
  #|   } catch (e) {
  #|     return JSON.stringify({
  #|       success: false,
  #|       value: '',
  #|       logs,
  #|       domOps,
  #|       error: e.message || String(e)
  #|     });
  #|   }
  #| }

///|
/// Initialize JS runtime (no-op for mock DOM approach)
pub fn init_js_runtime() -> Unit {
  runtime_state.initialized = true
}

///|
/// Execute JavaScript code with DOM bindings
pub fn JsContext::execute(
  self : JsContext,
  code : String,
) -> JsResult raise JsError {
  init_js_runtime()
  let context_id = register_context(self.dom)
  let result_json = js_execute_with_mock_dom(code)

  // Parse result
  let (result, dom_ops) = parse_js_result_with_ops(result_json)

  // Apply DOM operations to actual DomTree
  apply_dom_ops(self.dom, dom_ops)

  // Cleanup
  unregister_context(context_id)

  // Add logs to context
  for log in result.logs {
    self.logs.push(log)
  }
  if not(result.success) {
    raise ExecutionError(result.value)
  }
  result
}

///|
/// DOM operation type
priv struct DomOp {
  op : String
  id : Int
  parent_id : Int
  child_id : Int
  tag_name : String
  text : String
  name : String
  value : String
}

///|
/// Parse JS result JSON with DOM operations
fn parse_js_result_with_ops(json : String) -> (JsResult, Array[DomOp]) {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  let dom_ops = parse_dom_ops(json)
  ({ value, logs, success }, dom_ops)
}

///|
/// Parse DOM operations from JSON
fn parse_dom_ops(json : String) -> Array[DomOp] {
  let ops : Array[DomOp] = []
  // Find domOps array
  let pattern = "\"domOps\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      // Simple JSON array of objects parser
      let chars = json.to_array()
      let mut i = array_start
      let mut depth = 0
      let mut obj_start = -1
      while i < chars.length() {
        let c = chars[i]
        if c == '{' {
          if depth == 0 {
            obj_start = i
          }
          depth = depth + 1
        } else if c == '}' {
          depth = depth - 1
          if depth == 0 && obj_start >= 0 {
            let obj_json = json.unsafe_substring(start=obj_start, end=i + 1)
            let op = parse_single_dom_op(obj_json)
            ops.push(op)
            obj_start = -1
          }
        } else if c == ']' && depth == 0 {
          break
        }
        i = i + 1
      }
    }
    None => ()
  }
  ops
}

///|
/// Parse a single DOM operation object
fn parse_single_dom_op(json : String) -> DomOp {
  {
    op: extract_json_field(json, "op"),
    id: parse_int_field(json, "id"),
    parent_id: parse_int_field(json, "parentId"),
    child_id: parse_int_field(json, "childId"),
    tag_name: extract_json_field(json, "tagName"),
    text: extract_json_field(json, "text"),
    name: extract_json_field(json, "name"),
    value: extract_json_field(json, "value"),
  }
}

///|
/// Parse integer field from JSON
fn parse_int_field(json : String, field : String) -> Int {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut end = value_start
      while end < chars.length() &&
            ((chars[end] >= '0' && chars[end] <= '9') || chars[end] == '-') {
        end = end + 1
      }
      if end > value_start {
        let num_str = json.unsafe_substring(start=value_start, end~)
        @strconv.parse_int(num_str) catch {
          _ => 0
        }
      } else {
        0
      }
    }
    None => 0
  }
}

///|
/// Apply DOM operations to DomTree
fn apply_dom_ops(dom : @dom.DomTree, ops : Array[DomOp]) -> Unit {
  // Map mock IDs to real NodeIds
  let id_map : Map[Int, @dom.NodeId] = {}

  // Pre-populate with body (id=2 in mock)
  match dom.query_selector(dom.get_document(), "body") {
    Ok(Some(body_id)) => id_map.set(2, body_id)
    _ => ()
  }
  // Pre-populate with html (id=1 in mock)
  match dom.query_selector(dom.get_document(), "html") {
    Ok(Some(html_id)) => id_map.set(1, html_id)
    _ => ()
  }
  for op in ops {
    match op.op {
      "createElement" => {
        let node_id = dom.create_element(op.tag_name)
        id_map.set(op.id, node_id)
      }
      "createTextNode" => {
        let node_id = dom.create_text(op.text)
        id_map.set(op.id, node_id)
      }
      "appendChild" =>
        match (id_map.get(op.parent_id), id_map.get(op.child_id)) {
          (Some(parent), Some(child)) => {
            let _ = dom.append_child(parent, child)

          }
          _ => ()
        }
      "removeChild" =>
        match (id_map.get(op.parent_id), id_map.get(op.child_id)) {
          (Some(parent), Some(child)) => {
            let _ = dom.remove_child(parent, child)

          }
          _ => ()
        }
      "setAttribute" =>
        match id_map.get(op.id) {
          Some(node_id) => {
            let _ = dom.set_attribute(node_id, op.name, op.value)

          }
          None => ()
        }
      "removeAttribute" =>
        match id_map.get(op.id) {
          Some(node_id) => {
            let _ = dom.remove_attribute(node_id, op.name)

          }
          None => ()
        }
      "setTextContent" =>
        match id_map.get(op.id) {
          Some(node_id) => {
            let _ = dom.set_text_content(node_id, op.value)

          }
          None => ()
        }
      _ => ()
    }
  }
}

///|
/// Extract string field from JSON
fn extract_json_field(json : String, field : String) -> String {
  let pattern = "\"" + field + "\":\""
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut end = value_start
      while end < chars.length() {
        if chars[end] == '"' && (end == value_start || chars[end - 1] != '\\') {
          break
        }
        end = end + 1
      }
      json.unsafe_substring(start=value_start, end~)
    }
    None => ""
  }
}

///|
/// Extract string array from JSON
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
            if chars[str_end] == '"' && chars[str_end - 1] != '\\' {
              break
            }
            str_end = str_end + 1
          }
          result.push(json.unsafe_substring(start=str_start, end=str_end))
          i = str_end + 1
        } else {
          i = i + 1
        }
      }
      result
    }
    None => []
  }
}

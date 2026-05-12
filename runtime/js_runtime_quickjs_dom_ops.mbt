///|
/// QuickJS runtime DOM operation parsing and application
///
/// Converts the JSON domOps emitted by the JavaScript mock DOM into DomTree
/// mutations.

///|
/// DOM operation type
priv struct DomOp {
  op : String
  id : Int
  parent_id : Int
  child_id : Int
  ref_id : Int // Reference node ID for insertBefore
  tag_name : String
  text : String
  name : String
  value : String
  has_name : Bool
  has_value : Bool
  delegates_focus : Bool
  slot_assignment : String
  clonable : Bool
  serializable : Bool
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
    ref_id: parse_int_field(json, "refId"),
    tag_name: extract_json_field(json, "tagName"),
    text: extract_json_field(json, "text"),
    name: extract_json_field(json, "name"),
    value: extract_json_field(json, "value"),
    has_name: parse_bool_field(json, "hasName"),
    has_value: parse_bool_field(json, "hasValue"),
    delegates_focus: parse_bool_field(json, "delegatesFocus"),
    slot_assignment: extract_json_field(json, "slotAssignment"),
    clonable: parse_bool_field(json, "clonable"),
    serializable: parse_bool_field(json, "serializable"),
  }
}

///|
fn parse_bool_field(json : String, field : String) -> Bool {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let remaining = json.unsafe_substring(
        start=value_start,
        end=json.length(),
      )
      remaining.has_prefix("true")
    }
    None => false
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
        @string.parse_int(num_str) catch {
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
fn parse_custom_states_value(value : String) -> Array[String] {
  let states : Array[String] = []
  if value.is_empty() {
    return states
  }
  for part in value.split(" ") {
    let state = part.trim().to_string()
    if !state.is_empty() {
      states.push(state)
    }
  }
  states
}

///|
/// Resolve ID to NodeId for apply_dom_ops
/// If ID is in map, use mapped value; otherwise treat as direct DomTree NodeId
fn resolve_dom_id(id_map : Map[Int, @dom.NodeId], id : Int) -> @dom.NodeId? {
  match id_map.get(id) {
    Some(node_id) => Some(node_id)
    None =>
      // ID might be a direct DomTree NodeId (from DOM initialization)
      if id > 0 {
        Some(@dom.NodeId::from_int(id))
      } else {
        None
      }
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
      "createElement" =>
        match
          dom.create_runtime_node(op.id, @dom.Element, tag_name=op.tag_name) {
          Ok(node_id) => id_map.set(op.id, node_id)
          Err(_) => ()
        }
      "createTextNode" =>
        match dom.create_runtime_node(op.id, @dom.Text, text_content=op.text) {
          Ok(node_id) => id_map.set(op.id, node_id)
          Err(_) => ()
        }
      "createComment" =>
        match
          dom.create_runtime_node(op.id, @dom.Comment, text_content=op.text) {
          Ok(node_id) => id_map.set(op.id, node_id)
          Err(_) => ()
        }
      "createDocumentFragment" =>
        match dom.create_runtime_node(op.id, @dom.DocumentFragment) {
          Ok(node_id) => id_map.set(op.id, node_id)
          Err(_) => ()
        }
      "attachShadow" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(host), Some(shadow_root)) => {
            let init = @dom.ShadowRootInit::new(
              mode=op.value,
              delegates_focus=op.delegates_focus,
              slot_assignment=if op.slot_assignment.length() > 0 {
                op.slot_assignment
              } else {
                "named"
              },
              clonable=op.clonable,
              serializable=op.serializable,
            )
            let _ = dom.attach_existing_shadow_root_with_init(
              host, shadow_root, init,
            )
          }
          _ => ()
        }
      "appendChild" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(parent), Some(child)) => {
            let _ = dom.append_child(parent, child)
          }
          _ => ()
        }
      "insertBefore" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(parent), Some(child)) => {
            let ref_node = if op.ref_id > 0 {
              resolve_dom_id(id_map, op.ref_id)
            } else {
              None
            }
            let _ = dom.insert_before(parent, child, ref_node)
          }
          _ => ()
        }
      "replaceChild" => {
        let parent_id = resolve_dom_id(id_map, op.parent_id)
        let new_child_id = resolve_dom_id(id_map, op.child_id)
        let old_child_id = resolve_dom_id(id_map, op.ref_id)
        match (parent_id, new_child_id, old_child_id) {
          (Some(parent), Some(new_child), Some(old_child)) => {
            // replaceChild: insert new before old, then remove old
            let _ = dom.insert_before(parent, new_child, Some(old_child))
            let _ = dom.remove_child(parent, old_child)
          }
          _ => ()
        }
      }
      "removeChild" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(parent), Some(child)) => {
            let _ = dom.remove_child(parent, child)
          }
          _ => ()
        }
      "setAttribute" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let _ = dom.set_attribute(node_id, op.name, op.value)
          }
          None => ()
        }
      "removeAttribute" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let _ = dom.remove_attribute(node_id, op.name)
          }
          None => ()
        }
      "setCustomStates" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let _ = dom.set_custom_states(
              node_id,
              parse_custom_states_value(op.value),
            )
          }
          None => ()
        }
      "setFormValue" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let form_value = if op.has_name { Some(op.name) } else { None }
            let form_state_value = if op.has_value {
              Some(op.value)
            } else {
              None
            }
            let _ = dom.set_form_associated_state(
              node_id, form_value, form_state_value,
            )
          }
          None => ()
        }
      "setTextContent" =>
        match resolve_dom_id(id_map, op.id) {
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
      unescape_json_string(json.unsafe_substring(start=value_start, end~))
    }
    None => ""
  }
}

///|
fn unescape_json_string(value : String) -> String {
  let out = StringBuilder::new()
  let chars = value.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c != '\\' || i + 1 >= chars.length() {
      out.write_char(c)
      i = i + 1
      continue
    }
    let next = chars[i + 1]
    match next {
      '"' => out.write_char('"')
      '\\' => out.write_char('\\')
      '/' => out.write_char('/')
      'b' => out.write_char('\b')
      'f' => out.write_char('\u000C')
      'n' => out.write_char('\n')
      'r' => out.write_char('\r')
      't' => out.write_char('\t')
      'u' =>
        if i + 5 < chars.length() {
          let code = parse_json_hex4(
            chars[i + 2],
            chars[i + 3],
            chars[i + 4],
            chars[i + 5],
          )
          match code {
            Some(code) => out.write_char(code.unsafe_to_char())
            None => {
              out.write_char('\\')
              out.write_char('u')
              out.write_char(chars[i + 2])
              out.write_char(chars[i + 3])
              out.write_char(chars[i + 4])
              out.write_char(chars[i + 5])
            }
          }
          i = i + 6
          continue
        } else {
          out.write_char('\\')
          out.write_char('u')
        }
      _ => out.write_char(next)
    }
    i = i + 2
  }
  out.to_string()
}

///|
fn parse_json_hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(10 + c.to_int() - 'a'.to_int())
  } else if c >= 'A' && c <= 'F' {
    Some(10 + c.to_int() - 'A'.to_int())
  } else {
    None
  }
}

///|
fn parse_json_hex4(c0 : Char, c1 : Char, c2 : Char, c3 : Char) -> Int? {
  match
    (
      parse_json_hex_digit(c0),
      parse_json_hex_digit(c1),
      parse_json_hex_digit(c2),
      parse_json_hex_digit(c3),
    ) {
    (Some(d0), Some(d1), Some(d2), Some(d3)) =>
      Some(d0 * 4096 + d1 * 256 + d2 * 16 + d3)
    _ => None
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
          result.push(
            unescape_json_string(
              json.unsafe_substring(start=str_start, end=str_end),
            ),
          )
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

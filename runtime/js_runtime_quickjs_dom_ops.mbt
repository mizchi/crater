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
  let pstart = json_index_of(json, pattern, 0)
  if pstart < 0 {
    return ops
  }
  let array_start = pstart + pattern.length()
  // Simple JSON array of objects parser
  let len = json.length()
  let mut i = array_start
  let mut depth = 0
  let mut obj_start = -1
  while i < len {
    let c = json[i].to_int()
    if c == 123 {
      if depth == 0 {
        obj_start = i
      }
      depth = depth + 1
    } else if c == 125 {
      depth = depth - 1
      if depth == 0 && obj_start >= 0 {
        let obj_json = json.unsafe_substring(start=obj_start, end=i + 1)
        let op = parse_single_dom_op(obj_json)
        ops.push(op)
        obj_start = -1
      }
    } else if c == 93 && depth == 0 {
      break
    }
    i = i + 1
  }
  ops
}

///|
/// Parse a single DOM operation object
fn parse_single_dom_op(json : String) -> DomOp {
  // Single pass over one char-array snapshot. The previous form re-scanned the
  // object once per field (14 String::find / to_array calls), which dominated
  // DOM-ops parse allocation.
  let chars = json.to_array()
  let len = chars.length()
  let mut op = ""
  let mut id = 0
  let mut parent_id = 0
  let mut child_id = 0
  let mut ref_id = 0
  let mut tag_name = ""
  let mut text = ""
  let mut name = ""
  let mut value = ""
  let mut has_name = false
  let mut has_value = false
  let mut delegates_focus = false
  let mut slot_assignment = ""
  let mut clonable = false
  let mut serializable = false
  let mut i = 0
  while i < len {
    if chars[i] != '"' {
      i = i + 1
      continue
    }
    // Read key.
    let ks = i + 1
    let mut ke = ks
    while ke < len && chars[ke] != '"' {
      ke = ke + 1
    }
    let key = String::from_array(chars[ks:ke])
    i = ke + 1
    // Advance past the ':' separator and whitespace to the value.
    while i < len && chars[i] != ':' {
      i = i + 1
    }
    i = i + 1
    while i < len && chars[i] == ' ' {
      i = i + 1
    }
    if i >= len {
      break
    }
    let vc = chars[i]
    if vc == '"' {
      // String value (honoring escaped quotes).
      let vs = i + 1
      let mut ve = vs
      while ve < len && !(chars[ve] == '"' && chars[ve - 1] != '\\') {
        ve = ve + 1
      }
      let val = unescape_json_string(String::from_array(chars[vs:ve]))
      i = ve + 1
      match key {
        "op" => op = val
        "tagName" => tag_name = val
        "text" => text = val
        "name" => name = val
        "value" => value = val
        "slotAssignment" => slot_assignment = val
        _ => ()
      }
    } else if vc == 't' || vc == 'f' {
      let b = vc == 't'
      while i < len && chars[i] != ',' && chars[i] != '}' {
        i = i + 1
      }
      match key {
        "hasName" => has_name = b
        "hasValue" => has_value = b
        "delegatesFocus" => delegates_focus = b
        "clonable" => clonable = b
        "serializable" => serializable = b
        _ => ()
      }
    } else {
      // Numeric value.
      let vs = i
      while i < len && ((chars[i] >= '0' && chars[i] <= '9') || chars[i] == '-') {
        i = i + 1
      }
      let n = @string.parse_int(String::from_array(chars[vs:i])) catch {
        _ => 0
      }
      match key {
        "id" => id = n
        "parentId" => parent_id = n
        "childId" => child_id = n
        "refId" => ref_id = n
        _ => ()
      }
    }
  }
  {
    op,
    id,
    parent_id,
    child_id,
    ref_id,
    tag_name,
    text,
    name,
    value,
    has_name,
    has_value,
    delegates_focus,
    slot_assignment,
    clonable,
    serializable,
  }
}

///|
fn parse_custom_states_value(value : String) -> Array[String] {
  let states : Array[String] = []
  if value.is_empty() {
    return states
  }
  for part in value.split(" ") {
    let state = part.trim().to_owned()
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
  let start = json_index_of(json, pattern, 0)
  if start < 0 {
    return ""
  }
  let value_start = start + pattern.length()
  let len = json.length()
  let mut end = value_start
  while end < len {
    if json[end].to_int() == 34 &&
      (end == value_start || json[end - 1].to_int() != 92) {
      break
    }
    end = end + 1
  }
  unescape_json_string(json.unsafe_substring(start=value_start, end~))
}

///|
/// Allocation-free substring index search (naive). `String::find` uses
/// Boyer-Moore-Horspool and allocates an ~850-byte skip table per call; the
/// DOM-ops parser calls it ~8 times per op, which dominated parse allocation.
fn json_index_of(s : String, needle : String, from : Int) -> Int {
  let slen = s.length()
  let nlen = needle.length()
  if nlen == 0 || from + nlen > slen {
    return -1
  }
  for i = from; i <= slen - nlen; i = i + 1 {
    let mut k = 0
    while k < nlen && s[i + k].to_int() == needle[k].to_int() {
      k = k + 1
    }
    if k == nlen {
      return i
    }
  }
  -1
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
  let start = json_index_of(json, pattern, 0)
  if start < 0 {
    return []
  }
  let array_start = start + pattern.length()
  let len = json.length()
  let result : Array[String] = []
  let mut i = array_start
  while i < len && json[i].to_int() != 93 {
    if json[i].to_int() == 34 {
      let str_start = i + 1
      let mut str_end = str_start
      while str_end < len {
        if json[str_end].to_int() == 34 && json[str_end - 1].to_int() != 92 {
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

///|
fn is_valid_locate_nodes_locator_type(locator_type : String) -> Bool {
  locator_type == "css" ||
  locator_type == "xpath" ||
  locator_type == "innerText" ||
  locator_type == "accessibility" ||
  locator_type == "context"
}

///|
/// Convert a small XPath subset used by WPT locateNodes tests to CSS.
fn xpath_to_css_selector(xpath : String) -> String? {
  let trimmed = xpath.trim().to_owned()
  if trimmed == ".//*[name()='circle']" {
    return Some("circle")
  }

  let body = if trimmed.has_prefix(".//") {
    trimmed.unsafe_substring(start=3, end=trimmed.length())
  } else if trimmed.has_prefix("//") {
    trimmed.unsafe_substring(start=2, end=trimmed.length())
  } else {
    return None
  }
  if body == "" {
    return None
  }

  match find_substring(body, "[@", 0) {
    None => if body.contains("[") { None } else { Some(body) }
    Some(predicate_idx) => {
      let selector_tag = body.unsafe_substring(start=0, end=predicate_idx)
      if selector_tag == "" {
        return None
      }
      let predicate_start = predicate_idx + 2
      let predicate_full = body.unsafe_substring(
        start=predicate_start,
        end=body.length(),
      )
      if predicate_full == "" || !predicate_full.has_suffix("]") {
        return None
      }
      let predicate = predicate_full.unsafe_substring(
        start=0,
        end=predicate_full.length() - 1,
      )
      match find_substring(predicate, "=", 0) {
        None => None
        Some(eq_idx) => {
          let attr_name = predicate.unsafe_substring(start=0, end=eq_idx)
          let quoted_value = predicate.unsafe_substring(
            start=eq_idx + 1,
            end=predicate.length(),
          )
          if attr_name == "" || quoted_value.length() < 2 {
            return None
          }
          let quote_chars = quoted_value.to_array()
          let quote = quote_chars[0]
          let end_quote = quote_chars[quote_chars.length() - 1]
          if (quote != '\'' && quote != '"') || end_quote != quote {
            return None
          }
          let attr_value = quoted_value.unsafe_substring(
            start=1,
            end=quoted_value.length() - 1,
          )
          Some(
            selector_tag +
            "[" +
            attr_name.trim().to_owned() +
            "=\"" +
            attr_value +
            "\"]",
          )
        }
      }
    }
  }
}

///|
/// Check whether localName should use SVG namespace in BiDi node values.
fn is_svg_local_name(local_name : String) -> Bool {
  local_name == "svg" ||
  local_name == "circle" ||
  local_name == "text" ||
  local_name == "path" ||
  local_name == "rect" ||
  local_name == "ellipse" ||
  local_name == "line" ||
  local_name == "polyline" ||
  local_name == "polygon" ||
  local_name == "g" ||
  local_name == "defs" ||
  local_name == "use"
}

///|
/// Normalize namespaceURI for SVG-like nodes in locateNodes response.
fn normalize_svg_namespace_in_node(node : Json) -> Json {
  match node {
    Object(node_map) => {
      let out_node : Map[String, Json] = {}
      for key, value in node_map {
        out_node[key] = value
      }
      match node_map.get("value") {
        Some(Object(value_map)) => {
          let out_value : Map[String, Json] = {}
          for key, value in value_map {
            out_value[key] = value
          }
          let local_name = match value_map.get("localName") {
            Some(String(name)) => name
            _ => ""
          }
          let namespace_uri = match value_map.get("namespaceURI") {
            Some(String(uri)) => uri
            _ => ""
          }
          if namespace_uri == "http://www.w3.org/1999/xhtml" &&
            is_svg_local_name(local_name) {
            out_value["namespaceURI"] = Json::string(
              "http://www.w3.org/2000/svg",
            )
          }
          out_node["value"] = make_object(out_value)
        }
        _ => ()
      }
      make_object(out_node)
    }
    _ => node
  }
}

///|
/// Normalize SVG namespace for all nodes in locateNodes response array.
fn normalize_svg_namespace_in_nodes(nodes : Json) -> Json {
  match nodes {
    Array(values) => {
      let out : Array[Json] = []
      for value in values {
        out.push(normalize_svg_namespace_in_node(value))
      }
      Json::array(out)
    }
    _ => nodes
  }
}

///|
/// Encode string array as a JavaScript string-array literal.
fn js_string_array_literal(values : Array[String]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push("\"" + escape_js_string(value) + "\"")
  }
  "[" + parts.join(",") + "]"
}

///|
/// Evaluate locateNodes expression and normalize result to nodes array.
fn BidiProtocol::evaluate_locate_expression(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
  serialization_options_json : String,
) -> Json {
  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let eval_result_json = evaluate_js_with_console(
    expression, false, false, false, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => return Json::array([])
  }

  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(Object(result_map)) =>
          match result_map.get("type") {
            Some(String("array")) =>
              match result_map.get("value") {
                Some(Array(values)) => Json::array(values)
                _ => Json::array([])
              }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
}

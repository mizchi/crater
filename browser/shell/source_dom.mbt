///|
fn build_dom_tree_from_document(doc : @html.Document) -> @dom.DomTree {
  let dom = @dom.DomTree::new()
  let doc_id = dom.get_document()
  let root_id = build_dom_element(dom, doc.root)
  let _ = dom.append_child(doc_id, root_id)
  dom
}

///|
fn html_source_has_declarative_shadow_dom(html : String) -> Bool {
  html.to_lower().contains("shadowrootmode")
}

///|
priv struct SourceHtmlFragment {
  attrs : Array[(String, String)]
  inner_html : String
}

///|
priv struct NormalizedShadowSourceHtml {
  render_html : String
  snapshot_html : String
  parsed_doc : @html.Document
}

///|
fn is_html_attr_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn parse_html_attributes(raw : String) -> Array[(String, String)] {
  let attrs : Array[(String, String)] = []
  let mut i = 0
  while i < raw.length() {
    while i < raw.length() && is_html_attr_whitespace(char_at(raw, i)) {
      i = i + 1
    }
    if i >= raw.length() {
      break
    }
    if char_at(raw, i) == '/' {
      i = i + 1
      continue
    }
    let name_start = i
    while i < raw.length() {
      let c = char_at(raw, i)
      if is_html_attr_whitespace(c) || c == '=' || c == '>' || c == '/' {
        break
      }
      i = i + 1
    }
    let name = raw.unsafe_substring(start=name_start, end=i).trim().to_owned()
    while i < raw.length() && is_html_attr_whitespace(char_at(raw, i)) {
      i = i + 1
    }
    let mut value = ""
    if i < raw.length() && char_at(raw, i) == '=' {
      i = i + 1
      while i < raw.length() && is_html_attr_whitespace(char_at(raw, i)) {
        i = i + 1
      }
      if i < raw.length() {
        let quote = char_at(raw, i)
        if quote == '"' || quote == '\'' {
          i = i + 1
          let value_start = i
          while i < raw.length() && char_at(raw, i) != quote {
            i = i + 1
          }
          value = raw.unsafe_substring(start=value_start, end=i)
          if i < raw.length() {
            i = i + 1
          }
        } else {
          let value_start = i
          while i < raw.length() {
            let c = char_at(raw, i)
            if is_html_attr_whitespace(c) || c == '>' {
              break
            }
            i = i + 1
          }
          value = raw.unsafe_substring(start=value_start, end=i)
        }
      }
    }
    if name.length() > 0 {
      attrs.push((name, value))
    }
  }
  attrs
}

///|
fn extract_source_html_fragment(
  html : String,
  tag : String,
) -> SourceHtmlFragment? {
  let lower = html.to_lower()
  let open_needle = "<" + tag
  match lower.find(open_needle) {
    Some(start) => {
      let mut open_end = start
      while open_end < html.length() && char_at(html, open_end) != '>' {
        open_end = open_end + 1
      }
      if open_end >= html.length() {
        return None
      }
      let attr_source = html
        .unsafe_substring(start=start + open_needle.length(), end=open_end)
        .trim()
        .to_owned()
      let close_needle = "</" + tag + ">"
      let inner_html = match lower.find(close_needle) {
        Some(close_start) if close_start > open_end =>
          html.unsafe_substring(start=open_end + 1, end=close_start)
        _ => ""
      }
      Some({ attrs: parse_html_attributes(attr_source), inner_html })
    }
    None => None
  }
}

///|
fn write_set_attributes_js(
  buf : StringBuilder,
  target_expr : String,
  attrs : Array[(String, String)],
) -> Unit {
  for pair in attrs {
    let (name, value) = pair
    buf.write_string(target_expr)
    buf.write_string(".setAttribute('")
    buf.write_string(escape_js_string(name))
    buf.write_string("', '")
    buf.write_string(escape_js_string(value))
    buf.write_string("');")
  }
}

///|
fn create_empty_html_dom_tree() -> @dom.DomTree {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let head = dom.create_element("head")
  let body = dom.create_element("body")
  let doc_id = dom.get_document()
  let _ = dom.append_child(doc_id, html)
  let _ = dom.append_child(html, head)
  let _ = dom.append_child(html, body)
  dom
}

///|
fn normalize_declarative_shadow_source_html_with_hint(
  html : String,
  has_declarative_shadow_dom : Bool,
) -> NormalizedShadowSourceHtml? {
  if !has_declarative_shadow_dom {
    return None
  }
  match build_dom_tree_from_source_html(html) {
    Some(dom) => {
      let render_html = @js.serialize_dom_to_html(dom)
      if render_html.length() == 0 {
        return None
      }
      let snapshot_html = @js.serialize_dom_to_snapshot_html(dom)
      let parsed_doc = @html.assign_synthetic_ids(
        @html.parse_document(render_html),
      )
      Some({ render_html, snapshot_html, parsed_doc })
    }
    None => None
  }
}

///|
let crater_form_value_attr_name = "data-crater-form-value"

///|
let crater_form_state_attr_name = "data-crater-form-state-value"

///|
fn html_source_has_internal_form_restore_state(html : String) -> Bool {
  html.contains(crater_form_value_attr_name) ||
  html.contains(crater_form_state_attr_name)
}

///|
fn html_source_requires_runtime_rebuild(html : String) -> Bool {
  html_source_has_declarative_shadow_dom(html) ||
  html_source_has_internal_form_restore_state(html)
}

///|
fn consume_internal_form_restore_state_recursive(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
) -> Unit {
  let info = dom.get_node_info(node_id)
  guard info is Ok(info) else { return }
  if info.node_type == @dom.Element {
    let form_value = dom
      .get_attribute(node_id, crater_form_value_attr_name)
      .unwrap_or(None)
    let form_state_value = dom
      .get_attribute(node_id, crater_form_state_attr_name)
      .unwrap_or(None)
    if form_value != None || form_state_value != None {
      let _ = dom.set_form_associated_state(
        node_id, form_value, form_state_value,
      )
      let _ = dom.remove_attribute(node_id, crater_form_value_attr_name)
      let _ = dom.remove_attribute(node_id, crater_form_state_attr_name)
    }
  }
  match dom.get_children(node_id) {
    Ok(children) =>
      for child_id in children {
        consume_internal_form_restore_state_recursive(dom, child_id)
      }
    Err(_) => ()
  }
  match dom.get_shadow_root(node_id) {
    Ok(Some(shadow_root_id)) =>
      consume_internal_form_restore_state_recursive(dom, shadow_root_id)
    _ => ()
  }
}

///|
fn consume_internal_form_restore_state(dom : @dom.DomTree) -> Unit {
  consume_internal_form_restore_state_recursive(dom, dom.get_document())
}

///|
fn build_dom_tree_from_source_html(html : String) -> @dom.DomTree? {
  if html.length() == 0 {
    return None
  }
  let dom = create_empty_html_dom_tree()
  let ctx = @js.JsContext::new_deferred(dom)
  let html_fragment = extract_source_html_fragment(html, "html")
  let head_fragment = extract_source_html_fragment(html, "head")
  let body_fragment = extract_source_html_fragment(html, "body")
  let body_inner_html = match body_fragment {
    Some(fragment) => fragment.inner_html
    None => html
  }
  let source = StringBuilder::new()
  source.write_string("(function(){")
  source.write_string("const htmlEl=document.documentElement;")
  source.write_string("const headEl=document.head;")
  source.write_string("const bodyEl=document.body;")
  match html_fragment {
    Some(fragment) => write_set_attributes_js(source, "htmlEl", fragment.attrs)
    None => ()
  }
  match head_fragment {
    Some(fragment) => {
      write_set_attributes_js(source, "headEl", fragment.attrs)
      source.write_string("headEl.setHTMLUnsafe('")
      source.write_string(escape_js_string(fragment.inner_html))
      source.write_string("');")
    }
    None => source.write_string("headEl.setHTMLUnsafe('');")
  }
  match body_fragment {
    Some(fragment) => {
      write_set_attributes_js(source, "bodyEl", fragment.attrs)
      source.write_string("bodyEl.setHTMLUnsafe('")
      source.write_string(escape_js_string(fragment.inner_html))
      source.write_string("');")
    }
    None => {
      source.write_string("bodyEl.setHTMLUnsafe('")
      source.write_string(escape_js_string(body_inner_html))
      source.write_string("');")
    }
  }
  source.write_string("return 'ok';})()")
  try {
    let result = ctx.execute(source.to_string())
    if result.success {
      consume_internal_form_restore_state(dom)
      Some(dom)
    } else {
      None
    }
  } catch {
    _ => None
  }
}

///|
fn get_declarative_shadow_root_init(
  elem : @html.Element,
) -> @dom.ShadowRootInit? {
  if elem.tag.to_lower() != "template" {
    return None
  }
  match elem.attributes.get("shadowrootmode") {
    Some(mode) => {
      let mode = mode.to_lower()
      if mode != "open" && mode != "closed" {
        return None
      }
      Some(
        @dom.ShadowRootInit::new(
          mode~,
          delegates_focus=elem.attributes.contains("shadowrootdelegatesfocus"),
          slot_assignment=if elem.attributes.contains(
              "shadowrootslotassignment",
            ) {
            match elem.attributes.get("shadowrootslotassignment") {
              Some(value) if value.to_lower() == "manual" => "manual"
              _ => "named"
            }
          } else {
            "named"
          },
          clonable=elem.attributes.contains("shadowrootclonable"),
          serializable=elem.attributes.contains("shadowrootserializable"),
        ),
      )
    }
    None => None
  }
}

///|
fn build_dom_children(
  dom : @dom.DomTree,
  parent_id : @dom.NodeId,
  children : Array[@html.Node],
) -> Unit {
  for child in children {
    match child {
      @html.Node::Element(child_elem) =>
        match get_declarative_shadow_root_init(child_elem) {
          Some(shadow_init) =>
            match dom.get_shadow_root(parent_id) {
              Ok(None) => {
                let shadow_root = dom
                  .attach_shadow_with_init(parent_id, shadow_init)
                  .unwrap()
                build_dom_children(dom, shadow_root, child_elem.children)
              }
              _ => {
                let child_id = build_dom_element(dom, child_elem)
                let _ = dom.append_child(parent_id, child_id)
              }
            }
          None => {
            let child_id = build_dom_element(dom, child_elem)
            let _ = dom.append_child(parent_id, child_id)
          }
        }
      @html.Node::Text(text) =>
        if text.length() > 0 {
          let text_id = dom.create_text(text)
          let _ = dom.append_child(parent_id, text_id)
        }
    }
  }
}

///|
fn build_dom_element(dom : @dom.DomTree, elem : @html.Element) -> @dom.NodeId {
  let node_id = dom.create_element(elem.tag)
  match elem.id {
    Some(id) => {
      let _ = dom.set_attribute(node_id, "id", id)
    }
    None => ()
  }
  for name, value in elem.attributes {
    let _ = dom.set_attribute(node_id, name, value)
  }
  build_dom_children(dom, node_id, elem.children)
  node_id
}

///|
struct RenderRequest {
  html : String
  css : Array[String]
  target_id : String?
  target_selector : String?
  viewport_width : Int
  viewport_height : Int
}

///|
struct ResolvedTarget {
  element : @html.Element
  target_id : String
}

///|
struct LandmarkTree {
  role : String
  name : String?
  source_id : String?
  children : Array[LandmarkTree]
}

///|
let artifact_schema_version = 1

///|
fn RenderRequest::render_ctx(self : RenderRequest) -> @renderer.RenderContext {
  {
    viewport_width: self.viewport_width.to_double(),
    viewport_height: self.viewport_height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
}

///|
fn parse_component_document(request : RenderRequest) -> @html.Document {
  @html.assign_synthetic_ids(@html.parse_document(request.html))
}

///|
fn child_html_elements(children : Array[@html.Node]) -> Array[@html.Element] {
  let elements : Array[@html.Element] = []
  for child in children {
    match child {
      @html.Node::Element(child_elem) => elements.push(child_elem)
      _ => ()
    }
  }
  elements
}

///|
fn html_to_selector_element(
  element : @html.Element,
  parent : @css.Element?,
  sibling_index : Int,
  sibling_count : Int,
  prev_sibling : @css.Element?,
) -> @css.Element {
  let mut selector_element = @css.Element::new(element.tag)
  match element.id {
    Some(id) => selector_element = selector_element.set_id(id)
    None => ()
  }
  for cls in element.classes {
    selector_element = selector_element.add_class(cls)
  }
  element.attributes.each(fn(name, value) {
    selector_element = selector_element.set_attribute(name, value)
  })
  match parent {
    Some(parent) => selector_element = selector_element.set_parent(parent)
    None => ()
  }
  selector_element = selector_element.set_sibling_info(
    sibling_index, sibling_count,
  )
  selector_element = { ..selector_element, prev_sibling, }
  let html_children = child_html_elements(element.children)
  let selector_children : Array[@css.Element] = []
  let mut prev_child : @css.Element? = None
  for i = 0; i < html_children.length(); i = i + 1 {
    let child_selector = html_to_selector_element(
      html_children[i],
      Some(selector_element),
      i + 1,
      html_children.length(),
      prev_child,
    )
    selector_children.push(child_selector)
    prev_child = Some(child_selector)
  }
  { ..selector_element, children: selector_children }
}

///|
fn find_component_element_by_id(
  element : @html.Element,
  target_id : String,
) -> @html.Element? {
  match element.id {
    Some(id) if id == target_id => return Some(element)
    _ => ()
  }
  for child in element.children {
    match child {
      @html.Node::Element(child_elem) =>
        match find_component_element_by_id(child_elem, target_id) {
          Some(found) => return Some(found)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn find_component_element_by_selector(
  element : @html.Element,
  selector_list : @css.SelectorList,
  selector_element : @css.Element,
) -> @html.Element? {
  if @css.matches_selector_list(selector_element, selector_list) {
    return Some(element)
  }
  let html_children = child_html_elements(element.children)
  let mut prev_child_selector : @css.Element? = None
  for i = 0; i < html_children.length(); i = i + 1 {
    let child_elem = html_children[i]
    let child_selector = html_to_selector_element(
      child_elem,
      Some(selector_element),
      i + 1,
      html_children.length(),
      prev_child_selector,
    )
    prev_child_selector = Some(child_selector)
    match
      find_component_element_by_selector(
        child_elem, selector_list, child_selector,
      ) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn target_label(request : RenderRequest) -> String {
  match request.target_id {
    Some(target_id) => "#" + target_id
    None =>
      match request.target_selector {
        Some(selector) => selector
        None => "<missing-target>"
      }
  }
}

///|
fn resolve_target(request : RenderRequest) -> Result[ResolvedTarget, String] {
  let doc = parse_component_document(request)
  match request.target_id {
    Some(target_id) =>
      match find_component_element_by_id(doc.root, target_id) {
        Some(element) => Ok({ element, target_id })
        None => Err("Target element not found: #" + target_id)
      }
    None =>
      match request.target_selector {
        Some(selector_text) =>
          match @css.parse_selector_list(selector_text) {
            Some(selector_list) => {
              let root_selector = html_to_selector_element(
                doc.root,
                None,
                1,
                1,
                None,
              )
              match
                find_component_element_by_selector(
                  doc.root,
                  selector_list,
                  root_selector,
                ) {
                Some(element) =>
                  match element.id {
                    Some(target_id) => Ok({ element, target_id })
                    None =>
                      Err(
                        "Target element is missing a resolved id: " +
                        selector_text,
                      )
                  }
                None => Err("Target element not found: " + selector_text)
              }
            }
            None => Err("Invalid selector: " + selector_text)
          }
        None => Err("No target specified")
      }
  }
}

///|
fn collect_landmark_forest(
  node : @aom.AccessibilityNode,
) -> Array[LandmarkTree] {
  let children : Array[LandmarkTree] = []
  for child in node.children {
    let child_landmarks = collect_landmark_forest(child)
    for landmark in child_landmarks {
      children.push(landmark)
    }
  }
  if @aom.role_is_landmark(node.role) {
    let landmark : LandmarkTree = {
      role: node.role.to_string(),
      name: node.name,
      source_id: node.source_id,
      children,
    }
    [landmark]
  } else {
    children
  }
}

///|
fn json_escape_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn render_landmark_node_json(node : LandmarkTree, buf : StringBuilder) -> Unit {
  buf.write_string("{\"role\":\"")
  buf.write_string(json_escape_string(node.role))
  buf.write_string("\"")
  match node.name {
    Some(name) if !name.is_empty() => {
      buf.write_string(",\"name\":\"")
      buf.write_string(json_escape_string(name))
      buf.write_string("\"")
    }
    _ => ()
  }
  match node.source_id {
    Some(source_id) if !source_id.is_empty() => {
      buf.write_string(",\"sourceId\":\"")
      buf.write_string(json_escape_string(source_id))
      buf.write_string("\"")
    }
    _ => ()
  }
  buf.write_string(",\"children\":[")
  for i = 0; i < node.children.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",")
    }
    render_landmark_node_json(node.children[i], buf)
  }
  buf.write_string("]}")
}

///|
fn render_landmark_forest_json(forest : Array[LandmarkTree]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[")
  for i = 0; i < forest.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",")
    }
    render_landmark_node_json(forest[i], buf)
  }
  buf.write_string("]")
  buf.to_string()
}

///|
fn write_artifact_metadata_prefix(
  buf : StringBuilder,
  target_id : String,
  viewport_width : Int,
  viewport_height : Int,
  artifact : String,
) -> Unit {
  buf.write_string("{\"schemaVersion\":")
  buf.write_string(artifact_schema_version.to_string())
  buf.write_string(",\"artifact\":\"")
  buf.write_string(json_escape_string(artifact))
  buf.write_string("\",\"targetId\":\"")
  buf.write_string(json_escape_string(target_id))
  buf.write_string("\",\"viewport\":{\"width\":")
  buf.write_string(viewport_width.to_string())
  buf.write_string(",\"height\":")
  buf.write_string(viewport_height.to_string())
  buf.write_string("}")
}

///|
fn node_id_matches_target(node_id : String, target_id : String) -> Bool {
  node_id == target_id || node_id.has_suffix("#" + target_id)
}

///|
fn find_component_subtree(
  node : @node.Node,
  layout : @types.Layout,
  target_id : String,
) -> (@node.Node, @types.Layout)? {
  if node_id_matches_target(node.id, target_id) &&
    node_id_matches_target(layout.id, target_id) {
    return Some((node, layout))
  }
  let child_count = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  for i = 0; i < child_count; i = i + 1 {
    match
      find_component_subtree(node.children[i], layout.children[i], target_id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn normalize_component_layout(layout : @types.Layout) -> @types.Layout {
  { ..layout, x: 0.0, y: 0.0 }
}

///|
fn pixel_span(value : Double) -> Int {
  let rounded = value.ceil().to_int()
  if rounded > 0 {
    rounded
  } else {
    1
  }
}

///|
fn render_request_node_and_layout(
  request : RenderRequest,
) -> (@node.Node, @types.Layout) {
  @renderer.render_to_node_and_layout_with_external_css(
    request.html,
    request.render_ctx(),
    request.css,
  )
}

///|
fn render_component_subtree(
  request : RenderRequest,
) -> Result[(@node.Node, @types.Layout, String), String] {
  match resolve_target(request) {
    Ok(target) => {
      let (node, layout) = render_request_node_and_layout(request)
      match find_component_subtree(node, layout, target.target_id) {
        Some((matched_node, matched_layout)) =>
          Ok((matched_node, matched_layout, target.target_id))
        None =>
          Err(
            "Target subtree not found in render output: " +
            target_label(request),
          )
      }
    }
    Err(error) => Err(error)
  }
}

///|
fn render_layout_artifact(request : RenderRequest) -> Result[String, String] {
  match render_component_subtree(request) {
    Ok((_node, layout, target_id)) => {
      let buf = StringBuilder::new()
      write_artifact_metadata_prefix(
        buf,
        target_id,
        request.viewport_width,
        request.viewport_height,
        "layout",
      )
      buf.write_string(",\"data\":")
      buf.write_string(
        @renderer.layout_to_json(normalize_component_layout(layout)),
      )
      buf.write_string("}")
      Ok(buf.to_string())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_component_paint_node(
  request : RenderRequest,
) -> Result[(@tui_paint_plain.PaintNode, Int, Int, String), String] {
  match render_component_subtree(request) {
    Ok((node, layout, target_id)) => {
      let normalized = normalize_component_layout(layout)
      let paint_node = @tui_paint_plain.from_node_and_layout(node, normalized)
      let width = pixel_span(normalized.width)
      let height = pixel_span(normalized.height)
      Ok((paint_node, width, height, target_id))
    }
    Err(error) => Err(error)
  }
}

///|

///|
fn build_image_artifact_json(
  target_id : String,
  viewport_width : Int,
  viewport_height : Int,
  data : String,
  width : Int,
  height : Int,
) -> String {
  let buf = StringBuilder::new()
  write_artifact_metadata_prefix(
    buf, target_id, viewport_width, viewport_height, "image",
  )
  buf.write_string(",\"encoding\":\"png-base64\",\"width\":")
  buf.write_string(width.to_string())
  buf.write_string(",\"height\":")
  buf.write_string(height.to_string())
  buf.write_string(",\"data\":\"")
  buf.write_string(json_escape_string(data))
  buf.write_string("\"}")
  buf.to_string()
}

///|
fn render_image_artifact(request : RenderRequest) -> Result[String, String] {
  match render_component_paint_node(request) {
    Ok((paint_node, width, height, target_id)) => {
      let data = @tui_paint_png.raster_to_png_base64(paint_node, width, height)
      Ok(
        build_image_artifact_json(
          target_id,
          request.viewport_width,
          request.viewport_height,
          data,
          width,
          height,
        ),
      )
    }
    Err(error) => Err(error)
  }
}

///|
fn render_landmark_artifact(request : RenderRequest) -> Result[String, String] {
  match resolve_target(request) {
    Ok(target) => {
      let tree = @aom.build_accessibility_tree_from_element(target.element)
      let buf = StringBuilder::new()
      write_artifact_metadata_prefix(
        buf,
        target.target_id,
        request.viewport_width,
        request.viewport_height,
        "landmarks",
      )
      buf.write_string(",\"data\":")
      buf.write_string(
        render_landmark_forest_json(collect_landmark_forest(tree.root)),
      )
      buf.write_string("}")
      Ok(buf.to_string())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_artifact_or_error(
  request : RenderRequest,
  mode : ArtifactMode,
) -> Result[String, String] {
  match mode {
    Layout => render_layout_artifact(request)
    Image => render_image_artifact(request)
    Landmarks => render_landmark_artifact(request)
  }
}

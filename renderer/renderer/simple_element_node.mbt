///|
// Simple inline-style-only HTML element to layout node conversion.

///|
/// Convert HTML Element to Node tree for layout computation
pub fn element_to_node(
  elem : @html.Element,
  parent_style : @style.Style?,
) -> @node.Node {
  // Compute style from inline style attribute with parent for inheritance
  let ctx = match parent_style {
    Some(ps) => @css.ComputeContext::with_parent(ps)
    None => @css.ComputeContext::new()
  }
  let style = match elem.style {
    Some(css) => @css.compute_inline_style(css, ctx)
    None =>
      // When no inline style, inherit from parent if available
      match parent_style {
        Some(ps) => {
          let inherited = @style.Style::default()
          // Copy inherited properties from parent
          inherited.writing_mode = ps.writing_mode
          inherited.direction = ps.direction
          inherited.color = ps.color
          inherited.pointer_events = ps.pointer_events
          inherited
        }
        None => @style.Style::default()
      }
  }

  // Convert children
  let children : Array[@node.Node] = []
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let child_node = element_to_node(child_elem, Some(style))
        children.push(child_node)
      }
      @html.Node::Text(_text) =>
        // For now, we ignore text nodes in layout
        // In a real implementation, we'd create inline boxes
        ()
    }
  }

  // Create node ID from tag and id/class
  let node_id = match elem.id {
    Some(id) => elem.tag + "#" + id
    None =>
      if elem.classes.length() > 0 {
        elem.tag + "." + elem.classes[0]
      } else {
        elem.tag
      }
  }
  if children.is_empty() {
    @node.Node::leaf(node_id, style)
  } else {
    @node.Node::new(node_id, style, children)
  }
}

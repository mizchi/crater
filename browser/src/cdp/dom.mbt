///|
/// CDP DOM Domain
///
/// Implements Chrome DevTools Protocol DOM domain.
/// Maps CDP operations to Core Primitives.

///|
/// DOM Domain handler
pub struct DomDomain {
  tree : @dom.DomTree
}

///|
/// Create new DOM domain
pub fn DomDomain::new(tree : @dom.DomTree) -> DomDomain {
  { tree, }
}

// =============================================================================
// Document Operations (DOM.getDocument, DOM.requestChildNodes)
// =============================================================================

///|
/// DOM.getDocument - Returns the root DOM node
pub fn DomDomain::get_document(
  self : DomDomain,
  depth : Int?, // Optional depth to include
) -> Result[CdpNode, CdpError] {
  let root = self.tree.get_document()
  let max_depth = depth.unwrap_or(1)
  self.node_to_cdp(root, 0, max_depth)
}

///|
/// DOM.requestChildNodes - Requests child nodes for the given node
pub fn DomDomain::request_child_nodes(
  self : DomDomain,
  node_id : Int,
  depth : Int?,
) -> Result[Array[CdpNode], CdpError] {
  let max_depth = depth.unwrap_or(1)
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.get_children(node) {
    Ok(children) => {
      let cdp_children : Array[CdpNode] = []
      for child in children {
        match self.node_to_cdp(child, 0, max_depth) {
          Ok(cdp_node) => cdp_children.push(cdp_node)
          Err(e) => return Err(e)
        }
      }
      Ok(cdp_children)
    }
    Err(e) => Err(core_to_cdp_error(e))
  }
}

// =============================================================================
// Query Operations (DOM.querySelector, DOM.querySelectorAll)
// =============================================================================

///|
/// DOM.querySelector - Executes querySelector on a given node
pub fn DomDomain::query_selector(
  self : DomDomain,
  node_id : Int,
  selector : String,
) -> Result[Int?, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.query_selector(node, selector) {
    Ok(result) =>
      match result {
        Some(found) => Ok(Some(found.to_int()))
        None => Ok(None)
      }
    Err(e) => Err(core_to_cdp_error(e))
  }
}

///|
/// DOM.querySelectorAll - Executes querySelectorAll on a given node
pub fn DomDomain::query_selector_all(
  self : DomDomain,
  node_id : Int,
  selector : String,
) -> Result[Array[Int], CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.query_selector_all(node, selector) {
    Ok(results) => Ok(results.map(fn(n) { n.to_int() }))
    Err(e) => Err(core_to_cdp_error(e))
  }
}

// =============================================================================
// Attribute Operations
// =============================================================================

///|
/// DOM.getAttributes - Returns attributes for the given node
pub fn DomDomain::get_attributes(
  self : DomDomain,
  node_id : Int,
) -> Result[Array[String], CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.get_attributes(node) {
    Ok(attrs) => {
      // CDP returns [name, value, name, value, ...]
      let result : Array[String] = []
      for pair in attrs {
        result.push(pair.0)
        result.push(pair.1)
      }
      Ok(result)
    }
    Err(e) => Err(core_to_cdp_error(e))
  }
}

///|
/// DOM.setAttributeValue - Sets attribute value
pub fn DomDomain::set_attribute_value(
  self : DomDomain,
  node_id : Int,
  name : String,
  value : String,
) -> Result[Unit, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.set_attribute(node, name, value) {
    Ok(_) => Ok(())
    Err(e) => Err(core_to_cdp_error(e))
  }
}

///|
/// DOM.removeAttribute - Removes attribute
pub fn DomDomain::remove_attribute(
  self : DomDomain,
  node_id : Int,
  name : String,
) -> Result[Unit, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.remove_attribute(node, name) {
    Ok(_) => Ok(())
    Err(e) => Err(core_to_cdp_error(e))
  }
}

// =============================================================================
// Node Operations
// =============================================================================

///|
/// DOM.getOuterHTML - Returns node's outer HTML
pub fn DomDomain::get_outer_html(
  self : DomDomain,
  node_id : Int,
) -> Result[String, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.get_node_info(node) {
    Ok(info) =>
      match info.node_type {
        @dom.Text => Ok(info.node_value)
        @dom.Element => {
          // Build outer HTML
          let buf = StringBuilder::new()
          self.build_outer_html(node, buf)
          Ok(buf.to_string())
        }
        _ => Ok("")
      }
    Err(e) => Err(core_to_cdp_error(e))
  }
}

///|
/// DOM.setNodeValue - Sets node value (for text nodes)
pub fn DomDomain::set_node_value(
  self : DomDomain,
  node_id : Int,
  value : String,
) -> Result[Unit, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.set_text_content(node, value) {
    Ok(_) => Ok(())
    Err(e) => Err(core_to_cdp_error(e))
  }
}

///|
/// DOM.removeNode - Removes node from the tree
pub fn DomDomain::remove_node(
  self : DomDomain,
  node_id : Int,
) -> Result[Unit, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.get_parent(node) {
    Ok(Some(parent)) =>
      match self.tree.remove_child(parent, node) {
        Ok(_) => Ok(())
        Err(e) => Err(core_to_cdp_error(e))
      }
    Ok(None) =>
      Err(CdpError::from_code(InvalidParams, "Cannot remove root node"))
    Err(e) => Err(core_to_cdp_error(e))
  }
}

// =============================================================================
// Box Model
// =============================================================================

///|
/// DOM.getBoxModel - Returns box model for the given node
pub fn DomDomain::get_box_model(
  self : DomDomain,
  node_id : Int,
) -> Result[CdpBoxModel, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  match self.tree.get_cached_rect(node) {
    Some(rect) => {
      // Convert Rect to box model (simplified - all boxes same)
      let quad = [
        rect.x,
        rect.y,
        rect.x + rect.width,
        rect.y,
        rect.x + rect.width,
        rect.y + rect.height,
        rect.x,
        rect.y + rect.height,
      ]
      Ok({
        content: quad,
        padding: quad,
        border: quad,
        margin: quad,
        width: rect.width.to_int(),
        height: rect.height.to_int(),
      })
    }
    None =>
      // Return zero box if no layout computed
      Ok({
        content: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        padding: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        border: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        margin: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        width: 0,
        height: 0,
      })
  }
}

// =============================================================================
// Internal Helpers
// =============================================================================

///|
/// Convert core NodeId to CDP node representation
fn DomDomain::node_to_cdp(
  self : DomDomain,
  node : @dom.NodeId,
  current_depth : Int,
  max_depth : Int,
) -> Result[CdpNode, CdpError] {
  match self.tree.get_node_info(node) {
    Ok(info) => {
      let node_type = match info.node_type {
        @dom.Document => 9
        @dom.Element => 1
        @dom.Text => 3
        @dom.Comment => 8
        @dom.DocumentType => 10
      }
      // Get attributes for elements
      let attributes : Array[String]? = match info.node_type {
        @dom.Element =>
          match self.tree.get_attributes(node) {
            Ok(attrs) => {
              let arr : Array[String] = []
              for pair in attrs {
                arr.push(pair.0)
                arr.push(pair.1)
              }
              Some(arr)
            }
            Err(_) => None
          }
        _ => None
      }
      // Get children if within depth limit
      let children : Array[CdpNode]? = if current_depth < max_depth {
        match self.tree.get_children(node) {
          Ok(child_nodes) => {
            let cdp_children : Array[CdpNode] = []
            for child in child_nodes {
              match self.node_to_cdp(child, current_depth + 1, max_depth) {
                Ok(cdp_child) => cdp_children.push(cdp_child)
                Err(_) => () // Skip failed children
              }
            }
            Some(cdp_children)
          }
          Err(_) => None
        }
      } else {
        None
      }
      Ok({
        node_id: node.to_int(),
        backend_node_id: node.to_int(),
        node_type,
        node_name: info.node_name.to_upper(),
        local_name: info.node_name.to_lower(),
        node_value: info.node_value,
        child_node_count: Some(info.child_count),
        children,
        attributes,
      })
    }
    Err(e) => Err(core_to_cdp_error(e))
  }
}

///|
/// Build outer HTML recursively
fn DomDomain::build_outer_html(
  self : DomDomain,
  node : @dom.NodeId,
  buf : StringBuilder,
) -> Unit {
  match self.tree.get_node_info(node) {
    Ok(info) =>
      match info.node_type {
        @dom.Text => buf.write_string(info.node_value)
        @dom.Comment => {
          buf.write_string("<!--")
          buf.write_string(info.node_value)
          buf.write_string("-->")
        }
        @dom.Element => {
          buf.write_string("<")
          buf.write_string(info.node_name)
          // Add attributes
          match self.tree.get_attributes(node) {
            Ok(attrs) =>
              for pair in attrs {
                buf.write_string(" ")
                buf.write_string(pair.0)
                buf.write_string("=\"")
                buf.write_string(pair.1)
                buf.write_string("\"")
              }
            Err(_) => ()
          }
          buf.write_string(">")
          // Add children
          match self.tree.get_children(node) {
            Ok(children) =>
              for child in children {
                self.build_outer_html(child, buf)
              }
            Err(_) => ()
          }
          // Close tag
          buf.write_string("</")
          buf.write_string(info.node_name)
          buf.write_string(">")
        }
        _ => ()
      }
    Err(_) => ()
  }
}

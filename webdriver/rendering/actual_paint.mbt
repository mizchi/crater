///|
pub fn actual_paint_layout_content_right(layout : @types.Layout) -> Double {
  let mut right = layout.x + layout.width
  match layout.overflow_x {
    @types.Visible => {
      let scroll_right = layout.x + layout.scroll_width
      if scroll_right > right {
        right = scroll_right
      }
      for child in layout.children {
        let child_right = actual_paint_layout_content_right(child)
        if child_right > right {
          right = child_right
        }
      }
    }
    _ => ()
  }
  right
}

///|
pub fn actual_paint_layout_content_bottom(layout : @types.Layout) -> Double {
  let mut bottom = layout.y + layout.height
  match layout.overflow_y {
    @types.Visible => {
      let scroll_bottom = layout.y + layout.scroll_height
      if scroll_bottom > bottom {
        bottom = scroll_bottom
      }
      for child in layout.children {
        let child_bottom = actual_paint_layout_content_bottom(child)
        if child_bottom > bottom {
          bottom = child_bottom
        }
      }
    }
    _ => ()
  }
  bottom
}

///|
pub fn actual_paint_document_dimensions_from_node_and_layout(
  node : @node.Node,
  layout : @types.Layout,
  viewport_width : Int,
  viewport_height : Int,
) -> (Int, Int) {
  let width = actual_paint_node_layout_content_right(node, layout)
    .ceil()
    .to_int()
  let height = actual_paint_node_layout_content_bottom(node, layout)
    .ceil()
    .to_int()
  (width.max(viewport_width).max(1), height.max(viewport_height).max(1))
}

///|
pub fn should_use_font_aware_text_provider(font_family : String) -> Bool {
  let normalized = font_family.trim().to_lower()
  normalized.length() > 0 &&
  normalized != "inherit" &&
  normalized != "initial" &&
  normalized != "unset" &&
  normalized != "revert" &&
  normalized != "revert-layer"
}

///|
fn actual_paint_node_contributes_document_overflow(node : @node.Node) -> Bool {
  node.style.position != @types.Fixed
}

///|
fn actual_paint_node_subtree_has_fixed_positioned(node : @node.Node) -> Bool {
  if node.style.position == @types.Fixed {
    return true
  }
  for child in node.children {
    if actual_paint_node_subtree_has_fixed_positioned(child) {
      return true
    }
  }
  false
}

///|
fn actual_paint_node_layout_child(
  node : @node.Node,
  index : Int,
) -> @node.Node? {
  if index < node.children.length() {
    Some(node.children[index])
  } else {
    None
  }
}

///|
fn actual_paint_node_layout_content_right(
  node : @node.Node,
  layout : @types.Layout,
) -> Double {
  if !actual_paint_node_contributes_document_overflow(node) {
    return 0.0
  }
  let mut right = layout.x + layout.width
  match layout.overflow_x {
    @types.Visible => {
      if !actual_paint_node_subtree_has_fixed_positioned(node) {
        let scroll_right = layout.x + layout.scroll_width
        if scroll_right > right {
          right = scroll_right
        }
      }
      for i, child_layout in layout.children {
        let child_right = match actual_paint_node_layout_child(node, i) {
          Some(child_node) =>
            actual_paint_node_layout_content_right(child_node, child_layout)
          None => actual_paint_layout_content_right(child_layout)
        }
        if child_right > right {
          right = child_right
        }
      }
    }
    _ => ()
  }
  right
}

///|
fn actual_paint_node_layout_content_bottom(
  node : @node.Node,
  layout : @types.Layout,
) -> Double {
  if !actual_paint_node_contributes_document_overflow(node) {
    return 0.0
  }
  let collapsed_top_margin = if layout.y == 0.0 && layout.margin.top > 0.0 {
    layout.margin.top
  } else {
    0.0
  }
  let mut bottom = layout.y +
    collapsed_top_margin +
    layout.height +
    layout.margin.bottom
  match layout.overflow_y {
    @types.Visible => {
      if !actual_paint_node_subtree_has_fixed_positioned(node) {
        let scroll_bottom = layout.y + layout.scroll_height
        if scroll_bottom > bottom {
          bottom = scroll_bottom
        }
      }
      for i, child_layout in layout.children {
        let child_bottom = match actual_paint_node_layout_child(node, i) {
          Some(child_node) =>
            actual_paint_node_layout_content_bottom(child_node, child_layout)
          None => actual_paint_layout_content_bottom(child_layout)
        }
        if child_bottom > bottom {
          bottom = child_bottom
        }
      }
    }
    _ => ()
  }
  bottom
}

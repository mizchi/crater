///|
/// HTML/CSS Renderer
/// Converts HTML elements with inline styles to layout

///|
/// Render context with viewport dimensions
pub(all) struct RenderContext {
  viewport_width : Double
  viewport_height : Double
  root_font_size : Double
}

///|
pub fn RenderContext::default() -> RenderContext {
  { viewport_width: 800.0, viewport_height: 600.0, root_font_size: 16.0 }
}

///|
/// Convert HTML Element to Node tree for layout computation
pub fn element_to_node(
  elem : @html.Element,
  parent_style : @style.Style?
) -> @node.Node {
  // Compute style from inline style attribute
  let ctx = @computed.ComputeContext::new()
  let style = match elem.style {
    Some(css) => @computed.compute_inline(css, ctx)
    None => @style.Style::default()
  }

  // Convert children
  let children : Array[@node.Node] = []
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let child_node = element_to_node(child_elem, Some(style))
        children.push(child_node)
      }
      @html.Node::Text(_text) => {
        // For now, we ignore text nodes in layout
        // In a real implementation, we'd create inline boxes
        ()
      }
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

///|
/// Render HTML string to Layout
pub fn render(
  html : String,
  ctx : RenderContext
) -> @node.Layout {
  // Parse HTML
  let elem = @html.parse_fragment(html)

  // Convert to node tree
  let root = element_to_node(elem, None)

  // Create layout context
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.SizingMode::Definite,
  }

  // Compute layout based on display type
  match root.style.display {
    @style.Display::Flex => @flex.compute(root, layout_ctx)
    _ => @block.compute(root, layout_ctx)
  }
}

///|
/// Render HTML to Sixel string
pub fn render_to_sixel(
  html : String,
  width : Int,
  height : Int
) -> String {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = render(html, ctx)
  @sixel.render_layout(layout, width, height)
}

///|
/// Print layout tree for debugging
pub fn print_layout_tree(layout : @node.Layout, indent : Int) -> Unit {
  let prefix = "  ".repeat(indent)
  println(
    prefix +
    layout.id +
    " (" +
    layout.x.to_string() +
    ", " +
    layout.y.to_string() +
    ") " +
    layout.width.to_string() +
    "x" +
    layout.height.to_string(),
  )
  for child in layout.children {
    print_layout_tree(child, indent + 1)
  }
}

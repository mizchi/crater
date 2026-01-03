test "renderer_grid_column" {
  let html_str = "<!DOCTYPE html><div id=\"mygrid\" style=\"display: grid; grid-template-columns: 1fr 30px; width: min-content; border: 10px solid;\"><div id=\"item\" style=\"grid-column: 1 / span 2;\"><div id=\"filler\" style=\"width: 300px; height: 50px;\"></div></div></div>"
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  // root is body, root.children[0] is mygrid
  inspect(root.id, content="body")
  let mygrid = root.children[0]
  inspect(mygrid.id, content="div#mygrid")

  // The item is mygrid.children[0]
  let item = mygrid.children[0]
  inspect(item.id, content="div#item")
  inspect(item.style.grid_column.start, content="Line(1)")
  inspect(item.style.grid_column.end, content="Span(2)")

  // Now compute layout
  @dispatch.setup()
  let layout_ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.Definite,
  }
  let layout = @dispatch.compute(root, layout_ctx)

  // body -> mygrid -> item
  let mygrid_layout = layout.children[0]
  inspect(mygrid_layout.children[0].width, content="30")
}

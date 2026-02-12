///|
test "intrinsic_percent_replaced_wpt_style" {
  // Mimics the WPT test intrinsic-percent-replaced-001.html
  // Canvas with height: 100% inside float with height: 100px
  // Should use aspect_ratio to derive width from height
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#float { float: left; height: 100px; }
    #|canvas { height: 100%; }
    #|</style>
    #|<div id=float><canvas width=10 height=10></canvas></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  // Verify node structure
  inspect(root.id, content="body")
  let float_div = root.children[0]
  inspect(float_div.id, content="div#float")
  let canvas = float_div.children[0]
  inspect(canvas.id, content="canvas")

  // Verify canvas style: height is %, width is Auto, aspect_ratio from intrinsic
  inspect(canvas.style.height, content="Percent(1)")
  inspect(canvas.style.width, content="Auto")
  inspect(canvas.style.aspect_ratio, content="Some(1)")

  // Compute layout
  @dispatch.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: None,
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)
  let float_layout = layout.children[0]
  let canvas_layout = float_layout.children[0]

  // Canvas should have width=100 (from aspect-ratio 1:1 with height=100)
  inspect(canvas_layout.width, content="100")
  inspect(canvas_layout.height, content="100")
  inspect(float_layout.width, content="100")
}

///|
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
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)

  // body -> mygrid -> item
  let mygrid_layout = layout.children[0]
  inspect(mygrid_layout.children[0].width, content="30")
}

///|
test "flex_margin_no_collapse_wpt" {
  // Mimics the exact WPT test flex-margin-no-collapse.html
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#container {
    #|  display: flex;
    #|  flex-direction: column;
    #|  position: absolute;
    #|  top: 100px;
    #|  left: 10px;
    #|  width: 200px;
    #|  height: 300px;
    #|}
    #|.box {
    #|  width: 100px;
    #|  height: 100px;
    #|  flex: none;
    #|}
    #|#box1 { margin: 50px 0; }
    #|#box2 { margin: 50px 0; }
    #|</style>
    #|<div id="container">
    #|  <div id="box1" class="box"></div>
    #|  <div id="box2" class="box"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  // Verify node structure
  inspect(root.id, content="body")
  let container = root.children[0]
  inspect(container.id, content="div#container")
  let box1 = container.children[0]
  let box2 = container.children[1]
  inspect(box1.id, content="div#box1")
  inspect(box2.id, content="div#box2")

  // Check if flex: none parsed correctly
  inspect(box1.style.flex_shrink, content="0")
  inspect(box1.style.flex_grow, content="0")
  inspect(box2.style.flex_shrink, content="0")
  inspect(box2.style.flex_grow, content="0")

  // Check margins parsed correctly
  inspect(box1.style.margin.top, content="Length(50)")
  inspect(box1.style.margin.bottom, content="Length(50)")
  inspect(box2.style.margin.top, content="Length(50)")
  inspect(box2.style.margin.bottom, content="Length(50)")

  // Check position: absolute on container
  inspect(container.style.position, content="Absolute")

  // Compute layout using render function (same as WASM API)
  let layout = @renderer.render(html_str, ctx)

  // Debug: check container dimensions
  let container_layout = layout.children[0]
  inspect(container_layout.id, content="div#container")
  inspect(container_layout.x, content="10")
  inspect(container_layout.y, content="100")
  let box1_layout = container_layout.children[0]
  let box2_layout = container_layout.children[1]

  // Expected layout:
  // box1.y = 50 (margin-top)
  // box2.y = 50 + 100 + 50 + 50 = 250 (margin-top + height + margin-bottom + margin-top)
  inspect(box1_layout.y, content="50")
  inspect(box1_layout.height, content="100")
  inspect(box2_layout.y, content="250")
  inspect(box2_layout.height, content="100")
}

///|
test "wpt_grid_container_as_flex_item_reflows_to_final_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.inner-grid {
    #|  display: grid;
    #|  flex: 1 1 0%;
    #|  width: 100%;
    #|}
    #|.inner-grid-item {
    #|  font: 50px/1 Ahem;
    #|  min-width: 0;
    #|  width: 100%;
    #|}
    #|</style>
    #|<div style="display: grid">
    #|  <div style="display: flex; flex-direction: column; width: 100px">
    #|    <div class="inner-grid">
    #|      <div class="inner-grid-item">XX XX</div>
    #|    </div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let root_grid = layout.children[0]
  let outer_flex = root_grid.children[0]
  let inner_grid = outer_flex.children[0]
  let inner_item = inner_grid.children[0]

  inspect(root_grid.height, content="100")
  inspect(outer_flex.height, content="100")
  inspect(inner_grid.height, content="100")
  inspect(inner_item.height, content="100")
}

///|
test "wpt_grid_child_percent_basis_resize_uses_definite_track_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body {
    #|  margin: 0;
    #|  font-family: monospace;
    #|  font-size: 16px;
    #|  line-height: 1.2;
    #|}
    #|.grid-container {
    #|  display: grid;
    #|  width: 100px;
    #|}
    #|.scroll-outer {
    #|  overflow: hidden;
    #|  height: 100%;
    #|  max-height: 100px;
    #|}
    #|.scroll-inner {
    #|  overflow: scroll;
    #|  height: 100%;
    #|}
    #|</style>
    #|<div class="grid-container">
    #|  <div class="grid-item">
    #|    <div class="scroll-outer">
    #|      <div class="scroll-inner">
    #|        <div>0</div><div>1</div><div>2</div><div>3</div><div>4</div>
    #|        <div>5</div><div>6</div><div>7</div><div>8</div><div>9</div>
    #|        <div>0</div><div>1</div><div>2</div><div>3</div><div>4</div>
    #|        <div>5</div><div>6</div><div>7</div><div>8</div><div>9</div>
    #|      </div>
    #|    </div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let node_tree = @renderer.render_to_node(html_str, ctx)
  let node_grid = node_tree.children[0]
  let node_grid_item = node_grid.children[0]
  let node_scroll_outer = node_grid_item.children[0]
  let node_scroll_inner = node_scroll_outer.children[0]
  inspect(node_scroll_outer.style.max_height, content="Length(100)")
  inspect(node_scroll_inner.style.height, content="Percent(1)")
  inspect(node_scroll_inner.children[0].style.height, content="Auto")

  let layout = @renderer.render(html_str, ctx)
  let grid = layout.children[0]
  let grid_item = grid.children[0]
  let scroll_outer = grid_item.children[0]
  let scroll_inner = scroll_outer.children[0]
  let first_line = scroll_inner.children[0]
  let second_line = scroll_inner.children[1]

  inspect(first_line.height, content="19.2")
  inspect(second_line.y, content="19.2")
  inspect(grid.height, content="100")
  inspect(grid_item.height, content="100")
  inspect(scroll_outer.height, content="100")
  inspect(scroll_inner.height, content="100")
}

///|
test "wpt_grid_item_percentage_quirk_canvas_behaves_like_browser" {
  let html_str =
    #|<!-- quirks mode -->
    #|<div style="width: 100px; height: 100px; overflow: hidden; background: green;">
    #|  <div style="display: grid; position: relative; left: -20px;">
    #|    <canvas width=10 height=10 style="height: 200%; background: red;"></canvas>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let outer = layout.children[0]
  let grid = outer.children[0]
  let canvas = grid.children[0]

  inspect(grid.height, content="10")
  inspect(canvas.width, content="20")
  inspect(canvas.height, content="20")
}

///|
test "wpt_grid_item_percentage_quirk_non_replaced_stays_auto" {
  let html_str =
    #|<!-- quirks mode -->
    #|<div style="width: 100px; height: 100px; overflow: hidden; background: green;">
    #|  <div style="display: grid; position: relative; left: -20px;">
    #|    <div width=10 height=10 style="height: 200%; width: 200px; background: red;"></div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let outer = layout.children[0]
  let grid = outer.children[0]
  let child = grid.children[0]

  inspect(grid.height, content="0")
  inspect(child.width, content="200")
  inspect(child.height, content="0")
}

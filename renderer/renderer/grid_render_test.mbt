///|
// Grid renderer regression tests split from render_test.mbt.

///|
test "grid_named_layout_lines_place_item_to_extended_full_end" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|:root {
    #|  --layout-side-padding-min: 1rem;
    #|  --layout-side-padding: max(var(--layout-side-padding-min), calc(50vw - 720px + 1rem));
    #|  --layout-content-max: 48rem;
    #|  --layout-no-sidebar-extended:
    #|    [extended-full-start] var(--layout-side-padding)
    #|    [full-start] 1fr
    #|    [content-start] minmax(0, var(--layout-content-max))
    #|    [content-end] 1fr
    #|    [full-end] var(--layout-side-padding)
    #|    [extended-full-end];
    #|}
    #|.homepage {
    #|  display: grid;
    #|  grid-template-columns: var(--layout-no-sidebar-extended);
    #|  width: 800px;
    #|}
    #|.homepage > * { grid-column: content; }
    #|.homepage-header {
    #|  display: grid;
    #|  grid-column-end: extended-full-end;
    #|}
    #|</style>
    #|<div class="homepage"><div class="homepage-header"></div></div>
  let (node, layout) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let header_node = node.children[0].children[0]
  inspect(header_node.style.grid_column.start, content="Line(2)")
  inspect(header_node.style.grid_column.end, content="Line(-1)")
  let homepage = layout.children[0]
  let header = homepage.children[0]
  inspect(header.x, content="16")
  inspect(header.width, content="784")
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
  @node.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)

  // body -> mygrid -> item
  let mygrid_layout = layout.children[0]
  inspect(mygrid_layout.children[0].width, content="30")
}

///|
test "orthogonal_child_within_flex_grid_wpt_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="display: flex; width: 100px; overflow: hidden;">
    #|  <div style="display: grid; height: 100px;">
    #|    <div style="writing-mode: vertical-rl; line-height: 0;">
    #|      <span style="display: inline-block; width: 50px; height: 100px;"></span>
    #|      <span style="display: inline-block; width: 50px; height: 100px;"></span>
    #|    </div>
    #|  </div>
    #|  <div>text</div>
    #|</div>

  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let flex = root.children[0]
  let grid = flex.children[0]
  let ortho = grid.children[0]
  inspect(ortho.style.writing_mode, content="VerticalRl")

  @node.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)
  let flex_layout = layout.children[0]
  let grid_layout = flex_layout.children[0]
  let ortho_layout = grid_layout.children[0]
  inspect(grid_layout.width, content="100")
  inspect(ortho_layout.width, content="100")
  inspect(ortho_layout.children[0].x, content="50")
  inspect(ortho_layout.children[1].x, content="0")
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

///|
test "wpt_grid_align_start_item_uses_content_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.grid {
    #|  display: grid;
    #|  grid-template-columns: 100%;
    #|  grid-template-rows: 50px;
    #|  height: 50px;
    #|  font: 10px/1 Ahem;
    #|}
    #|.alignStart {
    #|  align-items: start;
    #|}
    #|</style>
    #|<div class="grid alignStart">
    #|  <div class="test">x x x x</div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let grid = layout.children[0]
  let item = grid.children[0]

  inspect(grid.height, content="50")
  inspect(
    item.height,
    content=(
      #|10
    ),
  )
}

///|
test "wpt_grid_flex_item_vertical_lr_auto_row_keeps_zero_block_size" {
  let html_str =
    #|<!doctype html><div id="flex" style="display:flex;flex-direction:column;width:100px;height:100px;"><div id="grid" style="display:grid;grid-template-rows:auto;writing-mode:vertical-lr;"><div id="leaf"></div></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let flex = layout.children[0]
  let grid = flex.children[0]
  let leaf = grid.children[0]

  inspect(grid.width, content="100")
  inspect(grid.height, content="0")
  inspect(leaf.width, content="100")
  inspect(leaf.height, content="0")
}

///|
test "wpt_grid_flex_item_column_percent_basis_indefinite_height_uses_content" {
  let html_str =
    #|<!doctype html><div id="target"><div id="flex" style="display:flex;flex-direction:column"><div id="grid" style="display:grid;height:0;flex:1;grid-template-rows:minmax(100px,200%);"><div id="leaf"></div></div></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let target = layout.children[0]
  let flex = target.children[0]
  let grid = flex.children[0]
  let leaf = grid.children[0]

  inspect(target.height, content="100")
  inspect(flex.height, content="100")
  inspect(grid.height, content="100")
  inspect(leaf.height, content="100")
}

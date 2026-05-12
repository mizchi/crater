///|
// Table positioning regression tests split from table_render_test.mbt.

///|
test "relative tfoot offset does not inflate parent auto height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-collapse: collapse; }
    #|td { padding: 0; }
    #|td > div { width: 50px; height: 50px; }
    #|.group { display: inline-block; position: relative; width: 150px; height: 200px; }
    #|.indicator { position: absolute; left: 0; top: 150px; width: 50px; height: 50px; background: red; }
    #|.relative { position: relative; top: 100px; background: green; }
    #|</style>
    #|<div class="group">
    #|  <div>
    #|    <div class="indicator"></div>
    #|    <table>
    #|      <tbody><tr><td><div></div></td></tr></tbody>
    #|      <tfoot class="relative"><tr><td><div></div></td></tr></tfoot>
    #|    </table>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let group = layout.children[0]
  let inner = group.children[0]
  let table = inner.children[1]
  inspect(inner.id, content="div")
  inspect(table.id, content="table")
  inspect(inner.height, content="100")
  inspect(table.height, content="100")
}

///|
test "relative tfoot abs child does not inflate parent auto height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-collapse: collapse; }
    #|td { padding: 0; }
    #|td > div { width: 50px; height: 50px; }
    #|.group { display: inline-block; position: relative; width: 150px; height: 200px; }
    #|.indicator { position: absolute; left: 0; top: 150px; width: 50px; height: 50px; background: red; }
    #|.relative { position: relative; top: 50px; background: white; }
    #|.absolute { position: absolute; top: 50px; background: green; }
    #|</style>
    #|<div class="group">
    #|  <div>
    #|    <div class="indicator"></div>
    #|    <table>
    #|      <tbody><tr><td><div></div></td></tr></tbody>
    #|      <tfoot class="relative">
    #|        <tr><td style="width:50px;height:50px"><div class="absolute"></div></td></tr>
    #|      </tfoot>
    #|    </table>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let group = layout.children[0]
  let inner = group.children[0]
  let table = inner.children[1]
  inspect(inner.id, content="div")
  inspect(table.id, content="table")
  inspect(inner.height, content="100")
  inspect(table.height, content="100")
}

///|
test "abspos_canvas_display_table_respects_explicit_css_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#wrap { position: relative; }
    #|canvas {
    #|  position: absolute;
    #|  display: table;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div id="wrap"><canvas width="200"></canvas></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let node_wrap = node.children[0]
  let node_canvas = node_wrap.children[0]
  inspect(node_canvas.style.width, content="Length(100)")
  inspect(node_canvas.style.height, content="Length(100)")
  let wrap = layout.children[0]
  let canvas = wrap.children[0]
  inspect(canvas.id, content="canvas")
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
}

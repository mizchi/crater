///|
// Table cell layout regression tests split from table_render_test.mbt.

///|
test "wpt_table_cell_overflow_auto_respects_max_width" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="width: 100px; height: 100px; border: solid;">
    #|  <div id="cell" style="display: table-cell; max-width: 100px; height: 100px; background: green; overflow-x: auto; vertical-align: top;">
    #|    <div style="width: 120px; height: 50px; background: hotpink;"></div>
    #|  </div>
    #|</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let wrapper = node.children[0]
  let cell = wrapper.children[0]
  inspect(cell.style.display, content="TableCell")
  inspect(cell.style.max_width, content="Length(100)")
  inspect(cell.style.height, content="Length(100)")

  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let container = layout.children[0]
  let laid_out_cell = container.children[0]
  inspect(laid_out_cell.width, content="100")
}

///|
test "wpt_table_cell_child_overflow_measure_keeps_explicit_height" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="cell" style="width: 100px; height: 100px; display: table-cell; background: green;">
    #|  <div id="scroller" style="overflow: auto; height: 100%;">
    #|    <div style="height: 200px;"></div>
    #|  </div>
    #|</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let cell = node.children[0]
  inspect(cell.style.display, content="TableCell")
  inspect(cell.style.height, content="Length(100)")

  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let laid_out_cell = layout.children[0]
  let scroller = laid_out_cell.children[0]
  inspect(laid_out_cell.height, content="100")
  inspect(scroller.height, content="100")
}

///|
test "table_cell_defaults_to_normal_line_height_metrics" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|table {
    #|  border-spacing: 0;
    #|  font-family: monospace;
    #|  font-size: 100px;
    #|  table-layout: fixed;
    #|  width: 4ch;
    #|}
    #|td { padding: 0; }
    #|col#middle-column { width: 4ch; }
    #|span { background-color: red; color: yellow; }
    #|</style>
    #|<table>
    #|  <col><col id="middle-column"><col>
    #|  <tr><td><td><td>
    #|  <tr><td><td id="test">PASS<span>FAIL</span><td>
    #|  <tr><td><td><td>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[1]
  let target_row = tbody.children[1]
  let target_cell = target_row.children[1]
  let span = target_cell.children[1]
  inspect(target_cell.id, content="td#test")
  guard target_cell.height <= 125.0 else {
    fail("table cell height should stay close to normal line-height metrics")
  }
  inspect(span.height, content="120")
  inspect(span.y, content="0")
}

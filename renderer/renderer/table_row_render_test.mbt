///|
// Table row visual regression tests split from table_render_test.mbt.

///|
test "wpt_visibility_collapse_border_spacing_002_layout" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|table#t {
    #|  border-spacing: 50px 100px;
    #|}
    #|td {
    #|  width: 100px;
    #|  padding: 0;
    #|}
    #|tr + tr {
    #|  visibility: collapse;
    #|}
    #|</style>
    #|<table id="t">
    #|  <tr><td rowspan="2"></td></tr>
    #|  <tr></tr>
    #|</table>
  let ctx = @renderer.RenderContext::default()
  let node_root = @renderer.render_to_node(html_str, ctx)
  let mut table_node : @node.Node? = None
  for child in node_root.children {
    if child.id == "table#t" {
      table_node = Some(child)
      break
    }
  }
  let table = match table_node {
    Some(node) => node
    None => {
      inspect(false, content="table_node_not_found")
      return
    }
  }
  let tbody = table.children[0]
  let collapsed_row = tbody.children[1]
  inspect(table.style.border_spacing, content="50")
  inspect(table.style.border_spacing_vertical, content="100")
  inspect(tbody.style.display, content="TableRowGroup")
  inspect(collapsed_row.style.visibility, content="Collapse")

  let layout_root = @renderer.render(html_str, ctx)
  let mut table_layout : @types.Layout? = None
  for child in layout_root.children {
    if child.id == "table#t" {
      table_layout = Some(child)
      break
    }
  }
  let table_box = match table_layout {
    Some(layout) => layout
    None => {
      inspect(false, content="table_layout_not_found")
      return
    }
  }
  inspect(table_box.height, content="200")
  inspect(table_box.children[0].height, content="0")
  inspect(table_box.children[0].children[1].y, content="0")
}

///|
test "overflow alignment table keeps sixth cell width in node and layout" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0 }
    #|th, td { padding: 0; }
    #|thead { display: table-footer-group; }
    #|.indicator { width: 72px; height: 72px; }
    #|.indicator > div { width: 24px; height: 24px; }
    #|.indicator > .tl, .indicator > .tc, .indicator > .cl, .indicator > .cc, .indicator > .bl, .indicator > .bc { float: left; }
    #|.indicator > .tr, .indicator > .cr, .indicator > .br { float: right; }
    #|.indicator > .cl, .indicator > .bl { clear: both; }
    #|.test { width: 24px; height: 24px; overflow: hidden; place-content: safe center; }
    #|</style>
    #|<table>
    #|  <thead><tr><th colspan="6">x</th></tr></thead>
    #|  <tbody>
    #|    <tr>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|    </tr>
    #|  </tbody>
    #|</table>
  let ctx = @renderer.RenderContext::default()
  let node_root = @renderer.render_to_node(html_str, ctx)
  let layout_root = @renderer.render(html_str, ctx)
  let table_node = node_root.children[0]
  let tbody_node = table_node.children[1]
  let target_cell_node = tbody_node.children[0].children[5]
  let target_test = tbody_node.children[0].children[5].children[0]
  inspect(target_cell_node.id, content="td")
  inspect(target_test.id, content="div.test")
  inspect(target_test.style.display, content="Block")
  inspect(target_test.style.width, content="Length(24)")
  inspect(target_test.style.height, content="Length(24)")

  let table_layout = layout_root.children[0]
  let tbody_layout = table_layout.children[1]
  let target_cell = tbody_layout.children[0].children[5]
  let target_test_layout = target_cell.children[0]
  inspect(target_cell.width, content="24")
  inspect(target_cell.height, content="24")
  inspect(target_test_layout.width, content="24")
  inspect(target_test_layout.height, content="24")
}

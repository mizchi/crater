///|
// Table display-model regression tests split from table_render_test.mbt.

///|
test "quirks_table_cell_inline_size_preserves_table_display_model" {
  let html_str =
    #|<!~quirks>
    #|<style>
    #|  td {
    #|    width: 50px;
    #|    padding: 10px;
    #|    border: 1px solid black;
    #|    box-sizing: border-box;
    #|  }
    #|</style>
    #|<table>
    #|  <tr><td>A</td></tr>
    #|</table>
  let ctx = @renderer.RenderContext::default()
  let node_root = @renderer.render_to_node(html_str, ctx)
  let mut table_node : @node.Node? = None
  for child in node_root.children {
    if child.id == "table" {
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
  let tr = tbody.children[0]
  let td = tr.children[0]
  inspect(table.style.display, content="Table")
  inspect(table.style.width, content="Auto")
  inspect(tbody.style.display, content="TableRowGroup")
  inspect(tr.style.display, content="TableRow")
  inspect(td.style.display, content="TableCell")

  let layout_root = @renderer.render(html_str, ctx)
  let mut table_layout : @layout_types.Layout? = None
  for child in layout_root.children {
    if child.id == "table" {
      table_layout = Some(child)
      break
    }
  }
  let table_box = match table_layout {
    Some(node) => node
    None => {
      inspect(false, content="table_layout_not_found")
      return
    }
  }
  inspect(table_box.width, content="54")
}

///|
test "mixed_inline_and_table_child_keeps_table_shrink_width" {
  let html_str =
    #|<!doctype html>
    #|<a>Spec</a>
    #|<table><tr><td>A</td></tr></table>
  let ctx = @renderer.RenderContext::default()
  let layout_root = @renderer.render(html_str, ctx)
  let link = layout_root.children[0]
  let table = layout_root.children[1]

  inspect(link.id, content="a")
  inspect(
    link.width,
    content=(
      #|32
    ),
  )
  inspect(table.id, content="table")
  inspect(
    table.width,
    content=(
      #|12
    ),
  )
}

///|
// Table parser regression tests split from table_render_test.mbt.

///|
test "table cells keep nbsp text when td end tags are omitted" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-spacing: 0; }
    #|</style>
    #|<table>
    #|  <tr><td>&nbsp;<td>&nbsp;
    #|  <tr><td>&nbsp;<td>x
    #|</table>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let table = root.children[0]
  let tbody = table.children[0]
  let row0 = tbody.children[0]
  let row1 = tbody.children[1]
  assert_eq(row0.children.length(), 2)
  assert_eq(row1.children.length(), 2)
  guard row0.children[0].children.length() > 0 else {
    fail("first row first cell should keep nbsp text")
  }
  guard row0.children[1].children.length() > 0 else {
    fail("first row second cell should keep nbsp text")
  }
  guard row1.children[0].children.length() > 0 else {
    fail("second row first cell should keep nbsp text")
  }
}

///|
test "table omitted td end tags do not double last cell width with trailing indentation" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-spacing: 0; }
    #|td {
    #|  contain: size;
    #|  font-size: 50px;
    #|}
    #|</style>
    #|<table>
    #|  <tr>
    #|    <td>5<td>6<td>7<td>8
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  guard row.children.length() == 4 else {
    fail("row should keep four cells with omitted td end tags")
  }
  let first_width = row.children[0].width
  let last_width = row.children[3].width
  guard last_width <= first_width + 1.0 else {
    fail(
      "last cell should not include trailing indentation as extra text width",
    )
  }
}

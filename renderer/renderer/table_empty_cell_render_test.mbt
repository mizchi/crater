///|
// Table empty-cell and cellpadding regression tests split from table_render_test.mbt.

///|
test "empty_td_has_zero_content_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td></td><td>text</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let empty_td = row.children[0]
  let text_td = row.children[1]
  inspect(empty_td.id, content="td")
  inspect(text_td.id, content="td")
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    empty_td.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "all_empty_td_row_has_zero_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td></td><td></td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let td1 = row.children[0]
  let td2 = row.children[1]
  inspect(
    row.height,
    content=(
      #|0
    ),
  )
  inspect(
    td1.height,
    content=(
      #|0
    ),
  )
  inspect(
    td2.height,
    content=(
      #|0
    ),
  )
}

///|
test "empty_td_with_colspan_has_zero_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td colspan="2"></td><td>text</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let colspan_td = row.children[0]
  let text_td = row.children[1]
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    colspan_td.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "empty_td_with_line_height_has_zero_content_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0;line-height:40px}table{border-spacing:0}td{padding:0}</style>
    #|<table>
    #|  <tr>
    #|    <td></td>
    #|    <td></td>
    #|  </tr>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  inspect(
    row.height,
    content=(
      #|0
    ),
  )
}

///|
test "whitespace_only_td_has_zero_content_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0;line-height:40px}table{border-spacing:0}td{padding:0}</style>
    #|<table>
    #|  <tr>
    #|    <td>   </td>
    #|    <td>text</td>
    #|  </tr>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let ws_td = row.children[0]
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    ws_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "empty_td_does_not_inflate_row_with_large_line_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0;line-height:40px}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td></td><td>x</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let empty_td = row.children[0]
  let text_td = row.children[1]
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    empty_td.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "empty_td_cellpadding_does_not_inflate_row" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}</style>
    #|<table cellpadding="10" cellspacing="0"><tr><td></td><td>x</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let empty_td = row.children[0]
  let text_td = row.children[1]
  inspect(
    row.height,
    content=(
      #|39.2
    ),
  )
  inspect(
    empty_td.height,
    content=(
      #|39.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|39.2
    ),
  )
}

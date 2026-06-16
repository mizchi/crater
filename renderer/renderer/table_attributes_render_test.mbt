///|
// Table attribute regression tests split from table_render_test.mbt.

///|
test "cellpadding_attribute_sets_cell_padding" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<table cellpadding="10"><tr><td>test</td></tr></table>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  fn find_td(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("td") {
      return Some(n)
    }
    for child in n.children {
      match find_td(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
  match find_td(node) {
    Some(td) => {
      inspect(
        td.style.padding.top,
        content=(
          #|Length(10)
        ),
      )
      inspect(
        td.style.padding.left,
        content=(
          #|Length(10)
        ),
      )
    }
    None => inspect(false, content="td not found")
  }
}

///|
test "nested_table_cell_height_ignores_surrounding_whitespace" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body {
    #|  margin: 0;
    #|  font-family: Verdana, Geneva, sans-serif;
    #|  font-size: 10pt;
    #|  color: #828282;
    #|}
    #|td {
    #|  font-family: Verdana, Geneva, sans-serif;
    #|  font-size: 10pt;
    #|  color: #828282;
    #|}
    #|.pagetop {
    #|  font-family: Verdana, Geneva, sans-serif;
    #|  font-size: 10pt;
    #|  color: #222;
    #|  line-height: 12px;
    #|}
    #|.hnname { margin-left: 1px; margin-right: 5px; }
    #|a:link { color: #000; text-decoration: none; }
    #|</style>
    #|<table id="hnmain" border="0" cellpadding="0" cellspacing="0" width="85%" bgcolor="#f6f6ef">
    #|  <tbody>
    #|    <tr id="outer-row">
    #|      <td id="outer-cell" bgcolor="#ff6600">
    #|        <table id="inner" border="0" cellpadding="0" cellspacing="0" width="100%" style="padding:2px">
    #|          <tbody>
    #|            <tr id="inner-row">
    #|              <td id="logo" style="width:18px;padding-right:4px">
    #|                <a><img src="missing.svg" width="18" height="18" style="border:1px white solid;display:block"></a>
    #|              </td>
    #|              <td id="nav" style="line-height:12pt;height:10px">
    #|                <span class="pagetop"><b class="hnname"><a>Hacker News</a></b><a>new</a> | <a>past</a></span>
    #|              </td>
    #|              <td id="login" style="text-align:right;padding-right:4px">
    #|                <span class="pagetop"><a>login</a></span>
    #|              </td>
    #|            </tr>
    #|          </tbody>
    #|        </table>
    #|      </td>
    #|    </tr>
    #|  </tbody>
    #|</table>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let outer_row = tbody.children[0]
  let outer_cell = outer_row.children[0]
  let inner_table = outer_cell.children[0]
  let inner_tbody = inner_table.children[0]
  let inner_row = inner_tbody.children[0]
  inspect(table.height, content="22")
  inspect(outer_row.height, content="22")
  inspect(outer_cell.height, content="22")
  inspect(inner_table.height, content="22")
  inspect(inner_row.height, content="18")
}

///|
test "table width=85% constrains content within 85% of viewport" {
  let html =
    #|<html><body>
    #|<style>body { margin: 0; }</style>
    #|<center>
    #|<table width="85%" bgcolor="#f6f6ef">
    #|<tr><td>
    #|<table width="100%"><tr>
    #|<td>Hacker News new| past| comments| ask| show| jobs| submit</td>
    #|<td style="text-align:right">login</td>
    #|</tr></table>
    #|</td></tr>
    #|<tr><td>Long article title that should wrap within 85% of 800px viewport width</td></tr>
    #|</table>
    #|</center>
    #|</body></html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
  let center_node = node.children[0]
  inspect(center_node.id, content="center")
  inspect(center_node.style.display, content="Block")
  let table_node = center_node.children[0]
  inspect(table_node.style.display, content="Table")
  inspect(
    table_node.style.width,
    content=(
      #|Percent(0.85)
    ),
  )
  let center_layout = layout.children[0]
  let table_layout = center_layout.children[0]
  inspect(
    table_layout.width,
    content=(
      #|680
    ),
  )
}

///|
/// HTML presentational hint: a bare `<table border>` (empty value) maps to a 1px
/// border, while `border="0"` leaves the table without one.
test "bare_table_border_attribute_maps_to_one_pixel" {
  fn find_table(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("table") {
      return Some(n)
    }
    for child in n.children {
      match find_table(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }

  fn table_border_top(html : String) -> @types.Dimension {
    let ctx = @renderer.RenderContext::default()
    let node = @renderer.render_to_node(html, ctx)
    match find_table(node) {
      Some(table) => table.style.border.top
      None => @types.Auto
    }
  }

  // Bare attribute → 1px on every side.
  inspect(
    table_border_top(
      (
        #|<table border><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(1)
    ),
  )
  // Explicit zero → no border.
  inspect(
    table_border_top(
      (
        #|<table border="0"><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(0)
    ),
  )
  // Explicit numeric value is used verbatim.
  inspect(
    table_border_top(
      (
        #|<table border="3"><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(3)
    ),
  )
}

///|
/// A `<table border>` also gives every cell an implied 1px border, regardless
/// of the table border width. `border="0"` leaves the cells borderless.
test "table_border_attribute_adds_one_pixel_cell_border" {
  fn cell_border_top(html : String) -> @types.Dimension {
    let ctx = @renderer.RenderContext::default()
    let node = @renderer.render_to_node(html, ctx)
    match find_node_by_tag_id(node, "td") {
      Some(cell) => cell.style.border.top
      None => @types.Auto
    }
  }

  // Bare attribute → 1px on every cell, independent of the table border value.
  inspect(
    cell_border_top(
      (
        #|<table border><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(1)
    ),
  )
  // A thick table border still implies only a 1px cell border.
  inspect(
    cell_border_top(
      (
        #|<table border="5"><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(1)
    ),
  )
  // Explicit zero → no cell border.
  inspect(
    cell_border_top(
      (
        #|<table border="0"><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(0)
    ),
  )
  // No border attribute → no implied cell border.
  inspect(
    cell_border_top(
      (
        #|<table><tr><td>x</td></tr></table>
      ),
    ),
    content=(
      #|Length(0)
    ),
  )
}

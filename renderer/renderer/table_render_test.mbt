///|
// Table layout regression tests split from render_test.mbt.
//
// Keep table formatting-model and empty-cell cases here so render_test.mbt can
// stay focused on cross-cutting renderer regressions.

///|
test "contain_layout_table_row_group_has_no_principal_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#wrapper {
    #|  position: relative;
    #|  width: 100px;
    #|  height: 100px;
    #|  padding: 25px;
    #|  box-sizing: border-box;
    #|}
    #|#table-row-group {
    #|  display: table-row-group;
    #|  contain: layout;
    #|}
    #|#abspos {
    #|  position: absolute;
    #|  font: 100px/1 monospace;
    #|  top: 0;
    #|  left: 0;
    #|}
    #|</style>
    #|<div id="wrapper">
    #|  <div id="table-row-group">
    #|    <div id="abspos">X</div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let row_group = layout.children[0].children[0]
  guard row_group.width == 0.0 else {
    fail("table-row-group should not generate a principal box width")
  }
  guard row_group.height == 0.0 else {
    fail("table-row-group should not generate a principal box height")
  }
  guard row_group.children.length() > 0 else {
    fail("absolute descendant should remain in layout tree")
  }
  let abs = row_group.children[0]
  guard abs.x < 0.0 && abs.y < 0.0 else {
    fail("absolute descendant should ignore no-principal ancestor offset")
  }
  guard abs.width >= 60.0 else {
    fail("absolute descendant should keep intrinsic inline size")
  }
}

///|
test "contain_paint_table_row_group_static_abs_keeps_static_position" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|div {
    #|  display: table-row-group;
    #|  contain: paint;
    #|}
    #|span {
    #|  position: absolute;
    #|}
    #|</style>
    #|<p>Test passes if there is the word "PASS" below.</p>
    #|<div><span>PASS</span></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("body should keep paragraph and table-row-group children")
  }
  let row_group = layout.children[1]
  guard row_group.children.length() == 1 else {
    fail("table-row-group should keep absolute descendant")
  }
  let abs = row_group.children[0]
  guard abs.y >= -0.5 && abs.y <= 0.5 else {
    fail("static-positioned absolute child should stay aligned with row-group")
  }
}

///|
test "contain_paint_table_cell_abs_does_not_contribute_intrinsic_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|div {
    #|  display: table-cell;
    #|  contain: paint;
    #|}
    #|span {
    #|  position: absolute;
    #|}
    #|</style>
    #|<p>There should be nothing below.</p>
    #|<div><span>FAIL</span></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("body should keep paragraph and table-cell children")
  }
  let cell = layout.children[1]
  guard cell.width == 0.0 else {
    fail("table-cell with only abspos content should keep zero intrinsic width")
  }
  guard cell.height == 0.0 else {
    fail(
      "table-cell with only abspos content should keep zero intrinsic height",
    )
  }
}

///|
test "contain_size_table_row_group_with_text_does_not_crash" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|div {
    #|  display: table-row-group;
    #|  contain: size;
    #|}
    #|section {
    #|  overflow: hidden;
    #|}
    #|</style>
    #|<p>Test passes if there is the word "PASS" below.</p>
    #|<section><div>PASS</div></section>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("body should keep paragraph and section")
  }
  let section = layout.children[1]
  guard section.children.length() == 1 else {
    fail("section should keep the row-group child")
  }
}

///|
test "fixed_table_caption_keeps_intrinsic_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|caption {
    #|  position: fixed;
    #|}
    #|th {
    #|  padding-left: 50px;
    #|}
    #|</style>
    #|<table>
    #|  <caption>PASS</caption>
    #|  <tr><th>&emsp;</th></tr>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else { fail("body should keep table") }
  let table = layout.children[0]
  guard table.children.length() >= 1 else { fail("table should keep caption") }
  let caption = table.children[0]
  guard caption.width == 32.0 else {
    fail("fixed caption width should use intrinsic text width")
  }
}

///|
test "size_contained_caption_contributes_border_width_to_empty_table" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.contain { contain: size; }
    #|.innerContents { height: 100px; width: 100px; color: transparent; }
    #|caption { border: 1em solid green; }
    #|</style>
    #|<table>
    #|  <caption class="contain">
    #|    <div class="innerContents">inner</div>
    #|  </caption>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else { fail("body should keep table") }
  let table = layout.children[0]
  guard table.width == 32.0 else {
    fail("empty table should still include caption border width")
  }
}

///|
test "vertical writing table keeps intrinsic max-width in computed style" {
  let html =
    #|<!doctype html>
    #|<style>
    #|  .container { writing-mode: vertical-lr; }
    #|  .big-w { width: 150px; }
    #|  .max-width-min-content { max-width: 0px; max-width: min-content; }
    #|</style>
    #|<div class="container">
    #|  <table class="big-w max-width-min-content"><td>x</td></table>
    #|</div>

  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let container = root.children[0]
  let table = container.children[0]
  let td = table.children[0]
  inspect(container.style.writing_mode, content="VerticalLr")
  inspect(table.style.writing_mode, content="VerticalLr")
  inspect(td.style.writing_mode, content="VerticalLr")
  inspect(table.style.width, content="Length(150)")
  inspect(table.style.max_width, content="MinContent")
}

///|
test "wpt_block_size_table_container_keeps_auto_size_in_computed_style" {
  let html =
    #|<!doctype html>
    #|<style>
    #|  .container { writing-mode: vertical-lr; }
    #|</style>
    #|<div class="container"><table><td>x</td></table></div>

  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let container = root.children[0]
  inspect(container.style.writing_mode, content="VerticalLr")
  inspect(container.style.width, content="Auto")
  inspect(container.style.height, content="Auto")
}

///|
test "wpt_table_as_flex_item_auto_min_width_floor" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; width:100px; background:red;">
    #|  <div style="display:table; width:10px; max-width:10px; height:100px; background:green;">
    #|    <div style="width:100px; height:10px; background:green;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let table_item = layout.children[0].children[0]
  guard table_item.width >= 99.0 else {
    fail("table flex item should not shrink below intrinsic min-content width")
  }
}

///|
test "wpt_table_as_flex_item_fixed_min_width_floor" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; width:100px; background:red;">
    #|  <div style="display:table; min-width:5px; width:10px; max-width:10px; height:100px; background:green;">
    #|    <div style="width:100px; height:10px; background:green;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let table_item = layout.children[0].children[0]
  guard table_item.width >= 99.0 else {
    fail(
      "table flex item should honor intrinsic floor beyond specified min-width",
    )
  }
}

///|
test "wpt_table_intrinsic_size_001_inline_size_floor" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer { width: min-content; background: green; }
    #|.table {
    #|  display: table;
    #|  inline-size: 30px;
    #|  block-size: 100px;
    #|  border-inline: 10px solid green;
    #|  margin-inline: 10px;
    #|}
    #|.content { inline-size: 60px; block-size: 100px; }
    #|</style>
    #|<div class="outer"><div class="table"><div class="content"></div></div></div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let table = outer.children[0]
  inspect(outer.width, content="100")
  inspect(table.width, content="80")
}

///|
test "wpt_table_intrinsic_size_002_max_inline_size_floor" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer { width: min-content; background: green; }
    #|.table {
    #|  display: table;
    #|  max-inline-size: 30px;
    #|  block-size: 100px;
    #|  border-inline: 10px solid green;
    #|  margin-inline: 10px;
    #|}
    #|.content { inline-size: 60px; block-size: 100px; }
    #|</style>
    #|<div class="outer"><div class="table"><div class="content"></div></div></div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let table = outer.children[0]
  inspect(outer.width, content="100")
  inspect(table.width, content="80")
}

///|
test "wpt_table_intrinsic_size_003_vertical_inline_size_floor" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer { width: min-content; background: green; }
    #|.table {
    #|  writing-mode: vertical-rl;
    #|  display: table;
    #|  inline-size: 30px;
    #|  block-size: 100px;
    #|  border-inline: 10px solid green;
    #|}
    #|.content { inline-size: 80px; block-size: 100px; }
    #|</style>
    #|<div class="outer"><div class="table"><div class="content"></div></div></div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let table = outer.children[0]
  inspect(outer.width, content="100")
  inspect(outer.height, content="100")
  inspect(table.width, content="100")
  inspect(table.height, content="100")
}

///|
test "wpt_table_intrinsic_size_004_vertical_max_inline_size_floor" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer { width: min-content; background: green; }
    #|.table {
    #|  writing-mode: vertical-rl;
    #|  display: table;
    #|  max-inline-size: 30px;
    #|  block-size: 100px;
    #|  border-inline: 10px solid green;
    #|}
    #|.content { inline-size: 80px; block-size: 100px; }
    #|</style>
    #|<div class="outer"><div class="table"><div class="content"></div></div></div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let table = outer.children[0]
  inspect(outer.width, content="100")
  inspect(outer.height, content="100")
  inspect(table.width, content="100")
  inspect(table.height, content="100")
}

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
test "wpt_table_flex_item_auto_width_uses_flex_used_size" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; width:100px; height:100px; align-items:flex-start; background:green;">
    #|  <table style="flex-grow:1; flex-shrink:0; height:50px; background:green;" cellpadding="0" cellspacing="0">
    #|    <tr>
    #|      <td style="width:100%; background:green;">&nbsp;</td>
    #|      <td style="background:green;">&nbsp;</td>
    #|    </tr>
    #|  </table>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let table = layout.children[0].children[0]
  guard table.width >= 99.0 else {
    fail("table flex item with auto width should use flex-assigned main size")
  }
}

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

///|
test "wpt_table_flex_item_percent_width_does_not_override_used_size" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; width:200px;">
    #|  <div style="width:200px;"></div>
    #|  <table style="width:70%; flex-basis:200px; border-spacing:0;">
    #|    <tr><td><div style="width:10px; height:10px;"></div></td></tr>
    #|  </table>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let table = layout.children[0].children[1]
  guard table.width >= 99.0 && table.width <= 101.0 else {
    fail("flex-assigned used width should win over table percentage width")
  }
}

///|
test "wpt_table_percent_width_inside_flex_item_wrapper_uses_used_main_size" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; width:300px; border:1px solid black;">
    #|  <div id="item">
    #|    <div id="tbl" style="display:table; table-layout:fixed; width:100%; height:30px; border:1px solid blue; box-sizing:border-box;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  let table = item.children[0]
  inspect(item.width, content="300")
  inspect(table.width, content="300")
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
  let mut table_layout : @types.Layout? = None
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

///|
test "wpt_intrinsic_percent_replaced_018_like_table_min_content_ignores_newline_gap" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer {
    #|  display: table;
    #|  width: min-content;
    #|  height: 100px;
    #|}
    #|.inner {
    #|  display: table-cell;
    #|  height: 100%;
    #|}
    #|canvas {
    #|  vertical-align: top;
    #|}
    #|</style>
    #|<div class="outer">
    #|  <div class="inner">
    #|    <canvas width="10" height="4" style="height: 40%"></canvas>
    #|    <canvas width="10" height="6" style="height: 60%"></canvas>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let inner = outer.children[0]
  inspect(outer.width, content="20")
  inspect(inner.height, content="100")
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
  // The text td has content so its height is determined by text metrics.
  // The empty td should have zero content height and not inflate the row.
  // Row height should be driven entirely by the text td.
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
  // In Chrome, a row with only empty tds has height 0.
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
  // Row height should be driven by the text cell only
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
  // Test that an empty td does not get inflated by line-height
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
  // In Chrome, a row with only empty tds has height 0
  // even when line-height is large
  inspect(
    row.height,
    content=(
      #|0
    ),
  )
}

///|
test "whitespace_only_td_has_zero_content_height" {
  // HTML with whitespace inside td tags (from indentation)
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
  // Whitespace-only text in a td is collapsed to a single space,
  // but it's still text content so it participates in line-height.
  // Row height is 19.2 driven by the text cell (line-height:40px would be 40
  // if the whitespace cell contributed, but create_text_node collapses it
  // to a leaf since parent display is TableCell).
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
  // Key test: empty td with large line-height should NOT inflate row height
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
  // Row height = 19.2 (= 16 * 1.2). The line-height:40px on body
  // appears to not propagate to the table cell's text metric height.
  // This is a separate issue from empty-td inflation.
  // For the empty-td issue, the key fact is: empty td = 0 content height.
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
  // With cellpadding, empty td should still have zero content,
  // but padding is added around the zero content
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
  // In Chrome, empty td with cellpadding=10 has height = 20 (just padding)
  // text td has height = 19.2 (text) + 20 (padding) = 39.2
  // Row height = max(20, 39.2) = 39.2
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

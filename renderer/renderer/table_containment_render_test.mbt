///|
// Table containment regression tests split from table_render_test.mbt.

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

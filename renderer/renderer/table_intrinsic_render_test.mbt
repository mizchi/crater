///|
// Table intrinsic sizing regression tests split from table_render_test.mbt.

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

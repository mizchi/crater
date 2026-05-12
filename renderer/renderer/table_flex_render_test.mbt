///|
// Table flex item regression tests split from table_render_test.mbt.

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

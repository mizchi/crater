///|
// Form control renderer regression tests split from render_test.mbt.

///|
test "contain_size_select_single_uses_empty_control_metrics" {
  // Regression for css-contain/contain-size-select-001.html:
  // single-line select with contain:size should ignore option text for sizing.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|select { contain: size; color: transparent; background: white; }
    #|</style>
    #|<select id="s"><option>AVeryLongOption</option><option>Another Option</option></select>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else {
    fail("layout should include select node")
  }
  let select = layout.children[0]
  guard select.id == "select#s" else {
    fail("first body child should be select")
  }
  guard select.width >= 20.0 else {
    fail("single select width should keep empty-control intrinsic width")
  }
  guard select.height >= 18.0 else {
    fail("single select height should keep empty-control intrinsic height")
  }
  guard select.children.length() >= 2 else {
    fail("select should include option children for tree parity")
  }
  let mut option0_found = false
  let mut option0 = select.children[0]
  for child in select.children {
    if child.id == "option" ||
      child.id.has_prefix("option#") ||
      child.id.has_prefix("option.") {
      option0 = child
      option0_found = true
      break
    }
  }
  guard option0_found else { fail("select should include option layout child") }
  guard option0.width <= 1.0 else {
    fail("single select option should not contribute inline width")
  }
  guard option0.height <= 1.0 else {
    fail("single select option should not contribute block height")
  }
}

///|
test "contain_size_select_multiple_clamps_visible_option_rows" {
  // Regression for css-contain/contain-size-select-elem-003.html:
  // multiple select with contain:size should use empty listbox metrics.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|select { contain: size; color: transparent; }
    #|.w { width: 100px; }
    #|</style>
    #|<select id="s" multiple class="w"><option>Very very long option text should not blow up row height</option><option>a</option></select>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let select = layout.children[0]
  guard select.id == "select#s" else {
    fail("first body child should be multiple select")
  }
  inspect(select.width, content="100")
  guard select.height >= 50.0 else {
    fail("multiple select should keep listbox-like default height")
  }
  guard select.children.length() >= 2 else {
    fail("multiple select should keep option children")
  }
  let mut option0_found = false
  let mut option0 = select.children[0]
  for child in select.children {
    if child.id == "option" ||
      child.id.has_prefix("option#") ||
      child.id.has_prefix("option.") {
      option0 = child
      option0_found = true
      break
    }
  }
  guard option0_found else {
    fail("multiple select should include option row layout")
  }
  guard option0.height <= 40.0 else {
    fail("option row height should not expand from long option text")
  }
}

///|
test "contain_size_select_multiple_size_one_uses_single_row_height" {
  // Regression for css-contain/contain-size-select-elem-005.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|select { contain: size; color: transparent; }
    #|</style>
    #|<select id="s" multiple size="1"><option>X</option></select>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let select = layout.children[0]
  guard select.id == "select#s" else {
    fail("first body child should be select")
  }
  guard select.width <= 4.0 else {
    fail("multiple select width:auto should stay border-box narrow")
  }
  guard select.height >= 16.0 && select.height <= 22.0 else {
    fail("multiple+size=1 should use single-row listbox height")
  }
}

///|
test "select_without_contain_size_uses_option_text_for_auto_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|select {
    #|  color: transparent;
    #|  background: white;
    #|}
    #|</style>
    #|<select id="target">
    #|  <option>AVeryLongOption</option>
    #|  <option>Another Option</option>
    #|</select>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() > 0 else {
    fail("layout should include select node")
  }
  let select = layout.children[0]
  guard select.id == "select#target" else {
    fail("first body child should be target select")
  }
  guard select.width >= 100.0 else {
    fail("auto-width select without contain:size should reflect option text")
  }
}

///|
test "float_after_br_starts_after_inline_select_line" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|select { color: transparent; }
    #|.floatL { float: left; }
    #|</style>
    #|<select id="lead">
    #|  <option>a</option>
    #|</select>
    #|<br id="linebreak">
    #|<select id="tail" class="floatL">
    #|  <option>a</option>
    #|</select>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let mut lead_x = -1.0
  let mut br_x = -1.0
  let mut tail_y = -1.0
  for child in layout.children {
    if child.id == "select#lead" {
      lead_x = child.x
    } else if child.id == "br#linebreak" {
      br_x = child.x
    } else if child.id == "select#tail" {
      tail_y = child.y
    }
  }
  guard lead_x >= 0.0 else { fail("layout should include lead select") }
  guard br_x >= 0.0 else { fail("layout should include linebreak br") }
  guard tail_y >= 0.0 else { fail("layout should include tail float select") }
  guard lead_x <= 1.0 else {
    fail("leading inline select should not be shifted by later float")
  }
  guard br_x >= 20.0 else {
    fail("br should keep inline advance from leading select width")
  }
  guard tail_y >= 18.0 else {
    fail("float placed after br should start on a later line")
  }
}

///|
test "contain_size_select_single_option_text_does_not_shift_following_rows" {
  // Regression for css-contain/contain-size-select-elem-001.html:
  // hidden option text in single-line select should not advance block flow.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|select { contain: size; color: transparent; }
    #|.minWidth { min-width: 100px; }
    #|.width { width: 100px; }
    #|</style>
    #|<select id="s1"><option>Very long option text should stay internal</option><option>a</option></select>
    #|<br id="b1">
    #|<select id="s2" class="minWidth"><option>Very long option text should stay internal</option><option>b</option></select>
    #|<br id="b2">
    #|<select id="s3" class="width"><option>Very long option text should stay internal</option><option>c</option></select>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let mut b2_y = -1.0
  let mut s3_y = -1.0
  for child in layout.children {
    if child.id == "br#b2" {
      b2_y = child.y
    } else if child.id == "select#s3" {
      s3_y = child.y
    }
  }
  guard b2_y >= 0.0 else { fail("layout should include second br") }
  guard s3_y >= 0.0 else { fail("layout should include third select") }
  guard b2_y <= 40.0 else {
    fail("single select option text should not push second br down")
  }
  guard s3_y <= 60.0 else {
    fail("single select option text should not push later select down")
  }
}

///|
test "form_controls_max_content_intrinsic_size_wpt_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|input, textarea { font: 20px monospace; white-space: pre; }
    #|</style>
    #|<input id="i" value="sample text" style="width: max-content">
    #|<textarea id="t" rows="3" cols="12" style="height: max-content">sample text 1</textarea>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let input = layout.children[0]
  let textarea = layout.children[1]
  inspect(
    input.width,
    content=(
      #|215
    ),
  )
  inspect(
    textarea.width,
    content=(
      #|8
    ),
  )
  inspect(textarea.height > 0.0, content="true")
}

///|
test "input_button_like_intrinsic_width_uses_value_length" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.row { display: flex; border: 1px solid black; }
    #|.row > * {
    #|  contain: layout;
    #|  border: 2px solid teal;
    #|  align-self: baseline;
    #|  margin: 2px;
    #|}
    #|</style>
    #|<div class="row"><input id="btn" type="button" value="i-btn"><input id="sub" type="submit" value="i-sub"></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let row = layout.children[0]
  let input_btn = row.children[0]
  let input_sub = row.children[1]
  guard input_btn.width > 30.0 && input_btn.width < 60.0 else {
    fail("button-like input intrinsic width should track value text length")
  }
  guard input_sub.width > 30.0 && input_sub.width < 60.0 else {
    fail("submit-like input intrinsic width should track value text length")
  }
}

///|
test "text_input_auto_height_includes_explicit_padding_and_border" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|input {
    #|  font-size: 14px;
    #|  line-height: normal;
    #|  padding: 10px 12px;
    #|  border: 1px solid #d1d5db;
    #|}
    #|</style>
    #|<input id="email" type="email" placeholder="you@example.com">
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let input = layout.children[0]
  guard input.height >= 36.0 && input.height <= 40.0 else {
    fail(
      "text input auto height should include explicit vertical padding and border",
    )
  }
}

///|
test "wpt_justify_self_widgets_textarea_keeps_browser_default_block_heights" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.widget {
    #|  display: block;
    #|  width: auto;
    #|  box-sizing: border-box;
    #|}
    #|</style>
    #|<input class="widget" style="justify-self: normal">
    #|<input class="widget" style="justify-self: start">
    #|<input class="widget" style="justify-self: end">
    #|<input class="widget" style="justify-self: stretch">
    #|<select class="widget" style="justify-self: normal"></select>
    #|<select class="widget" style="justify-self: start"></select>
    #|<select class="widget" style="justify-self: end"></select>
    #|<select class="widget" style="justify-self: stretch"></select>
    #|<textarea class="widget" style="justify-self: normal"></textarea>
    #|<textarea class="widget" style="justify-self: start"></textarea>
    #|<textarea class="widget" style="justify-self: end"></textarea>
    #|<textarea class="widget" style="justify-self: stretch"></textarea>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let textarea_normal = layout.children[8]
  let textarea_start = layout.children[9]
  let textarea_end = layout.children[10]
  let textarea_stretch = layout.children[11]

  inspect(textarea_normal.height, content="34")
  inspect(textarea_start.y - textarea_normal.y, content="34")
  inspect(textarea_end.y - textarea_start.y, content="34")
  inspect(textarea_stretch.y - textarea_end.y, content="34")
}

///|
test "wpt_flex_vertical_align_effect_uses_small_text_input_metrics" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#container {
    #|  display: flex;
    #|  align-items: flex-start;
    #|}
    #|input { margin: 0; padding: 0; vertical-align: middle; }
    #|</style>
    #|<div id="container">
    #|  <input type="text" value="input1" />
    #|  <input type="radio" />
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let container = layout.children[0]
  let text_input = container.children[0]
  let radio = container.children[1]
  guard (text_input.width - 143.0).abs() < 0.1 else {
    fail(
      "text input intrinsic width should match browser small-control metrics",
    )
  }
  guard (text_input.height - 19.5).abs() < 0.1 else {
    fail(
      "text input intrinsic height should match browser small-control metrics",
    )
  }
  guard (radio.x - text_input.width).abs() < 0.1 else {
    fail("radio should follow text input width in flex row layout")
  }
}

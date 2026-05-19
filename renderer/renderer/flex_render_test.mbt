///|
// Flexbox, gap, and alignment renderer regression tests split from
// render_test.mbt and renderer_test.mbt.

///|
test "wpt_row_reverse_default_justify_content_uses_main_start" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; flex-direction:row-reverse; width:200px; height:200px;">
    #|  <div style="width:50px; height:50px;"></div>
    #|  <div style="width:50px; height:50px;"></div>
    #|  <div style="width:50px; height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  inspect(flex.children[0].x, content="150")
  inspect(flex.children[1].x, content="100")
  inspect(flex.children[2].x, content="50")
}

///|
test "wpt_column_reverse_default_justify_content_uses_main_start" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display:flex; flex-direction:column-reverse; width:200px; height:200px;">
    #|  <div style="width:50px; height:50px;"></div>
    #|  <div style="width:50px; height:50px;"></div>
    #|  <div style="width:50px; height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  inspect(flex.children[0].y, content="150")
  inspect(flex.children[1].y, content="100")
  inspect(flex.children[2].y, content="50")
}

///|
test "wpt_row_direction_matches_inline_axis_in_vertical_writing_mode" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#vertical { writing-mode: vertical-lr; }
    #|.test { display: flex; width: 3em; flex-direction: row; }
    #|.test > span { width: 1em; direction: ltr; }
    #|#row-rtl { direction: rtl; }
    #|</style>
    #|<div id="vertical">
    #|  <div class="test" id="row-ltr"><span>A</span><span>B</span><span>C</span></div>
    #|  <div class="test" id="row-rtl"><span>C</span><span>B</span><span>A</span></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let vertical = layout.children[0]
  let row_ltr = vertical.children[0]
  let row_rtl = vertical.children[1]
  inspect(row_ltr.height, content="24")
  inspect(row_ltr.children[0].y, content="0")
  inspect(row_ltr.children[1].y, content="8")
  inspect(row_ltr.children[2].y, content="16")
  inspect(row_rtl.height, content="24")
  inspect(row_rtl.children[0].y, content="16")
  inspect(row_rtl.children[1].y, content="8")
  inspect(row_rtl.children[2].y, content="0")
}

///|
test "flex_item_rem_line_height_affects_inline_box_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.row { display: flex; align-items: center; }
    #|.control { width: 24px; height: 24px; }
    #|.label { font-size: 0.875rem; line-height: 1.25rem; }
    #|</style>
    #|<div class="row"><span class="control"></span><span class="label">Checked</span></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let row = layout.children[0]
  inspect(row.height, content="24")
  let label = row.children[1]
  inspect(label.y, content="2")
  inspect(label.height, content="20")
}

///|
test "contain_size_fieldset_in_flex_keeps_baseline_sized_line" {
  // Regression for css-contain/contain-size-fieldset-004.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.contain {
    #|  contain: size;
    #|  border: none;
    #|  color: transparent;
    #|  visibility: hidden;
    #|}
    #|.innerContents { height: 50px; width: 50px; }
    #|.flexBaselineCheck { display: flex; align-items: baseline; }
    #|</style>
    #|<div id="row" class="flexBaselineCheck">
    #|  outside before
    #|  <fieldset class="contain">
    #|    <legend>legend</legend>
    #|    <div class="innerContents">inner</div>
    #|  </fieldset>
    #|  outside after
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let row = layout.children[0]
  guard row.id == "div#row" else {
    fail("first body child should be baseline flex row")
  }
  guard row.height >= 40.0 else {
    fail(
      "contain:size fieldset in baseline flex row should keep taller baseline line",
    )
  }
}

///|
test "flex_item_with_contain_layout_uses_synthesized_baseline" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#flex {
    #|  display: inline-flex;
    #|  align-items: baseline;
    #|}
    #|canvas {
    #|  width: 50px;
    #|  height: 100px;
    #|}
    #|#item {
    #|  contain: layout;
    #|  width: 50px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div id="flex"><canvas></canvas><div id="item">item</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  guard flex.height == 100.0 else {
    fail("baseline-synthesized flex line should keep 100px cross size")
  }
  let item = flex.children[1]
  guard item.y == 0.0 else {
    fail("contain:layout flex item should align with synthesized baseline")
  }
}

///|
test "wpt_gap_vertical_writing_lr_inline_size_propagation" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; writing-mode: vertical-lr; }
    #|section { display: flex; block-size: 100px; gap: 20px; }
    #|section > div { flex: 1 1 auto; }
    #|</style>
    #|<section><div></div><div></div><div></div></section>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let section = layout.children[0]
  guard section.width >= 99.0 else {
    fail("section block-size should map to physical width in vertical writing")
  }
  guard section.height >= 500.0 else {
    fail("section inline-size should use available viewport height")
  }
  guard section.children[0].height > 100.0 else {
    fail("flex item should receive non-zero main size with gap distribution")
  }
}

///|
test "wpt_gap_rtl_direction_inheritance_for_flex" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; direction: rtl; }
    #|section { display: flex; block-size: 100px; gap: 20px; }
    #|section > div { flex: 1 1 auto; }
    #|</style>
    #|<section><div></div><div></div><div></div></section>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let section = root.children[0]
  assert_true(section.style.direction.is_rtl())

  let layout = @renderer.render(html_str, ctx)
  let section_layout = layout.children[0]
  guard section_layout.children.length() == 3 else {
    fail("section should have three flex items")
  }
  let x0 = section_layout.children[0].x
  let x1 = section_layout.children[1].x
  let x2 = section_layout.children[2].x
  guard x0 > x1 && x1 > x2 else {
    fail("rtl row flex should place earlier DOM items further right")
  }
}

///|
test "wpt_gap_vertical_column_wrap_uses_available_inline_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; writing-mode: vertical-lr; }
    #|section { display: flex; flex-direction: column; flex-wrap: wrap; block-size: 100px; gap: 20px; }
    #|section > div { width: calc(50% - 10px); }
    #|</style>
    #|<section><div></div><div></div><div></div><div></div></section>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let section = layout.children[0]
  guard section.width >= 99.0 else {
    fail("section block-size should map to physical width in vertical writing")
  }
  guard section.height >= 500.0 else {
    fail("section auto inline-size should fill available viewport height")
  }
}

///|
test "wpt_gap_vertical_row_wrap_uses_column_gap_percentage" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.flex { display: flex; width: 220px; height: 200px; writing-mode: vertical-lr; flex-flow: row wrap; column-gap: 10%; row-gap: 10px; align-content: flex-start; justify-content: flex-end; }
    #|.item { width: 28px; height: 28px; border: 1px solid blue; }
    #|</style>
    #|<div class="flex">
    #|  <div class="item"></div><div class="item"></div><div class="item"></div>
    #|  <div class="item"></div><div class="item"></div><div class="item"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  let y0 = flex.children[0].y
  let y1 = flex.children[1].y
  guard y1 - y0 >= 45.0 else {
    fail(
      "row-wrap main-axis gap should follow column-gap percentage in vertical writing",
    )
  }
}

///|
test "wpt_align_content_wrap_004_column_flex_items_use_fit_content_cross_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.flex {
    #|  display: flex;
    #|  flex-wrap: wrap;
    #|  align-content: center;
    #|  flex-direction: column;
    #|  align-items: flex-start;
    #|  width: 100px;
    #|  line-height: 1;
    #|}
    #|.flex > div {
    #|  min-height: 0;
    #|  background: green;
    #|}
    #|.flex * {
    #|  vertical-align: top;
    #|}
    #|</style>
    #|<div class="flex">
    #|  <div style="align-self: stretch;">
    #|    <div style="display: inline-block; width: 20px; height: 40px;"></div>
    #|  </div>
    #|  <div style="height: 60px;">
    #|    <div style="display: inline-block; height: 15px; width: 20px;"></div>
    #|    <div style="display: inline-block; height: 15px; width: 100px;"></div>
    #|    <div style="display: inline-block; height: 15px; width: 100px;"></div>
    #|    <div style="display: inline-block; height: 15px; width: 100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  let first = flex.children[0]
  let second = flex.children[1]

  guard first.x.abs() < 0.01 else {
    fail("first wrapped column flex item should stay at cross-start")
  }
  guard (first.width - 100.0).abs() < 0.01 else {
    fail("stretch item should use fit-content constrained to container width")
  }
  guard second.x.abs() < 0.01 else {
    fail("second wrapped column flex item should stay at cross-start")
  }
  guard (second.width - 100.0).abs() < 0.01 else {
    fail("auto-width wrapped column flex item should use fit-content width")
  }
}

///|
test "wpt_gap_vertical_rl_wrap_progression_is_mirrored" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; writing-mode: vertical-rl; }
    #|section { block-size: 100px; inline-size: 200px; display: inline-flex; flex-wrap: wrap; gap: 20px; }
    #|section > div { block-size: 20px; }
    #|#bp { inline-size: 120px; } #ww { inline-size: 130px; } #s, #f { inline-size: 40px; }
    #|</style>
    #|<section>
    #|  <div id="bp"></div><div id="ww"></div><div id="s"></div><div id="f"></div>
    #|</section>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let section = layout.children[0]
  let bp = section.children[0]
  let ww = section.children[1]
  let f = section.children[3]
  guard (bp.x - 80.0).abs() < 0.01 else {
    fail(
      "first wrapped line should start on the physical right edge in vertical-rl",
    )
  }
  guard (ww.x - 40.0).abs() < 0.01 else {
    fail("second wrapped line should stay in the middle track in vertical-rl")
  }
  guard f.x.abs() < 0.01 else {
    fail(
      "last wrapped line should end on the physical left edge in vertical-rl",
    )
  }
}

///|
test "wpt_overflow_alignment_flex_item_negative_margin_child_vertical_rl" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.test {
    #|  display: flex;
    #|  flex-flow: row wrap;
    #|  width: 24px;
    #|  height: 24px;
    #|  overflow: hidden;
    #|  writing-mode: vertical-rl;
    #|}
    #|.container { width: 24px; height: 24px; flex: none; }
    #|.child {
    #|  width: 72px;
    #|  height: 72px;
    #|  margin: -24px;
    #|  writing-mode: horizontal-tb;
    #|  direction: ltr;
    #|}
    #|</style>
    #|<div class="test"><div class="container"><div class="child"></div></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let test_box = layout.children[0]
  let container = test_box.children[0]
  let child = container.children[0]
  inspect(container.x, content="0")
  inspect(container.y, content="0")
  inspect(child.x, content="-24")
  inspect(child.y, content="-24")
}

///|
test "wpt_overflow_alignment_flex_item_negative_margin_child_vertical_lr" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.test {
    #|  display: flex;
    #|  flex-flow: row wrap;
    #|  width: 24px;
    #|  height: 24px;
    #|  overflow: hidden;
    #|  writing-mode: vertical-lr;
    #|}
    #|.container { width: 24px; height: 24px; flex: none; }
    #|.child {
    #|  width: 72px;
    #|  height: 72px;
    #|  margin: -24px;
    #|  writing-mode: horizontal-tb;
    #|  direction: ltr;
    #|}
    #|</style>
    #|<div class="test"><div class="container"><div class="child"></div></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let test_box = layout.children[0]
  let container = test_box.children[0]
  let child = container.children[0]
  inspect(container.x, content="0")
  inspect(container.y, content="0")
  inspect(child.x, content="-24")
  inspect(child.y, content="-24")
}

///|
test "flex_stretch_respects_min_height_through_renderer" {
  let html_str =
    #|<!DOCTYPE html>
    #|<div id="target" style="display:flex; min-height:200px;">
    #|  <div id="item" style="width:100px; min-height:100px; background:green;"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let target = layout.children[0]
  let item = target.children[0]
  inspect(target.height, content="200")
  inspect(item.height, content="200")
}

///|
test "flex_baseline_align_offsets_smaller_font_item" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#test { display: flex; }
    #|#test div { align-self: baseline; }
    #|#div1 { height: 90px; font-size: 20px; width: 30px; }
    #|#div2 { height: 50px; font-size: 10px; width: 30px; }
    #|#div3 { height: 100px; font-size: 30px; width: 30px; }
    #|</style>
    #|<div id="test">
    #|  <div id="div1"><a href="#">aaa</a></div>
    #|  <div id="div2"><a href="#">aaa</a></div>
    #|  <div id="div3"><a href="#">aaa</a></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let div1 = layout.children[0].children[0]
  let div2 = layout.children[0].children[1]
  let div3 = layout.children[0].children[2]
  guard div3.y <= div1.y else {
    fail("largest-font item should anchor baseline reference")
  }
  guard div1.y < div2.y else {
    fail("smaller-font item should be pushed down for baseline alignment")
  }
  guard div2.y > 10.0 else {
    fail("baseline offset for smaller-font item should be visibly non-zero")
  }
}

///|
test "wpt_column_flex_align_items_baseline_falls_back_to_cross_side" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|h1, p { margin: 0; }
    #|.flexbox { display: flex; }
    #|.column { flex-direction: column; }
    #|.align-items-baseline { align-items: baseline; }
    #|.wrap-reverse { flex-wrap: wrap-reverse; }
    #|</style>
    #|<div id="left" class="flexbox column align-items-baseline">
    #|  <h1>This text</h1>
    #|  <p>should be left aligned.</p>
    #|</div>
    #|<div id="right" class="flexbox column align-items-baseline wrap-reverse">
    #|  <h1>This text</h1>
    #|  <p>should be right aligned.</p>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let left = layout.children[0]
  let right = layout.children[1]
  let left_h1 = left.children[0]
  let left_p = left.children[1]
  let right_h1 = right.children[0]
  let right_p = right.children[1]

  guard left_h1.x.abs() < 0.01 else {
    fail(
      "column flex baseline should fall back to cross-start for the first item",
    )
  }
  guard left_p.x.abs() < 0.01 else {
    fail(
      "column flex baseline should fall back to cross-start for the second item",
    )
  }
  guard (right_h1.x - right_p.x).abs() < 0.01 else {
    fail(
      "wrap-reverse column baseline should keep both items on one cross-side",
    )
  }
  guard (right_p.x + right_p.width - layout.width).abs() < 0.01 else {
    fail("wrap-reverse column baseline should fall back to cross-end")
  }
}

///|
test "flex_margin_no_collapse_wpt" {
  // Mimics the exact WPT test flex-margin-no-collapse.html
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#container {
    #|  display: flex;
    #|  flex-direction: column;
    #|  position: absolute;
    #|  top: 100px;
    #|  left: 10px;
    #|  width: 200px;
    #|  height: 300px;
    #|}
    #|.box {
    #|  width: 100px;
    #|  height: 100px;
    #|  flex: none;
    #|}
    #|#box1 { margin: 50px 0; }
    #|#box2 { margin: 50px 0; }
    #|</style>
    #|<div id="container">
    #|  <div id="box1" class="box"></div>
    #|  <div id="box2" class="box"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  // Verify node structure
  inspect(root.id, content="body")
  let container = root.children[0]
  inspect(container.id, content="div#container")
  let box1 = container.children[0]
  let box2 = container.children[1]
  inspect(box1.id, content="div#box1")
  inspect(box2.id, content="div#box2")

  // Check if flex: none parsed correctly
  inspect(box1.style.flex_shrink, content="0")
  inspect(box1.style.flex_grow, content="0")
  inspect(box2.style.flex_shrink, content="0")
  inspect(box2.style.flex_grow, content="0")

  // Check margins parsed correctly
  inspect(box1.style.margin.top, content="Length(50)")
  inspect(box1.style.margin.bottom, content="Length(50)")
  inspect(box2.style.margin.top, content="Length(50)")
  inspect(box2.style.margin.bottom, content="Length(50)")

  // Check position: absolute on container
  inspect(container.style.position, content="Absolute")

  // Compute layout using render function (same as WASM API)
  let layout = @renderer.render(html_str, ctx)

  // Debug: check container dimensions
  let container_layout = layout.children[0]
  inspect(container_layout.id, content="div#container")
  inspect(container_layout.x, content="10")
  inspect(container_layout.y, content="100")
  let box1_layout = container_layout.children[0]
  let box2_layout = container_layout.children[1]

  // Expected layout:
  // box1.y = 50 (margin-top)
  // box2.y = 50 + 100 + 50 + 50 = 250 (margin-top + height + margin-bottom + margin-top)
  inspect(box1_layout.y, content="50")
  inspect(box1_layout.height, content="100")
  inspect(box2_layout.y, content="250")
  inspect(box2_layout.height, content="100")
}

///|
test "google_header_flex_grow_wrapper_keeps_actions_right_aligned" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.nav { display: flex; align-items: center; width: 800px; height: 60px; }
    #|.left1 { display: inline-block; width: 120px; height: 20px; }
    #|.left2 { display: inline-block; width: 60px; height: 20px; }
    #|.grow { display: inline-block; flex-grow: 1; }
    #|.actions { display: flex; justify-content: flex-end; width: 100%; height: 40px; }
    #|.login { width: 85px; height: 40px; }
    #|</style>
    #|<div class="nav">
    #|  <a class="left1"></a>
    #|  <a class="left2"></a>
    #|  <div class="grow"><header class="actions"><a id="login" class="login"></a></header></div>
    #|</div>

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let nav = layout.children[0]
  let left1 = nav.children[0]
  let left2 = nav.children[1]
  let grow = nav.children[2]
  let actions = grow.children[0]
  let login = actions.children[0]

  inspect(left1.width, content="120")
  inspect(left2.x, content="120")
  inspect(grow.x, content="180")
  inspect(grow.width, content="620")
  inspect(actions.width, content="620")
  inspect(login.id, content="a#login")
  inspect(login.x, content="535")
  inspect(login.width, content="85")
}

///|
test "google_footer_nested_flex_groups_share_one_wrapped_row" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; font: 14px Arial, sans-serif; }
    #|.outer {
    #|  display: flex;
    #|  flex-wrap: wrap;
    #|  justify-content: space-evenly;
    #|  width: 760px;
    #|  padding: 0 20px;
    #|}
    #|.group {
    #|  display: flex;
    #|  flex-wrap: wrap;
    #|}
    #|a {
    #|  display: block;
    #|  padding: 15px;
    #|  white-space: nowrap;
    #|}
    #|</style>
    #|<div class="outer">
    #|  <div id="left" class="group"><a>広告</a><a>ビジネス</a><a>検索の仕組み</a></div>
    #|  <div id="right" class="group"><a>プライバシー</a><a>規約</a><a>設定</a></div>
    #|</div>

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let left = outer.children[0]
  let right = outer.children[1]

  inspect(left.id, content="div#left")
  inspect(right.id, content="div#right")
  inspect(left.width, content="258")
  inspect(right.y, content="0")
  guard left.width < 360.0 else {
    fail("nested flex group should shrink to its content width")
  }
}

///|
test "safe center stylesheet falls back to start in row reverse wrap reverse overflow" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0 }
    #|.test {
    #|  width: 24px;
    #|  height: 24px;
    #|  overflow: hidden;
    #|  display: flex;
    #|  flex-flow: row-reverse wrap-reverse;
    #|  place-content: safe center;
    #|}
    #|.indicator {
    #|  width: 72px;
    #|  height: 72px;
    #|  flex: none;
    #|}
    #|</style>
    #|<div class="test"><div class="indicator"></div></div>
  let layout_root = @renderer.render(
    html_str,
    @renderer.RenderContext::default(),
  )
  let container = layout_root.children[0]
  let indicator = container.children[0]
  inspect(indicator.x, content="0")
  inspect(indicator.y, content="0")
}

///|
test "unsafe center stylesheet keeps centered overflow in row reverse wrap reverse" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0 }
    #|.test {
    #|  width: 24px;
    #|  height: 24px;
    #|  overflow: hidden;
    #|  display: flex;
    #|  flex-flow: row-reverse wrap-reverse;
    #|  place-content: unsafe center;
    #|}
    #|.indicator {
    #|  width: 72px;
    #|  height: 72px;
    #|  flex: none;
    #|}
    #|</style>
    #|<div class="test"><div class="indicator"></div></div>
  let layout_root = @renderer.render(
    html_str,
    @renderer.RenderContext::default(),
  )
  let container = layout_root.children[0]
  let indicator = container.children[0]
  inspect(indicator.x, content="-24")
  inspect(indicator.y, content="-24")
}

///|
test "fit_content_item_001_like_column_flex_intrinsic_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|x-flexbox {
    #|  display: flex;
    #|  flex-direction: column;
    #|}
    #|x-item {
    #|  display: block;
    #|  background: red;
    #|  align-self: start;
    #|}
    #|#mainSizeDependsOnCrossSize {
    #|  padding-bottom: 50%;
    #|  background: green;
    #|}
    #|#widthSetter {
    #|  width: 100px;
    #|  height: 50px;
    #|  background: green;
    #|}
    #|</style>
    #|<x-flexbox>
    #|  <x-item>
    #|    <div id=widthSetter></div>
    #|    <div id=mainSizeDependsOnCrossSize></div>
    #|  </x-item>
    #|</x-flexbox>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flexbox = layout.children[0]
  let item = flexbox.children[0]
  let width_setter = item.children[0]
  let depends = item.children[1]

  inspect(width_setter.height, content="50")
  inspect(depends.height, content="50")
  inspect(item.height, content="100")
  inspect(flexbox.height, content="100")
}

///|
test "flex_item_transferred_sizes_padding_border_sizing_style_parse_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  .flexContainer {
    #|    display: flex;
    #|    flex-direction: column;
    #|    float: left;
    #|  }
    #|  .item {
    #|    background: green;
    #|    padding-left: 25px;
    #|    padding-right: 25px;
    #|    box-sizing: border-box;
    #|  }
    #|</style>
    #|<div class="flexContainer">
    #|  <div class="item" style="min-height:100px; aspect-ratio: 1/1;"></div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let flex = root.children[0]
  let item = flex.children[0]

  inspect(flex.style.display, content="Flex")
  inspect(flex.style.flex_direction, content="Column")
  inspect(item.style.width, content="Auto")
  inspect(item.style.height, content="Auto")
  inspect(item.style.min_height, content="Length(100)")
  debug_inspect(item.style.aspect_ratio, content="Some(1)")
  inspect(item.style.box_sizing, content="BorderBox")
}

///|
test "wpt_align_self_static_position_005_parent_inline_keeps_own_line_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.container {
    #|  position: relative;
    #|  border: 1px solid;
    #|}
    #|.abs {
    #|  position: absolute;
    #|  background: purple;
    #|  align-self: end;
    #|  opacity: 0.5;
    #|}
    #|</style>
    #|<div class="container">
    #|  <span style="font: 20px/1 Ahem;">hello
    #|    <span class="abs">hello</span>
    #|    <span style="vertical-align: top; font-size: 50px;">world</span>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let inline_span = container.children[0]

  inspect(inline_span.height, content="20")
}

///|
test "wpt_flex_item_min_width_min_content_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; height: 100px; width: 0px;">
    #|  <div style="min-width: min-content; flex-basis: 0; background: green; writing-mode: vertical-rl;">
    #|    <div style="width: 100px;"></div>
    #|  </div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let inner_node = root.children[0].children[0].children[0]
  inspect(inner_node.style.writing_mode, content="VerticalRl")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  let inner = item.children[0]

  inspect(item.width, content="100")
  inspect(inner.height, content="100")
}

///|
test "wpt_flex_item_min_height_min_content_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; flex-direction: column; width: 100px; height: 0px;">
    #|  <div style="min-height: min-content; flex-basis: 0; background: green;">
    #|    <div style="height: 100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  inspect(item.height, content="100")
}

///|
test "wpt_flex_item_max_height_min_content_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; flex-direction: column; width: 100px; height: 200px;">
    #|  <div style="max-height: min-content; flex-basis: 200px; background: green;">
    #|    <div style="height: 100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  inspect(item.height, content="100")
}

///|
test "wpt_flex_item_max_width_min_content_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; height: 100px; width: 200px;">
    #|  <div style="max-width: min-content; flex-basis: 200px; background: green; writing-mode: vertical-rl;">
    #|    <div style="width: 100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  let inner = item.children[0]
  inspect(item.width, content="100")
  inspect(inner.height, content="100")
}

///|
test "wpt_flex_item_max_width_min_content_002_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; flex-direction: column; width: 200px; height: 100px;">
    #|  <div style="max-width: min-content; background: green;">
    #|    <div style="float: left; width: 100px; height: 50px;"></div>
    #|    <div style="float: left; width: 100px; height: 50px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  inspect(item.width, content="100")
  inspect(item.height, content="100")
}

///|
test "wpt_flex_item_content_min_width_max_content_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.flex { width: 0px; display: flex; font-family: monospace; font-size: 20px; line-height: 1.2; }
    #|.flex_item { background: green; }
    #|.content { min-width: max-content; color: transparent; }
    #|</style>
    #|<div class="flex">
    #|  <div class="flex_item">
    #|    <div class="content">X X X</div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let item = layout.children[0].children[0]
  let content = item.children[0]
  guard item.width > 40.0 else {
    fail("min-width:max-content should prevent flex item from collapsing")
  }
  guard content.height < 40.0 else {
    fail("min-width:max-content content should stay on a single line")
  }
}

///|
test "hn_flex_nav_name_link_keeps_single_line_auto_min_width" {
  @renderer.clear_text_metrics_provider()
  let provider = @renderer.TextMetricsProvider::new(fn(
    text : String,
    _font_size : Double,
    line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @layout_types.MeasureFunc {
    let trimmed = text.trim()
    let min_width = if trimmed == "Hacker News" {
      45.0
    } else {
      trimmed.length().to_double() * 7.0
    }
    let max_width = if trimmed == "Hacker News" { 95.0 } else { min_width }
    {
      func: fn(
        available_width : Double,
        _available_height : Double,
      ) -> @layout_types.IntrinsicSize {
        let wraps = available_width > 0.0 && available_width < max_width
        {
          min_width,
          max_width,
          min_height: line_height,
          max_height: if wraps {
            line_height * 2.0
          } else {
            line_height
          },
        }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: Verdana, Geneva, sans-serif; font-size: 10pt; }
    #|#header { display: flex; align-items: center; width: 800px; }
    #|#header nav { display: flex; gap: 6px; }
    #|</style>
    #|<div id="header">
    #|  <span>Y</span>
    #|  <nav>
    #|    <a><b>Hacker News</b></a>
    #|    <span>|</span><a>new</a>
    #|    <span>|</span><a>past</a>
    #|  </nav>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let header = layout.children[0]
  let nav = header.children[1]
  let hn = nav.children[0]
  guard hn.width >= 90.0 else {
    fail("Hacker News flex item should keep its max-content width")
  }
  guard hn.height <= 18.0 else {
    fail("Hacker News flex item should not wrap to two lines")
  }
  let hn_text = hn.children[0]
  guard hn_text.width >= 90.0 else {
    fail("Hacker News text child should inherit the one-line flex item width")
  }
  guard hn_text.height <= 18.0 else {
    fail("Hacker News text child should not wrap to two lines")
  }
  @renderer.clear_text_metrics_provider()
}

///|
test "wpt_flex_child_percent_basis_resize_1_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|  .flex-container { display: flex; flex-direction: row; width: 100px; }
    #|  .flex-item { flex: 1 0 auto; }
    #|  .scroll-outer { overflow: hidden; height: 100%; max-height: 100px; }
    #|  .scroll-inner { overflow: scroll; height: 100%; }
    #|</style>
    #|<div class="flex-container">
    #|  <div class="flex-item">
    #|    <div class="scroll-outer">
    #|      <div class="scroll-inner">
    #|        <div>0</div><div>1</div><div>2</div><div>3</div><div>4</div>
    #|        <div>5</div><div>6</div><div>7</div><div>8</div><div>9</div>
    #|        <div>0</div><div>1</div><div>2</div><div>3</div><div>4</div>
    #|        <div>5</div><div>6</div><div>7</div><div>8</div><div>9</div>
    #|      </div>
    #|    </div>
    #|  </div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let flex_item_node = root.children[0].children[0]
  let scroll_outer_node = flex_item_node.children[0]
  inspect(scroll_outer_node.style.height, content="Percent(1)")
  inspect(scroll_outer_node.style.max_height, content="Length(100)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let flex_item = container.children[0]
  let scroll_outer = flex_item.children[0]
  let scroll_inner = scroll_outer.children[0]
  inspect(container.height, content="100")
  inspect(flex_item.height, content="100")
  inspect(scroll_outer.height, content="100")
  inspect(scroll_inner.height, content="100")
}

///|
test "studio flex root percent height expands under auto wrapper" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  body { margin: 0; }
    #|  .StudioCanvas {
    #|    display: flex;
    #|    min-height: 100dvh;
    #|  }
    #|  .StudioCanvas > .root {
    #|    min-height: 100dvh;
    #|  }
    #|  .root {
    #|    display: flex;
    #|    flex-direction: column;
    #|    height: 100%;
    #|    overflow: clip;
    #|    padding-top: 1px;
    #|    width: 100%;
    #|  }
    #|  .content { height: 6622px; }
    #|</style>
    #|<div class="StudioCanvas"><div class="root"><main class="content"></main></div></div>
  let ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 1440.0,
    viewport_height: 900.0,
  }
  let layout = @renderer.render(html_str, ctx)
  let canvas = layout.children[0]
  let root = canvas.children[0]
  let content = root.children[0]
  inspect(root.id, content="div.root")
  inspect(content.height, content="6622")
  guard root.height > 6600.0 else {
    fail("dynamic viewport min-height should not clip Studio root to padding")
  }
}

///|
test "wpt_flex_container_min_content_uses_item_min_content_contribution" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font: 10px/1 monospace; }
    #|.wrap > * {
    #|  width: min-content;
    #|  height: min-content;
    #|  float: left;
    #|}
    #|.wrap { width: 0; height: 0; }
    #|.row { display: flex; }
    #|.item {
    #|  margin: 5px;
    #|  padding: 3px;
    #|  border: 2px solid aqua;
    #|}
    #|</style>
    #|<div class="wrap">
    #|  <div class="row">
    #|    <div class="item" style="flex: auto">X X</div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let wrap = layout.children[0]
  let row = wrap.children[0]
  let item = row.children[0]
  inspect(wrap.width, content="0")
  inspect(row.width, content="25")
  inspect(item.width, content="15")
}

///|
test "wpt_overflow_top_left_keeps_stretched_item_inside_column_cross_size" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.column-wrapper {
    #|  width: 300px;
    #|  overflow: auto;
    #|  display: flex;
    #|  flex-direction: column;
    #|  direction: rtl;
    #|  border: 2px solid black;
    #|}
    #|.column-wrapper > div {
    #|  margin: 4px;
    #|  height: 30px;
    #|  background: #ccc;
    #|}
    #|.h-overflow { width: 500px; }
    #|</style>
    #|<div class="column-wrapper">
    #|  <div>one</div>
    #|  <div class="h-overflow">two</div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let wrapper = layout.children[0]
  let first = wrapper.children[0]
  let second = wrapper.children[1]
  inspect(first.x, content="6")
  inspect(first.width, content="292")
  inspect(second.x, content="-202")
  inspect(second.width, content="500")
}

///|
test "stylesheet flex-direction is applied" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>.row { display: flex; flex-direction: row; gap: 10px; }</style>
    #|<style>.box { width: 50px; height: 50px; }</style>
    #|</head>
    #|<body>
    #|<div class="row">
    #|  <div class="box">A</div>
    #|  <div class="box">B</div>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  // Check that div B has x > 0 (row direction)
  let body = layout
  let row_div = body.children[0]
  inspect(row_div.id, content="div.row")
  if row_div.children.length() >= 2 {
    let div_a = row_div.children[0]
    let div_b = row_div.children[1]
    // In row direction, B should be to the right of A with gap
    // A at x=0, B at x=50+10(gap)=60
    inspect(div_a.x, content="0")
    inspect(div_a.y, content="0")
    inspect(div_b.x, content="60")
    inspect(div_b.y, content="0")
  }
}

///|
test "align_self_static_position_005_inline_span_stays_inline" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|.container {
    #|  position: relative;
    #|  border: 1px solid;
    #|}
    #|
    #|.abs {
    #|  position: absolute;
    #|  background: purple;
    #|  align-self: end;
    #|  opacity: 0.5;
    #|}
    #|</style>
    #|<div class="container">
    #|  <span style="font: 20px/1 Ahem;">hello
    #|    <span class="abs">hello</span>
    #|    <span style="vertical-align: top; font-size: 50px;">world</span>
    #|  </span>
    #|</div>
  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let container = root.children[0]
  inspect(container.id, content="div.container")
  let inline_span = container.children[0]
  inspect(inline_span.id, content="span")
  inspect(inline_span.style.display, content="Inline")
  let mut has_abs = false
  for child in inline_span.children {
    if child.id == "span.abs" {
      inspect(child.style.position, content="Absolute")
      has_abs = true
    }
  }
  inspect(has_abs, content="true")
}

///|
test "anchor remains inline inside fixed-height flex item" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<style>
    #|#test { display: flex; }
    #|#test div { align-self: baseline; }
    #|#div1 { height: 90px; font-size: 20px; width: 30px; }
    #|</style>
    #|<div id="test"><div id="div1"><a href="#">aaa</a></div></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let target = node.children[0]
  let div1 = target.children[0]
  let anchor = div1.children[0]
  inspect(target.style.display, content="Flex")
  inspect(div1.style.display, content="Block")
  inspect(div1.style.zoom, content="1")
  inspect(anchor.id, content="a")
  inspect(anchor.style.display, content="Inline")
}

///|
test "wpt_baseline_row_horz_text_nodes_keep_single_line_metrics" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|#target {
    #|  display: flex;
    #|  align-items: baseline;
    #|  inline-size: min-content;
    #|  block-size: 100px;
    #|  border: solid 3px;
    #|}
    #|#target > div {
    #|  margin: 5px 7px 9px 11px;
    #|}
    #|#target > :nth-child(1) {
    #|  background: lime;
    #|  font: 30px/1 Ahem;
    #|}
    #|#target > :nth-child(2) {
    #|  background: hotpink;
    #|  font: 20px/1 Ahem;
    #|}
    #|#target > :nth-child(3) {
    #|  background: cyan;
    #|  writing-mode: vertical-rl;
    #|  font: 16px/1 Ahem;
    #|  width: 40px;
    #|  height: 40px;
    #|}
    #|</style>
    #|</head><body>
    #|<div id="target">
    #|  <div>line1<br>line2</div>
    #|  <div>line1<br>line2</div>
    #|  <div></div>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let target = node.children[0]
  let first = target.children[0]
  let text1 = first.children[0]
  let text2 = first.children[2]
  inspect(first.style.width, content="Auto")
  inspect(first.style.font_size, content="30")
  inspect(text1.style.font_size, content="30")
  inspect(text1.style.line_height, content="30")
  debug_inspect(text1.text, content="Some(\"line1\")")
  debug_inspect(text2.text, content="Some(\"line2\")")

  let layout = @renderer.render(html, ctx)
  let target_layout = layout.children[0]
  let first_layout = target_layout.children[0]
  inspect(
    first_layout.height,
    content=(
      #|60
    ),
  )
  inspect(
    first_layout.children[0].height,
    content=(
      #|30
    ),
  )
  inspect(first_layout.children[1].y, content="0")
  inspect(
    first_layout.children[2].y,
    content=(
      #|30
    ),
  )
}

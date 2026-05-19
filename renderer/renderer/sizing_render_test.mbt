///|
// Intrinsic sizing renderer regression tests split from render_test.mbt.

///|
test "wpt_intrinsic_percent_non_replaced_calc_mixed_static_layout" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#outer {
    #|  display: inline-block;
    #|  border: 5px solid;
    #|  padding: 3px;
    #|}
    #|#inner {
    #|  min-width: calc(100px + 50%);
    #|  min-height: calc(100px + 50%);
    #|  border: 2px solid cyan;
    #|}
    #|</style>
    #|<div id="outer">
    #|  <div id="inner"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let outer = layout.children[0]
  let inner = outer.children[0]

  inspect(outer.height, content="420")
  inspect(inner.width, content="104")
  inspect(inner.height, content="404")
}

///|
test "height mixed calc percentage uses vertical viewport basis" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#logo-slot {
    #|  min-height: 150px;
    #|  height: calc(100% - 560px);
    #|  max-height: 290px;
    #|}
    #|</style>
    #|<div id="logo-slot"></div>
  let ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let root = @renderer.render_to_node(html_str, ctx)
  let slot_node = root.children[0]
  inspect(slot_node.style.height, content="Length(40)")

  let layout = @renderer.render(html_str, ctx)
  let slot = layout.children[0]
  inspect(slot.height, content="150")
}

///|
test "wpt_margin_collapse_indefinite_block_size_005_like_stretch_behaves_as_auto" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<p>Test passes if there is a filled green square and no red.</p>
    #|<div style="width: 100px; height: stretch; background: red">
    #|  <div style="height: 100px; margin-bottom: 100px; background: green"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[1]
  let inner = outer.children[0]

  inspect(outer.height, content="100")
  inspect(inner.height, content="100")
  inspect(inner.y, content="0")
}

///|
test "wpt_min_content_le_max_content_zero_font_whitespace_has_zero_advance" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|main {
    #|  width: 100px;
    #|  height: 100px;
    #|  font-size: 0;
    #|}
    #|span {
    #|  display: inline-block;
    #|  vertical-align: top;
    #|  height: 50px;
    #|}
    #|</style>
    #|<main>
    #|  <div style="width: min-content">
    #|    <span style="width: 100px"></span>
    #|    <span style="margin-right: -50px"></span>
    #|  </div>
    #|</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(root.id, content="body")
  let main = root.children[0]
  inspect(main.id, content="main")
  inspect(main.style.font_size, content="0")
  let inner = main.children[0]
  inspect(inner.style.font_size, content="0")
  let gap = inner.children[1]
  inspect(gap.id, content="#text")
  inspect(gap.style.font_size, content="0")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let main_layout = layout.children[0]
  let inner_layout = main_layout.children[0]
  let second = inner_layout.children[2]
  inspect(inner_layout.children[1].width, content="0")
  inspect(inner_layout.height, content="50")
  inspect(second.x, content="100")
  inspect(second.y, content="0")
}

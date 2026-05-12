///|
test "orthogonal_block_auto_margin_centers_in_vertical_parent" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html { writing-mode: vertical-lr; width: 100vw; height: 100vh; overflow: hidden; }
    #|body { margin: 0; border-top: 100px solid red; border-bottom: 100px solid green; width: 100vw; height: 100vh; contain: layout; }
    #|p { margin: auto; padding: 150px 0; writing-mode: horizontal-tb; direction: ltr; }
    #|</style>
    #|<p>Test passes if there is no red.</p>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let p = layout.children[0]
  guard p.width < 400.0 else {
    fail("orthogonal auto-width block should not fill full viewport width")
  }
  guard p.y > 200.0 else {
    fail("vertical parent with auto margins should center orthogonal child")
  }
}

///|
test "vertical_text_block_wraps_to_available_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; writing-mode: vertical-rl; }
    #|.box { width: 160px; height: 240px; }
    #|p { margin: 0; }
    #|</style>
    #|<div class="box">
    #|  <p>a b c d e f g h i j k l m n o p q r s t u v w x y z LTR clear:inline-start</p>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let box = layout.children[0]
  let paragraph = box.children[0]
  inspect(
    paragraph.height,
    content=(
      #|240
    ),
  )
  guard paragraph.width > 0.0 && paragraph.width < 160.0 else {
    fail("vertical text block should wrap into multiple columns")
  }
}

///|
test "wpt_logical_float_vertical_rl_auto_width_shift_keeps_float_positions" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html { writing-mode: vertical-rl; }
    #|body > div { height: 20em; margin: 1em; padding: 2px; border: 1px solid silver; }
    #|div > div { margin: .5em; padding: .5em; background: yellow; }
    #|.is { float: left; }
    #|.ie { float: right; }
    #|.ltr { direction: ltr; }
    #|</style>
    #|<div class="ltr">
    #| Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    #| Phasellus efficitur nisi at sollicitudin eleifend.
    #| <div class="is">Inline-start</div>
    #| Vestibulum ac condimentum diam. Vivamus viverra iaculis mollis.
    #| Nam bibendum, dolor id porttitor egestas, metus sem pretium eros,
    #| ut mollis mauris ligula eu risus. Aenean eget vestibulum nunc.
    #| <div class="ie">Inline-end</div>
    #| Nam vitae eleifend tellus. Vestibulum ut accumsan lacus.
    #| Vivamus vitae eros hendrerit, tincidunt augue non, laoreet justo.
    #| Aliquam erat volutpat.
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let inline_start = target.children[1]
  let inline_end = target.children[3]
  guard target.width > 200.0 && target.width < 300.0 else {
    fail("vertical logical float container should shrink to content width")
  }
  guard inline_start.x > inline_end.x else {
    fail("inline-start float should stay on the block-start side")
  }
  guard inline_start.x < target.width else {
    fail("inline-start float should remain inside the container width")
  }
  guard inline_end.x >= 0.0 else {
    fail(
      "inline-end float should not end up with a negative x after width shrink",
    )
  }
}

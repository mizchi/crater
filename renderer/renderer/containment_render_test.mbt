///|
test "contain_inline_size_uses_contain_intrinsic_inline_size_fallback" {
  // Mirrors css-contain/contain-inline-size-intrinsic.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="background:green; contain:inline-size; height:50px; width:fit-content; contain-intrinsic-inline-size:100px">
    #|  <div style="display:inline-block; width:75px;"></div>
    #|  <div style="display:inline-block; width:75px;"></div>
    #|</div>
    #|<div style="background:green; contain:inline-size; height:fit-content; width:100px; contain-intrinsic-inline-size:50px; writing-mode: vertical-rl;">
    #|  <div style="display:inline-block; height:35px;"></div>
    #|  <div style="display:inline-block; height:35px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("body should include two contain:inline-size children")
  }
  let first = layout.children[0]
  let second = layout.children[1]
  inspect(first.width, content="100")
  inspect(first.height, content="50")
  inspect(second.width, content="100")
  inspect(second.height, content="50")
}

///|
test "contain_inline_size_fit_content_keeps_inline_children_single_line" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|</style>
    #|<div id="outer" style="background:green; contain:inline-size; height:50px; width:fit-content; contain-intrinsic-inline-size:100px">
    #|  <div id="a" style="display:inline-block; width:75px;"></div>
    #|  <div id="b" style="display:inline-block; width:75px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let first_child = outer.children[0]
  let second_child = outer.children[1]
  inspect(outer.width, content="100")
  inspect(first_child.x, content="0")
  inspect(second_child.x, content="0")
  guard second_child.y <= 14.9 else {
    fail(
      "inline-size contained fit-content inline-block should not wrap to next line",
    )
  }
}

///|
test "contain_inline_size_vertical_rl_fit_content_ignores_child_inline_extent" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="writing-mode:vertical-rl; contain:inline-size; width:fit-content; border:solid green; border-width:50px 0; background:red;">
    #|  <div style="width:100px; height:100px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  inspect(outer.width, content="100")
  inspect(outer.height, content="100")
}

///|
test "contain_inline_size_fieldset_uses_ua_defaults_and_legend_overlay" {
  // Mirrors css-contain/contain-inline-size-fieldset.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|</style>
    #|<p>The fieldset below has inline-size containment.</p>
    #|<fieldset style="contain:inline-size; border:20px solid; width:fit-content;">
    #|  <legend><div style="width:200px; height:2px; background:blue;"></div></legend>
    #|  <div style="width:100px; height:100px; background:hotpink;"></div>
    #|</fieldset>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let fieldset = layout.children[1]
  let legend = fieldset.children[0]
  inspect(fieldset.width, content="64")
  inspect(legend.width, content="204")
  inspect(legend.y, content="9")
}

///|
test "contain_inline_size_legend_respects_fieldset_ua_defaults" {
  // Mirrors css-contain/contain-inline-size-legend.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|</style>
    #|<p>Legend containment</p>
    #|<fieldset style="width:fit-content; min-width:0;">
    #|  <legend style="contain:inline-size; border:solid blue; border-width:0 50px; padding:0; background:red;">
    #|    <div style="width:500px; height:100px;"></div>
    #|  </legend>
    #|  <div style="height:100px; background:yellow;"></div>
    #|</fieldset>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let fieldset = layout.children[1]
  let legend = fieldset.children[0]
  inspect(fieldset.width, content="124")
  inspect(legend.width, content="100")
}

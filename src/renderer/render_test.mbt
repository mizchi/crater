///|
test "intrinsic_percent_replaced_wpt_style" {
  // Mimics the WPT test intrinsic-percent-replaced-001.html
  // Canvas with height: 100% inside float with height: 100px
  // Should use aspect_ratio to derive width from height
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#float { float: left; height: 100px; }
    #|canvas { height: 100%; }
    #|</style>
    #|<div id=float><canvas width=10 height=10></canvas></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  // Verify node structure
  inspect(root.id, content="body")
  let float_div = root.children[0]
  inspect(float_div.id, content="div#float")
  let canvas = float_div.children[0]
  inspect(canvas.id, content="canvas")

  // Verify canvas style: height is %, width is Auto, aspect_ratio from intrinsic
  inspect(canvas.style.height, content="Percent(1)")
  inspect(canvas.style.width, content="Auto")
  inspect(canvas.style.aspect_ratio, content="Some(1)")

  // Compute layout
  @dispatch.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: None,
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)
  let float_layout = layout.children[0]
  let canvas_layout = float_layout.children[0]

  // Canvas should have width=100 (from aspect-ratio 1:1 with height=100)
  inspect(canvas_layout.width, content="100")
  inspect(canvas_layout.height, content="100")
  inspect(float_layout.width, content="100")
}

///|
test "img_intrinsic_src_keeps_auto_size_for_flex_aspect_ratio_constraints" {
  // Mirrors WPT flex-aspect-ratio-img-row-010.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="display: flex;">
    #|  <img
    #|    src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100' width='200'%3E%3Crect width='100%25' height='100%25' fill='green'/%3E%3C/svg%3E"
    #|    style="max-height: 100px; flex: 0 0 auto; background: red;"
    #|  >
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let target = root.children[0]
  let img = target.children[0]
  inspect(img.style.width, content="Auto")
  inspect(img.style.height, content="Auto")
  inspect(img.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, ctx)
  let target_layout = layout.children[0]
  let img_layout = target_layout.children[0]
  inspect(img_layout.width, content="100")
  inspect(img_layout.height, content="100")
}

///|
test "contain_size_object_auto_with_padding_uses_empty_intrinsic" {
  // Mirrors css-contain/contain-size-replaced-001.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|object {
    #|  padding: 50px;
    #|  contain: size;
    #|}
    #|</style>
    #|<object></object>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let object_layout = layout.children[0]
  inspect(object_layout.width, content="100")
  inspect(object_layout.height, content="100")
}

///|
test "contain_size_video_auto_size_collapses_to_border_box" {
  // Mirrors css-contain/contain-size-replaced-003a.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|video {
    #|  border: 3px solid teal;
    #|  contain: size;
    #|  width: auto;
    #|  height: auto;
    #|}
    #|</style>
    #|<video></video>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let video_layout = layout.children[0]
  inspect(video_layout.width, content="6")
  inspect(video_layout.height, content="6")
}

///|
test "contain_size_inline_block_img_uses_broken_alt_fallback_size" {
  // Mirrors css-contain/contain-size-021.html behavior under WPT runner setup
  // where non-data image URLs are unresolved and alt fallback metrics are used.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|#inline-block-blue-test {
    #|  background-color: blue;
    #|  contain: size;
    #|  display: inline-block;
    #|  padding: 50px;
    #|}
    #|</style>
    #|<div>
    #|  <div id="inline-block-blue-test"><img src="support/blue50wBy46h.png" alt="Image download support must be enabled"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let blue = outer.children[0]
  let img = blue.children[0]
  inspect(blue.width, content="100")
  inspect(blue.height, content="100")
  inspect(img.width, content="64")
  inspect(img.height, content="96")
}

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

///|
test "replaced_video_iframe_are_preserved_in_layout_tree" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="a"></div><video id="v"></video><iframe id="f"></iframe><img id="i" src="broken">
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())

  let mut has_video = false
  let mut has_iframe = false
  for child in layout.children {
    if child.id == "video#v" {
      has_video = true
    }
    if child.id == "iframe#f" {
      has_iframe = true
    }
  }

  guard has_video else {
    fail("video element should exist in body layout children")
  }
  guard has_iframe else {
    fail("iframe element should exist in body layout children")
  }
}

///|
test "contain_size_float_replaced_elements_are_not_dropped" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|body > div, video, audio, img, canvas, svg, iframe {
    #|  border: 3px solid orange;
    #|  contain: size;
    #|  margin-bottom: 15px;
    #|  width: min-content;
    #|  height: min-content;
    #|  float: left;
    #|  clear: both;
    #|}
    #|</style>
    #|<div id="d">abc</div>
    #|<video id="v"></video><br>
    #|<video id="v2" controls></video><br>
    #|<img id="i" src="broken"><br>
    #|<picture>
    #|<source srcset="support/60x60-green.png">
    #|  <img id="pi">
    #|</picture><br>
    #|<canvas id="c"></canvas><br>
    #|<svg id="s"></svg><br>
    #|<iframe id="f"></iframe>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let mut node_has_div = false
  let mut node_has_video = false
  let mut node_has_video2 = false
  let mut node_has_img = false
  let mut node_has_canvas = false
  let mut node_has_svg = false
  let mut node_has_iframe = false
  for child in root.children {
    if child.id == "div#d" {
      node_has_div = true
    } else if child.id == "video#v" {
      node_has_video = true
    } else if child.id == "video#v2" {
      node_has_video2 = true
    } else if child.id == "img#i" {
      node_has_img = true
    } else if child.id == "canvas#c" {
      node_has_canvas = true
    } else if child.id == "svg#s" {
      node_has_svg = true
    } else if child.id == "iframe#f" {
      node_has_iframe = true
    }
  }
  guard node_has_div else { fail("node tree should include float+contain div") }
  guard node_has_video else {
    fail("node tree should include float+contain video")
  }
  guard node_has_video2 else {
    fail("node tree should include float+contain second video")
  }
  guard node_has_img else { fail("node tree should include float+contain img") }
  guard node_has_canvas else {
    fail("node tree should include float+contain canvas")
  }
  guard node_has_svg else { fail("node tree should include float+contain svg") }
  guard node_has_iframe else {
    fail("node tree should include float+contain iframe")
  }

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())

  let mut has_div = false
  let mut has_video = false
  let mut has_video2 = false
  let mut has_img = false
  let mut has_canvas = false
  let mut has_svg = false
  let mut has_iframe = false
  for child in layout.children {
    if child.id == "div#d" {
      has_div = true
    } else if child.id == "video#v" {
      has_video = true
    } else if child.id == "video#v2" {
      has_video2 = true
    } else if child.id == "img#i" {
      has_img = true
    } else if child.id == "canvas#c" {
      has_canvas = true
    } else if child.id == "svg#s" {
      has_svg = true
    } else if child.id == "iframe#f" {
      has_iframe = true
    }
  }

  guard has_div else { fail("float+contain div should exist in body children") }
  guard has_video else {
    fail("float+contain video should exist in body children")
  }
  guard has_video2 else {
    fail("float+contain second video should exist in body children")
  }
  guard has_img else { fail("float+contain img should exist in body children") }
  guard has_canvas else {
    fail("float+contain canvas should exist in body children")
  }
  guard has_svg else { fail("float+contain svg should exist in body children") }
  guard has_iframe else {
    fail("float+contain iframe should exist in body children")
  }
}

///|
test "contain_size_replaced_004_fixture_keeps_first_div_layout_child" {
  let html_str =
    #|<!DOCTYPE html>
    #|<meta charset="utf-8">
    #|<title>CSS Containment Test: Size containment replaced elements intrinsic size</title>
    #|<link rel="help" href="https://drafts.csswg.org/css-contain-1/#containment-size">
    #|<link rel="match" href="contain-size-replaced-004-ref.html">
    #|<meta name=assert content="This test checks that intrinsic size of replaced elements with 'contain: size' is zero.">
    #|<style>
    #|  body > div, video, audio, img, canvas, svg, iframe {
    #|    border: 3px solid orange;
    #|    contain: size;
    #|    margin-bottom: 15px;
    #|    width: min-content;
    #|    height: min-content;
    #|    float: left;
    #|    clear: both;
    #|  }
    #|</style>
    #|<div>abc</div>
    #|<video></video><br>
    #|<video controls></video><br>
    #|<img src="support/60x60-green.png"><br>
    #|<picture>
    #|<source srcset="support/60x60-green.png">
    #|    <img>
    #|</picture><br>
    #|<canvas></canvas><br>
    #|<svg></svg><br>
    #|<iframe></iframe>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() > 0 else {
    fail("body should contain rendered children")
  }
  guard layout.children[0].id == "div" else {
    fail("first body child should be floated div for contain-size-replaced-004")
  }
}

///|
test "contain_size_picture_uses_img_outer_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|img {
    #|  border: 3px solid teal;
    #|  contain: size;
    #|  margin: 15px;
    #|  width: auto;
    #|  height: auto;
    #|}
    #|</style>
    #|<picture><source srcset="support/blue-100x100.png"><img></picture>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(root.children[0].style.display, content="Inline")
  inspect(root.children[0].children.length(), content="2")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let picture = layout.children[0]
  guard picture.width >= 36.0 else {
    fail("picture width should include img border+margin contribution")
  }
}

///|
test "contain_size_empty_embed_is_zero_sized" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|embed {
    #|  border: 3px solid teal;
    #|  contain: size;
    #|  margin: 15px;
    #|  width: auto;
    #|  height: auto;
    #|}
    #|</style>
    #|<embed><embed src="support/blue-100x100.png">
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("body should contain two embed entries")
  }
  guard layout.children[0].width == 0.0 else {
    fail("embed without src should be zero-sized")
  }
  guard layout.children[0].height == 0.0 else {
    fail("embed without src should be zero-sized")
  }
  guard layout.children[1].width == 6.0 else {
    fail("embed with src should keep border-box size under contain:size")
  }
}

///|
test "contain_size_non_atomic_inline_span_is_preserved" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { overflow: hidden; }
    #|span { contain: size; }
    #|</style>
    #|<div><span>PASS</span></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[0]
  guard div.children.length() > 0 else {
    fail("div should keep span child under contain:size")
  }
  guard div.children[0].id == "span" else {
    fail("span with contain:size should not be flattened to text")
  }
}

///|
test "contain_layout_inline_sibling_with_id_is_preserved" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#pa { contain: layout; }
    #|#ss { vertical-align: bottom; }
    #|</style>
    #|<div><span id="pa">PA</span><span id="ss">SS</span></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[0]
  inspect(div.children.length(), content="2")
  inspect(div.children[0].id, content="span#pa")
  inspect(div.children[1].id, content="span#ss")
}

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
test "contain_paint_clip_abs_descendants_keep_outer_padding_box_reference" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|.root {
    #|  contain: paint;
    #|  width: 100px;
    #|  height: 100px;
    #|  margin: 25px;
    #|  padding: 25px;
    #|}
    #|.a { width: 100px; height: 200px; }
    #|.background {
    #|  position: absolute;
    #|  top: 0;
    #|  left: 0;
    #|  width: 200px;
    #|  height: 200px;
    #|}
    #|.foreground {
    #|  position: absolute;
    #|  top: -25px;
    #|  left: -25px;
    #|  width: 150px;
    #|  height: 150px;
    #|  border: 25px solid red;
    #|}
    #|</style>
    #|<div class="root">
    #|  <div class="a">
    #|    <div class="background"></div>
    #|    <div class="foreground"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else {
    fail("body should keep contain:paint root")
  }
  let root = layout.children[0]
  guard root.children.length() == 1 else { fail("root should keep flow child") }
  let flow_child = root.children[0]
  guard flow_child.children.length() == 2 else {
    fail("flow child should keep absolute descendants")
  }
  let background = flow_child.children[0]
  let foreground = flow_child.children[1]
  guard background.x == -25.0 && background.y == -25.0 else {
    fail(
      "absolute child with top/left:0 should stay anchored to contain:paint padding box",
    )
  }
  guard foreground.x == -50.0 && foreground.y == -50.0 else {
    fail(
      "offset absolute child should preserve containing block offset through static wrapper",
    )
  }
}

///|
test "contain_paint_inline_block_after_text_wrap_keeps_inline_offset_large_font" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#outer {
    #|  font-family: monospace;
    #|  font-size: 100px;
    #|  line-height: 1;
    #|  width: 2em;
    #|  height: 2em;
    #|}
    #|#containing-block {
    #|  contain: paint;
    #|  display: inline-block;
    #|  width: 1em;
    #|  height: 1em;
    #|}
    #|#abspos {
    #|  position: absolute;
    #|  left: 0;
    #|  top: 0;
    #|  width: 1em;
    #|  height: 1em;
    #|}
    #|</style>
    #|<div id="outer">AB C<div id="containing-block"><div id="abspos"></div></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else {
    fail("body should keep outer block")
  }
  let outer = layout.children[0]
  guard outer.children.length() >= 2 else {
    fail("outer should keep text and inline containing block")
  }
  let containing_block = outer.children[1]
  guard containing_block.x > 0.0 else {
    fail(
      "inline containing block should keep carry-over inline offset on wrapped line",
    )
  }
  guard containing_block.children.length() == 1 else {
    fail("containing block should keep absolute child")
  }
  let abspos = containing_block.children[0]
  guard abspos.x == 0.0 else {
    fail("absolute child should stay at left edge of containing block")
  }
}

///|
test "contain_paint_inline_block_after_text_wrap_keeps_inline_offset_small_font" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#outer {
    #|  font-family: monospace;
    #|  font-size: 50px;
    #|  line-height: 1;
    #|  width: 2em;
    #|  height: 2em;
    #|}
    #|#containing-block {
    #|  contain: paint;
    #|  display: inline-block;
    #|  width: 50%;
    #|  height: 50%;
    #|}
    #|#abspos {
    #|  position: absolute;
    #|  left: 0;
    #|  top: 0;
    #|  width: 50px;
    #|  height: 50px;
    #|}
    #|</style>
    #|<div id="outer">AB C<div id="containing-block"><div id="abspos"></div></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else {
    fail("body should keep outer block")
  }
  let outer = layout.children[0]
  guard outer.children.length() >= 2 else {
    fail("outer should keep text and inline containing block")
  }
  let containing_block = outer.children[1]
  guard containing_block.x > 0.0 else {
    fail(
      "inline containing block should keep carry-over inline offset on wrapped line",
    )
  }
  guard containing_block.children.length() == 1 else {
    fail("containing block should keep absolute child")
  }
  let abspos = containing_block.children[0]
  guard abspos.x == 0.0 else {
    fail("absolute child should stay at left edge of containing block")
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
test "rt_ua_default_font_size_is_half_of_parent" {
  let html_str =
    #|<!DOCTYPE html>
    #|<ruby><rt>FAIL</rt></ruby>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let ruby = root.children[0]
  let rt = ruby.children[0]
  inspect(ruby.style.font_size, content="16")
  inspect(rt.style.font_size, content="8")
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
test "whitespace_between_css_inline_blocks_is_preserved" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-size: 16px; line-height: 1; }
    #|.inline-block { display: inline-block; width: 10px; height: 10px; }
    #|</style>
    #|<div>
    #|  <div class="inline-block"></div>
    #|  <div class="inline-block"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let wrapper = layout.children[0]
  let inline_blocks : Array[@types.Layout] = []
  for child in wrapper.children {
    if not(child.id.has_prefix("#text")) {
      inline_blocks.push(child)
    }
  }
  guard inline_blocks.length() == 2 else {
    fail("wrapper should have two inline-block children")
  }
  let first = inline_blocks[0]
  let second = inline_blocks[1]
  guard first.x == 0.0 else { fail("first inline-block should start at x=0") }
  guard second.x == 18.0 else {
    fail(
      "collapsed inter-element space should create 8px gap at 16px font size",
    )
  }
}

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
test "contain_size_ruby_base_is_preserved" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { overflow: hidden; position: absolute; }
    #|rb { contain: size; display: ruby-base; }
    #|</style>
    #|<div><ruby><rb>PASS</rb></ruby></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let div_node = root.children[0]
  guard div_node.children.length() > 0 else {
    fail("node div should contain ruby child")
  }
  guard div_node.children[0].id == "ruby" else {
    fail("node div child should be ruby")
  }
  guard div_node.children[0].children.length() > 0 else {
    fail("node ruby should contain rb child")
  }
  inspect(div_node.children[0].children[0].style.display, content="Inline")
  inspect(div_node.children[0].children[0].children.length(), content="1")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[0]
  guard div.children.length() > 0 else { fail("div should contain ruby") }
  let ruby = div.children[0]
  guard ruby.children.length() > 0 else { fail("ruby should contain rb") }
  guard ruby.children[0].id == "rb" else {
    fail("rb with contain:size should be preserved")
  }
  guard ruby.children[0].width > 0.0 else {
    fail("rb with contain:size should still keep intrinsic text width")
  }
}

///|
test "contain_size_ruby_base_container_is_preserved" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { overflow: hidden; position: absolute; }
    #|rbc { contain: size; display: ruby-base-container; }
    #|</style>
    #|<div><ruby><rbc>PASS</rbc></ruby></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let div_node = root.children[0]
  guard div_node.children.length() > 0 else {
    fail("node div should contain ruby child")
  }
  let ruby_node = div_node.children[0]
  inspect(ruby_node.id, content="ruby")
  inspect(ruby_node.style.display, content="Inline")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[0]
  guard div.children.length() > 0 else { fail("div should contain ruby") }
  let ruby = div.children[0]
  guard ruby.children.length() > 0 else { fail("ruby should contain rbc") }
  guard ruby.children[0].id == "rbc" else {
    fail("rbc with contain:size should be preserved")
  }
  guard ruby.children[0].width > 0.0 else {
    fail("rbc with contain:size should still keep intrinsic text width")
  }
}

///|
test "empty_ruby_with_rt_has_non_zero_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|rt { contain: layout; display: ruby-text; font: 100px/1 monospace; }
    #|</style>
    #|<div><ruby><rt></rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let ruby = layout.children[0].children[0]
  guard ruby.height > 0.0 else {
    fail("ruby with rt child should reserve strut-like height")
  }
}

///|
test "contain_size_img_attr_ratio_keeps_auto_height" {
  // Mirrors css-contain/contain-size-replaced-007.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<img width="60" height="60" style="width: 100px; height: auto; contain: size;">
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let img_node = root.children[0]
  inspect(img_node.style.width, content="Length(100)")
  inspect(img_node.style.height, content="Auto")
  inspect(img_node.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let img_layout = layout.children[0]
  inspect(img_layout.width, content="100")
  inspect(img_layout.height, content="100")
}

///|
test "parse_aspect_ratio_transferred_max_size_style" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; width: 100px;">
    #|  <div style="aspect-ratio: 1/2; max-height: 100px; flex: 1; background: green;"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let flex = root.children[0]
  let item = flex.children[0]
  inspect(item.style.aspect_ratio, content="Some(0.5)")
  inspect(item.style.max_height, content="Length(100)")
  inspect(item.style.flex_grow, content="1")
  inspect(item.style.flex_shrink, content="1")
  inspect(item.style.flex_basis, content="Percent(0)")

  let layout = @renderer.render(html_str, ctx)
  let flex_layout = layout.children[0]
  let item_layout = flex_layout.children[0]
  inspect(flex_layout.height, content="100")
  inspect(item_layout.height, content="100")
}

///|
test "wpt_aspect_ratio_intrinsic_size_005_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="height: 50px; width: min-content; background: green;">
    #|  <div style="display: flex; height: 100%; background: green;">
    #|    <div style="aspect-ratio: 1/1;"></div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let target = root.children[0]
  let flex = target.children[0]
  let ratio_item = flex.children[0]
  inspect(target.style.width, content="MinContent")
  inspect(target.style.height, content="Length(50)")
  inspect(flex.style.display, content="Flex")
  inspect(flex.style.height, content="Percent(1)")
  inspect(ratio_item.style.aspect_ratio, content="Some(1)")

  @dispatch.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)
  let target_layout = layout.children[0]
  let flex_layout = target_layout.children[0]
  let ratio_layout = flex_layout.children[0]
  inspect(target_layout.width, content="50")
  inspect(target_layout.height, content="50")
  inspect(flex_layout.width, content="50")
  inspect(flex_layout.height, content="50")
  inspect(ratio_layout.width, content="50")
  inspect(ratio_layout.height, content="50")
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
  let f = section.children[3]
  guard bp.x > f.x else {
    fail("vertical-rl wrap should progress lines from right to left")
  }
}

///|
test "svg_default_intrinsic_size_wpt_like" {
  // Mirrors WPT-like behavior: <svg> without width/height defaults to 300x150.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<svg id="target"></svg>

  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  @dispatch.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)

  let svg = layout.children[0]

  inspect(svg.id, content="svg#target")
  inspect(svg.width, content="300")
  inspect(svg.height, content="150")
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
  inspect(input.width, content="215")
  inspect(textarea.width, content="142")
  inspect(textarea.height, content="69")
}

///|
test "wpt_contain_layout_button_002_border_box_min_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|button {
    #|  border: 5px solid green;
    #|  padding: 10px;
    #|  color: transparent;
    #|  width: 20px;
    #|  height: 20px;
    #|}
    #|</style>
    #|<button id="a"></button><button id="b" style="contain: layout"></button>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let button_a = layout.children[0]
  let button_b = layout.children[1]
  inspect(button_a.width, content="30")
  inspect(button_a.height, content="30")
  inspect(button_b.width, content="30")
  inspect(button_b.height, content="30")
}

///|
test "wpt_contain_layout_ifc_002_inline_block_keeps_vertical_margins" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|.wrapper { border: solid thick; margin: 1em; }
    #|</style>
    #|<p>Test passes if it has the same output than the reference.</p>
    #|<div class="wrapper">
    #|  <span style="display: inline-block; margin: 1em 0; vertical-align: top; contain: layout;">
    #|    <div style="margin: 1em 0;">This text should have 2em top and bottom margins (margins do not collapse).</div>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let wrapper = layout.children[1]
  let span = wrapper.children[0]
  let inner = span.children[0]
  inspect(wrapper.height, content="93.2")
  inspect(span.y, content="21")
  inspect(span.height, content="51.2")
  inspect(inner.y, content="16")
}

///|
test "wpt_contain_layout_ifc_003_inline_ignores_layout_containment" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|.wrapper { border: solid thick; margin: 1em; }
    #|</style>
    #|<p>Test passes if it has the same output than the reference.</p>
    #|<div class="wrapper">
    #|  <span style="margin: 1em 0; contain: layout;">
    #|    <div style="margin: 1em 0;">This text should have 1em top and bottom margins.</div>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let wrapper = layout.children[1]
  let span = wrapper.children[0]
  let inner = span.children[0]
  inspect(wrapper.height, content="61.2")
  inspect(span.y, content="21")
  inspect(span.height, content="19.2")
  inspect(inner.y, content="0")
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
test "inline_anchor_height_in_block_with_fixed_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#test { display: flex; }
    #|#test div { align-self: baseline; }
    #|#div1 { height: 90px; font-size: 20px; width: 30px; }
    #|</style>
    #|<div id="test">
    #|  <div id="div1"><a href="#">aaa</a></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let div1 = layout.children[0].children[0]
  let anchor = div1.children[0]
  inspect(div1.height, content="90")
  inspect(anchor.height, content="20")
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
test "renderer_grid_column" {
  let html_str = "<!DOCTYPE html><div id=\"mygrid\" style=\"display: grid; grid-template-columns: 1fr 30px; width: min-content; border: 10px solid;\"><div id=\"item\" style=\"grid-column: 1 / span 2;\"><div id=\"filler\" style=\"width: 300px; height: 50px;\"></div></div></div>"
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  // root is body, root.children[0] is mygrid
  inspect(root.id, content="body")
  let mygrid = root.children[0]
  inspect(mygrid.id, content="div#mygrid")

  // The item is mygrid.children[0]
  let item = mygrid.children[0]
  inspect(item.id, content="div#item")
  inspect(item.style.grid_column.start, content="Line(1)")
  inspect(item.style.grid_column.end, content="Span(2)")

  // Now compute layout
  @dispatch.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)

  // body -> mygrid -> item
  let mygrid_layout = layout.children[0]
  inspect(mygrid_layout.children[0].width, content="30")
}

///|
test "orthogonal_child_within_flex_grid_wpt_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="display: flex; width: 100px; overflow: hidden;">
    #|  <div style="display: grid; height: 100px;">
    #|    <div style="writing-mode: vertical-rl; line-height: 0;">
    #|      <span style="display: inline-block; width: 50px; height: 100px;"></span>
    #|      <span style="display: inline-block; width: 50px; height: 100px;"></span>
    #|    </div>
    #|  </div>
    #|  <div>text</div>
    #|</div>

  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let flex = root.children[0]
  let grid = flex.children[0]
  let ortho = grid.children[0]
  inspect(ortho.style.writing_mode, content="VerticalRl")

  @dispatch.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @dispatch.compute_layout(root, layout_ctx)
  let flex_layout = layout.children[0]
  let grid_layout = flex_layout.children[0]
  let ortho_layout = grid_layout.children[0]
  inspect(grid_layout.width, content="100")
  inspect(ortho_layout.width, content="100")
  inspect(ortho_layout.children[0].x, content="50")
  inspect(ortho_layout.children[1].x, content="0")
}

///|
test "inline_filter_preserves_abspos_descendant_wpt_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { filter: brightness(100%); }
    #|#abs { position: absolute; top: 0; left: 0; width: 10px; height: 10px; }
    #|</style>
    #|<div><span id="cb">text<span id="abs"></span></span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  let container = root.children[0]
  inspect(container.id, content="div")
  let cb = container.children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.children.length(), content="2")
  let abs = cb.children[1]
  inspect(abs.id, content="span#abs")
  inspect(abs.style.position, content="Absolute")
}

///|
test "inline_span_with_out_of_flow_block_child_stays_inline_wpt_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { position: relative; width: 100px; height: 100px; }
    #|#inline { contain: paint; }
    #|#abs { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
    #|#fixed { position: fixed; top: 0; left: 0; width: 100%; height: 100%; }
    #|</style>
    #|<div id="cb"><span id="inline"><div id="abs"></div><div id="fixed"></div></span></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let cb = layout.children[0]
  let inline = cb.children[0]
  inspect(inline.id, content="span#inline")
  inspect(inline.width, content="0")
  inspect(inline.height, content="0")
  let abs = inline.children[0]
  inspect(abs.id, content="div#abs")
  inspect(abs.x, content="0")
  inspect(abs.y, content="0")
}

///|
test "inline_span_with_background_from_stylesheet_is_preserved" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|div { font-family: monospace; font-size: 100px; width: 4ch; }
    #|span { background-color: red; color: yellow; }
    #|</style>
    #|<div>PASS<span>FAIL</span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let container = root.children[0]
  inspect(container.id, content="div")
  inspect(container.children.length(), content="2")
  inspect(container.children[0].id, content="#text")
  inspect(container.children[1].id, content="span")
}

///|
test "inline_text_and_span_without_space_stay_on_same_line" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { font-family: monospace; font-size: 100px; width: 4ch; contain: paint; }
    #|span { background-color: red; color: yellow; }
    #|</style>
    #|<div>PASS<span>FAIL</span></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let container = layout.children[0]
  let text = container.children[0]
  let span = container.children[1]
  inspect(container.height, content="100")
  inspect(text.y, content="0")
  inspect(span.x, content="200")
  inspect(span.y, content="0")
}

///|
test "inline_span_uses_tighter_glyph_box_under_larger_line_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|div { color: green; contain: paint; font-family: monospace; font-size: 100px; width: 4ch; }
    #|span { background-color: red; color: yellow; }
    #|</style>
    #|<div>PASS<span>FAIL</span></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let span = container.children[1]
  guard container.height >= 120.0 else {
    fail("contain:paint line box should remain at least one full line-height")
  }
  inspect(span.height, content="104.5")
  inspect(span.x, content="200")
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
  guard target_cell.height <= 110.0 else {
    fail("table cell height should stay close to normal line-height metrics")
  }
  inspect(span.height, content="104.5")
  inspect(span.y, content="0")
}

///|
test "fixed_child_in_abspos_parent_uses_viewport_reference" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#parent {
    #|  position: absolute;
    #|  top: 100px;
    #|  left: 100px;
    #|}
    #|#fixed {
    #|  position: fixed;
    #|  top: 50px;
    #|  left: 50px;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div id="parent"><div id="fixed"></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let parent = layout.children[0]
  let fixed = parent.children[0]

  // Fixed element should be positioned from viewport, so relative to parent it is negative.
  inspect(fixed.x, content="-50")
  inspect(fixed.y, content="-50")
}

///|
test "backdrop_filter_establishes_fixed_containing_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#container {
    #|  width: 200px;
    #|  backdrop-filter: invert(1);
    #|}
    #|#fixed {
    #|  position: fixed;
    #|  top: 0;
    #|  width: 100%;
    #|  height: 200px;
    #|}
    #|</style>
    #|<div id="container"><div id="fixed"></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let container = layout.children[0]
  let fixed = container.children[0]

  inspect(container.width, content="200")
  inspect(fixed.width, content="200")
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
test "wpt_grid_container_as_flex_item_reflows_to_final_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.inner-grid {
    #|  display: grid;
    #|  flex: 1 1 0%;
    #|  width: 100%;
    #|}
    #|.inner-grid-item {
    #|  font: 50px/1 Ahem;
    #|  min-width: 0;
    #|  width: 100%;
    #|}
    #|</style>
    #|<div style="display: grid">
    #|  <div style="display: flex; flex-direction: column; width: 100px">
    #|    <div class="inner-grid">
    #|      <div class="inner-grid-item">XX XX</div>
    #|    </div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let root_grid = layout.children[0]
  let outer_flex = root_grid.children[0]
  let inner_grid = outer_flex.children[0]
  let inner_item = inner_grid.children[0]

  inspect(root_grid.height, content="100")
  inspect(outer_flex.height, content="100")
  inspect(inner_grid.height, content="100")
  inspect(inner_item.height, content="100")
}

///|
test "wpt_grid_child_percent_basis_resize_uses_definite_track_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body {
    #|  margin: 0;
    #|  font-family: monospace;
    #|  font-size: 16px;
    #|  line-height: 1.2;
    #|}
    #|.grid-container {
    #|  display: grid;
    #|  width: 100px;
    #|}
    #|.scroll-outer {
    #|  overflow: hidden;
    #|  height: 100%;
    #|  max-height: 100px;
    #|}
    #|.scroll-inner {
    #|  overflow: scroll;
    #|  height: 100%;
    #|}
    #|</style>
    #|<div class="grid-container">
    #|  <div class="grid-item">
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
  let ctx = @renderer.RenderContext::default()
  let node_tree = @renderer.render_to_node(html_str, ctx)
  let node_grid = node_tree.children[0]
  let node_grid_item = node_grid.children[0]
  let node_scroll_outer = node_grid_item.children[0]
  let node_scroll_inner = node_scroll_outer.children[0]
  inspect(node_scroll_outer.style.max_height, content="Length(100)")
  inspect(node_scroll_inner.style.height, content="Percent(1)")
  inspect(node_scroll_inner.children[0].style.height, content="Auto")

  let layout = @renderer.render(html_str, ctx)
  let grid = layout.children[0]
  let grid_item = grid.children[0]
  let scroll_outer = grid_item.children[0]
  let scroll_inner = scroll_outer.children[0]
  let first_line = scroll_inner.children[0]
  let second_line = scroll_inner.children[1]

  inspect(first_line.height, content="19.2")
  inspect(second_line.y, content="19.2")
  inspect(grid.height, content="100")
  inspect(grid_item.height, content="100")
  inspect(scroll_outer.height, content="100")
  inspect(scroll_inner.height, content="100")
}

///|
test "wpt_grid_item_percentage_quirk_canvas_behaves_like_browser" {
  let html_str =
    #|<!-- quirks mode -->
    #|<div style="width: 100px; height: 100px; overflow: hidden; background: green;">
    #|  <div style="display: grid; position: relative; left: -20px;">
    #|    <canvas width=10 height=10 style="height: 200%; background: red;"></canvas>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let outer = layout.children[0]
  let grid = outer.children[0]
  let canvas = grid.children[0]

  inspect(grid.height, content="10")
  inspect(canvas.width, content="20")
  inspect(canvas.height, content="20")
}

///|
test "wpt_grid_item_percentage_quirk_non_replaced_stays_auto" {
  let html_str =
    #|<!-- quirks mode -->
    #|<div style="width: 100px; height: 100px; overflow: hidden; background: green;">
    #|  <div style="display: grid; position: relative; left: -20px;">
    #|    <div width=10 height=10 style="height: 200%; width: 200px; background: red;"></div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let outer = layout.children[0]
  let grid = outer.children[0]
  let child = grid.children[0]

  inspect(grid.height, content="0")
  inspect(child.width, content="200")
  inspect(child.height, content="0")
}

///|
test "wpt_grid_align_start_item_uses_content_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.grid {
    #|  display: grid;
    #|  grid-template-columns: 100%;
    #|  grid-template-rows: 50px;
    #|  height: 50px;
    #|  font: 10px/1 Ahem;
    #|}
    #|.alignStart {
    #|  align-items: start;
    #|}
    #|</style>
    #|<div class="grid alignStart">
    #|  <div class="test">x x x x</div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let grid = layout.children[0]
  let item = grid.children[0]

  inspect(grid.height, content="50")
  inspect(item.height, content="10")
}

///|
test "wpt_grid_flex_item_vertical_lr_auto_row_keeps_zero_block_size" {
  let html_str =
    #|<!doctype html><div id="flex" style="display:flex;flex-direction:column;width:100px;height:100px;"><div id="grid" style="display:grid;grid-template-rows:auto;writing-mode:vertical-lr;"><div id="leaf"></div></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let flex = layout.children[0]
  let grid = flex.children[0]
  let leaf = grid.children[0]

  inspect(grid.width, content="100")
  inspect(grid.height, content="0")
  inspect(leaf.width, content="100")
  inspect(leaf.height, content="0")
}

///|
test "wpt_grid_flex_item_column_percent_basis_indefinite_height_uses_content" {
  let html_str =
    #|<!doctype html><div id="target"><div id="flex" style="display:flex;flex-direction:column"><div id="grid" style="display:grid;height:0;flex:1;grid-template-rows:minmax(100px,200%);"><div id="leaf"></div></div></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let target = layout.children[0]
  let flex = target.children[0]
  let grid = flex.children[0]
  let leaf = grid.children[0]

  inspect(target.height, content="100")
  inspect(flex.height, content="100")
  inspect(grid.height, content="100")
  inspect(leaf.height, content="100")
}

///|
test "body_explicit_height_is_not_forced_to_viewport" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; height: 200px; }
    #|</style>
    #|<div style="height: 20px;"></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.id, content="body")
  inspect(layout.height, content="200")
}

///|
test "body_overflow_scroll_is_not_forced_to_viewport" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; overflow: scroll; }
    #|</style>
    #|body text
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.id, content="body")
  inspect(layout.height, content="16")
}

///|
test "body_auto_height_follows_content_not_viewport" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="height: 20px;"></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.id, content="body")
  inspect(layout.height, content="20")
}

///|
test "body_collapsed_top_margin_does_not_expand_body_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { margin-top: 10px; height: 50px; }
    #|</style>
    #|<div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let child = layout.children[0]

  inspect(layout.id, content="body")
  inspect(layout.height, content="50")
  inspect(child.y, content="0")
}

///|
test "intrinsic_percent_replaced_nested_wrapper_quirks_like" {
  let html_str =
    #|<!-- quirks mode -->
    #|<style>
    #|#float { float: left; height: 100px; background: green; }
    #|canvas { height: 100%; }
    #|</style>
    #|<p style="margin-top: 1em;">Test passes if there is a filled green square.</p>
    #|<div id=float>
    #|  <div>
    #|    <canvas width=10 height=10></canvas>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let float_div = layout.children[1]
  let inner = float_div.children[0]
  let canvas = inner.children[0]

  inspect(float_div.width, content="100")
  inspect(inner.width, content="100")
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
}

///|
test "intrinsic_percent_replaced_004_like_flex_parent_percent_height_chain" {
  let html_str =
    #|<!-- quirks mode -->
    #|<style>
    #|#container { display: flex; height: 200px; }
    #|#float { float: left; height: 50%; background: green; }
    #|canvas { height: 100%; }
    #|</style>
    #|<p style="margin-top: 1em;">Test passes if there is a filled green square.</p>
    #|<div id=container>
    #|  <div id=float>
    #|    <div>
    #|      <canvas width=10 height=10></canvas>
    #|    </div>
    #|  </div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let container = layout.children[1]
  let float_div = container.children[0]
  let inner = float_div.children[0]
  let canvas = inner.children[0]

  inspect(float_div.width, content="100")
  inspect(float_div.height, content="100")
  inspect(inner.width, content="100")
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
}

///|
test "intrinsic_ratio_replaced_box_sizing_like_first_case" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|img {
    #|  margin: 5px;
    #|  border: 10px solid grey;
    #|}
    #|div {
    #|  display: inline-block;
    #|  margin: 10px;
    #|  border: 1px solid black;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div>
    #|  <img src="data:image/svg+xml;charset=UTF-8,<svg viewBox='0 0 100 100' xmlns='http://www.w3.org/2000/svg'><rect width='100%' height='100%' fill='lime'/></svg>">
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let img = outer.children[0]

  inspect(outer.width, content="102")
  inspect(outer.height, content="102")
  inspect(img.width, content="90")
  inspect(img.height, content="90")
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
  inspect(item.style.aspect_ratio, content="Some(1)")
  inspect(item.style.box_sizing, content="BorderBox")
}

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
test "wpt_intrinsic_percent_replaced_dynamic_010_static_layout" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|p { margin: 0; }
    #|</style>
    #|<p>Test passes if there is a filled green square.</p>
    #|<div id="target" style="float: left; background: green; color: transparent;">
    #|  <span>
    #|    <div style="float: left; height: 100%;">
    #|      <canvas width="1" height="1" style="height: 100%;"></canvas>
    #|    </div>
    #|  </span>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let target = layout.children[1]
  let span = target.children[0]
  let float_div = span.children[0]
  let canvas = float_div.children[0]

  inspect(target.width, content="600")
  inspect(target.height, content="600")
  inspect(span.x, content="600")
  inspect(span.width, content="0")
  inspect(float_div.x, content="-600")
  inspect(float_div.width, content="600")
  inspect(float_div.height, content="600")
  inspect(canvas.width, content="600")
  inspect(canvas.height, content="600")
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

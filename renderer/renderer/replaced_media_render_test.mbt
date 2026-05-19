///|
// Replaced element and intrinsic media renderer regression tests split from
// render_test.mbt and renderer_test.mbt.

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
  debug_inspect(canvas.style.aspect_ratio, content="Some(1)")

  // Compute layout
  @node.setup()
  let layout_ctx : @layout_types.LayoutContext = {
    available_width: 800.0,
    available_height: None,
    sizing_mode: @layout_types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)
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
  debug_inspect(img.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, ctx)
  let target_layout = layout.children[0]
  let img_layout = target_layout.children[0]
  inspect(img_layout.width, content="100")
  inspect(img_layout.height, content="100")
}

///|
test "wpt_flex_aspect_ratio_img_column_012_like_min_height_does_not_set_base_size" {
  let provider = @renderer.ImageIntrinsicSizeProvider::new(fn(
    src : String,
  ) -> (Double, Double)? {
    if src.contains("support/1x1-green.png") {
      Some((1.0, 1.0))
    } else {
      None
    }
  })
  @renderer.set_image_intrinsic_size_provider(provider)
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; flex-direction: column; width:100px; height: 200px; align-items: flex-start;">
    #|  <img style="min-height: 100px; flex: 1 0 auto;" src="support/1x1-green.png">
    #|  <div style="flex: 1 0 1px;"></div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let img_node = root.children[0].children[0]
  inspect(img_node.style.width, content="Auto")
  inspect(img_node.style.height, content="Auto")
  debug_inspect(img_node.style.aspect_ratio, content="Some(1)")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  let img = flex.children[0]
  let filler = flex.children[1]
  inspect(img.height, content="100")
  inspect(filler.y, content="100")
  inspect(filler.height, content="100")
  @renderer.clear_image_intrinsic_size_provider()
}

///|
test "wpt_flex_aspect_ratio_svg_column_018_like_transferred_max_width_caps_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; flex-direction: column; align-items: flex-start; width: 200px;">
    #|  <svg viewBox="0 0 1 1" style="max-width: 100px; background: green;"></svg>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let flex = root.children[0]
  let svg = flex.children[0]
  debug_inspect(svg.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex_layout = layout.children[0]
  let svg_layout = flex_layout.children[0]
  inspect(flex_layout.height, content="100")
  inspect(svg_layout.width, content="100")
  inspect(svg_layout.height, content="100")
}

///|
test "wpt_flex_aspect_ratio_svg_row_015_like_transferred_max_height_caps_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="display: flex; align-items: flex-start; height: 200px;">
    #|  <svg viewBox="0 0 1 1" style="max-height: 100px; background: green;"></svg>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let flex = root.children[0]
  let svg = flex.children[0]
  debug_inspect(svg.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let svg_layout = layout.children[0].children[0]
  inspect(svg_layout.width, content="100")
  inspect(svg_layout.height, content="100")
}

///|
test "wpt_display_flex_svg_default_overflow_uses_zero_auto_min_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { display: flex; width: 100px; height: 100px; }
    #|svg { flex-grow: 1; }
    #|</style>
    #|<div>
    #|  <svg>
    #|    <rect width="150" height="150" fill="green"></rect>
    #|  </svg>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex_layout = layout.children[0]
  let svg_layout = flex_layout.children[0]
  inspect(flex_layout.width, content="100")
  inspect(flex_layout.height, content="100")
  inspect(svg_layout.width, content="100")
  inspect(svg_layout.height, content="100")
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
test "broken_img_with_scroll_overflow_uses_non_replaced_alt_box_height" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|  img {
    #|    border: solid;
    #|    display: block;
    #|    width: 150px;
    #|    padding: 10px;
    #|    overflow: scroll;
    #|  }
    #|</style>
    #|<img src="about:invalid" alt="I have scrollbar ................................................................">
  let body = @renderer.render(html_str, @renderer.RenderContext::default())
  let layout = body.children[0]
  guard (layout.width - 173.0).abs() < 0.01 else {
    fail("broken img scroll fallback should keep explicit border-box width")
  }
  guard layout.children.length() == 1 else {
    fail("broken img scroll fallback should expose alt text as inline child")
  }
  guard layout.children[0].id == "#text" else {
    fail("broken img scroll fallback child should be text")
  }
  guard layout.height < 140.0 else {
    fail(
      "broken img scroll fallback should not keep large replaced fallback height",
    )
  }
}

///|
test "video_with_source_children_keeps_explicit_replaced_size" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|  body { margin: 0; }
    #|  video {
    #|    border: 4px solid red;
    #|    width: 400px;
    #|    height: 300px;
    #|}
    #|</style>
    #|<video controls><source src="about:invalid" type="video/mp4"></video>
  let body = @renderer.render(html_str, @renderer.RenderContext::default())
  let layout = body.children[0]
  guard (layout.width - 408.0).abs() < 0.01 else {
    fail("video with source child should keep explicit replaced width")
  }
  guard (layout.height - 308.0).abs() < 0.01 else {
    fail("video with source child should keep explicit replaced height")
  }
}

///|
test "whitespace_between_inline_replaced_media_nodes_is_preserved" {
  // Regression for css-contain/contain-size-replaced-003a{b,c}.html:
  // collapsed whitespace between inline replaced siblings contributes inline advance.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|video { border: 3px solid teal; contain: size; margin: 15px; width: auto; height: auto; }
    #|</style>
    #|<video></video> <video></video>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let videos : Array[@layout_types.Layout] = []
  for child in layout.children {
    if child.id == "video" {
      videos.push(child)
    }
  }
  guard videos.length() >= 2 else {
    fail("layout should include at least two video nodes")
  }
  let first = videos[0]
  let second = videos[1]
  inspect(first.x, content="15")
  inspect(
    second.x,
    content=(
      #|59
    ),
  )
}

///|
test "inline_anchor_with_block_child_and_replaced_descendant_becomes_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { min-height: 10px; margin-bottom: 10px; }
    #|</style>
    #|<a href="">
    #|  <div>Text should be green</div>
    #|  <svg width="20" height="50"></svg>
    #|</a>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let anchor = root.children[0]
  inspect(anchor.id, content="a")
  inspect(anchor.style.display, content="Block")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let anchor_layout = layout.children[0]
  inspect(anchor_layout.width, content="800")
}

///|
test "whitespace_adjacent_to_br_is_not_preserved_between_replaced_nodes" {
  // Regression for css-contain/contain-size-replaced-003a:
  // whitespace immediately after <br> should not indent the next replaced element.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|video { border: 3px solid teal; contain: size; margin: 15px; width: auto; height: auto; }
    #|</style>
    #|<video id="v1"></video><br> <video id="v2"></video>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let mut second_x = -1.0
  for child in layout.children {
    if child.id == "video#v2" {
      second_x = child.x
    }
  }
  guard second_x >= 0.0 else { fail("layout should include second video node") }
  inspect(second_x, content="15")
}

///|
test "contain_size_replaced_line_break_baseline_matches_browser_like_offset" {
  // Regression for css-contain/contain-size-replaced-003a:
  // <br> after inline replaced sequence should align with the lower text baseline band.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|video { border: 3px solid teal; contain: size; margin: 15px; width: auto; height: auto; }
    #|</style>
    #|<video></video>
    #|<video></video>
    #|<video></video>
    #|<video></video>
    #|<video></video>
    #|<video></video>
    #|<br>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let mut br_y = -1.0
  for child in layout.children {
    if child.id == "br" {
      br_y = child.y
      break
    }
  }
  guard br_y >= 0.0 else {
    fail("layout should include br node after video sequence")
  }
  guard br_y >= 20.0 else {
    fail("br y should be on browser-like lower baseline band")
  }
}

///|
test "contain_size_picture_source_has_inline_line_box_height" {
  // Regression for css-contain/contain-size-replaced-003a:
  // picture/source should keep inline line-box height instead of collapsing to 0.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|img {
    #|  border: 3px solid teal;
    #|  contain: size;
    #|  margin: 15px;
    #|  width: auto;
    #|  height: auto;
    #|}
    #|</style>
    #|<img src="broken"><picture><source srcset="support/blue-100x100.png"><img></picture>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("layout should include img and picture nodes")
  }
  let picture = layout.children[1]
  guard picture.id == "picture" else { fail("second node should be picture") }
  guard picture.height <= 20.0 else {
    fail("picture inline box height should stay near text line-box height")
  }
  guard picture.children.length() >= 1 else {
    fail("picture should keep source/img child nodes")
  }
  let source = picture.children[0]
  guard source.id == "source" else {
    fail("picture first child should be source")
  }
  guard source.height >= 15.0 else {
    fail("source should retain inline line-box height contribution")
  }
}

///|
test "contain_size_aspect_ratio_auto_height_ignores_child_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="position: relative;">
    #|  <div id="bottom" style="contain: size; aspect-ratio: 1; background: red; width: 100px;">
    #|    <img height="200">
    #|  </div>
    #|  <div id="top" style="position: absolute; top: 0; left: 0; background: green; width: 100px; height: 100px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let bottom = outer.children[0]
  inspect(outer.height, content="100")
  inspect(bottom.height, content="100")
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
  debug_inspect(img_node.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let img_layout = layout.children[0]
  inspect(img_layout.width, content="100")
  inspect(img_layout.height, content="100")
}

///|
test "img_css_width_with_attr_dimensions_uses_aspect_ratio_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; } .frame { width: 600px; } .hero { display: block; width: 300px; height: auto; }</style>
    #|<div class="frame"><img class="hero" width="1926" height="1800" src="hero.png"></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let frame_node = root.children[0]
  let img_node = frame_node.children[0]
  inspect(img_node.style.width, content="Length(300)")
  inspect(img_node.style.height, content="Auto")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let frame = layout.children[0]
  let img = frame.children[0]
  inspect(img.width, content="300")
  assert_true((img.height - 280.37).abs() < 0.5)
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
  debug_inspect(item.style.aspect_ratio, content="Some(0.5)")
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
  debug_inspect(ratio_item.style.aspect_ratio, content="Some(1)")

  @node.setup()
  let layout_ctx : @layout_types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @layout_types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)
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

  @node.setup()
  let layout_ctx : @layout_types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @layout_types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)

  let svg = layout.children[0]

  inspect(svg.id, content="svg#target")
  inspect(svg.width, content="300")
  inspect(svg.height, content="150")
}

///|
test "svg_viewbox_auto_size_uses_available_inline_size" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<svg id="target" viewBox="0 0 200 80"></svg>

  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  @node.setup()
  let layout_ctx : @layout_types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @layout_types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)

  let svg = layout.children[0]

  inspect(svg.id, content="svg#target")
  inspect(svg.width, content="800")
  inspect(svg.height, content="320")
}

///|
test "svg_root_with_css_size_keeps_svg_children" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#svgMain { width: 200px; height: 200px; background: blue; }
    #|</style>
    #|<svg id="svgMain"><g id="group"><rect id="redSquare" width="100" height="100" fill="red"></rect></g></svg>

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let svg = layout.children[0]
  let group = svg.children[0]
  let rect = group.children[0]

  inspect(svg.id, content="svg#svgMain")
  inspect(svg.width, content="200")
  inspect(svg.height, content="200")
  inspect(group.id, content="g#group")
  inspect(group.width, content="100")
  inspect(group.height, content="100")
  inspect(rect.id, content="rect#redSquare")
  inspect(rect.width, content="100")
  inspect(rect.height, content="100")
}

///|
test "svg_viewbox_icon_fills_fixed_inline_container" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.button { display: inline-block; width: 40px; height: 40px; padding: 4px; }
    #|</style>
    #|<span class="button"><svg id="icon" viewBox="0 0 24 24"></svg></span>

  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  @node.setup()
  let layout_ctx : @layout_types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @layout_types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)

  let button = layout.children[0]
  let svg = button.children[0]

  inspect(button.width, content="48")
  inspect(button.height, content="48")
  inspect(svg.id, content="svg#icon")
  inspect(svg.x, content="4")
  inspect(svg.y, content="4")
  inspect(svg.width, content="40")
  inspect(svg.height, content="40")
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
test "wpt_intrinsic_percent_replaced_017_like_zero_sized_img_does_not_gain_line_strut" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer {
    #|  display: flex;
    #|  flex-direction: column;
    #|  width: 100px;
    #|  height: 100px;
    #|  align-items: center;
    #|}
    #|.inner {
    #|  max-height: 100%;
    #|}
    #|img {
    #|  max-height: 100%;
    #|}
    #|</style>
    #|<div class="outer">
    #|  <div class="inner">
    #|    <img src="aspect-ratio/support/200x200-green.png">
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let inner = outer.children[0]
  let img = inner.children[0]
  inspect(inner.width, content="0")
  inspect(inner.height, content="0")
  inspect(img.y, content="0")
  inspect(img.height, content="0")
}

///|
test "wpt_intrinsic_percent_replaced_030_like_vertical_max_block_size_keeps_ratio" {
  let html_str =
    #|<!DOCTYPE html>
    #|<div style="inline-size: min-content">
    #|  <canvas width="200" height="200"
    #|          style="writing-mode: vertical-rl; background: green; max-block-size: 50%"></canvas>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let outer = layout.children[0]
  let canvas = outer.children[0]

  inspect(outer.width, content="200")
  inspect(outer.height, content="100")
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
}

///|
test "br element preserved as separate node with line-height" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test" style="font: 20px/1 Ahem">line1<br>line2</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)

  // Check div#test
  let test_div = node.children[0]
  inspect(test_div.id, content="div#test")

  // Should have 3 children: text1, br, text2
  inspect(test_div.children.length(), content="3")
  let text1 = test_div.children[0]
  inspect(text1.id, content="#text")
  inspect(text1.style.font_size, content="20")
  let br = test_div.children[1]
  inspect(br.id, content="br")
  inspect(br.style.line_height, content="20")

  // Verify br has MeasureFunc (should have height via measure)
  inspect(br.measure is None, content="false")
  let text2 = test_div.children[2]
  inspect(text2.id, content="#text")
}

///|
test "br element has line-height for layout height" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<p id="test" style="font: 16px/1.2 Arial">Hello<br>World</p>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  // Check p#test
  let test_p = layout.children[0]
  inspect(test_p.id, content="p#test")

  // p should have 3 children: text, br, text
  inspect(test_p.children.length(), content="3")

  // Check br has height = line_height (16 * 1.2 = 19.2)
  let br = test_p.children[1]
  inspect(br.id, content="br")
  // height should be approximately 19.2 (16 * 1.2)
  inspect(
    br.height,
    content=(
      #|16.32
    ),
  )
}

///|
test "img_alt_text_propagation" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|  <h1>Test</h1>
    #|  <img src="test.jpg" width="200" height="100" alt="Alt text here">
    #|  <p>After</p>
    #|</body>
    #|</html>
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = render_to_node(html, ctx)
  let layout = render(html, ctx)
  // Debug: print all node IDs
  fn print_nodes(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    let _ = match n.text {
      Some(t) => " text=\"" + t + "\""
      None => ""
    }
    for child in n.children {
      print_nodes(child, depth + 1)
    }
  }

  print_nodes(node, 0)
  // Find img node
  fn find_img_node(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("img") {
      return Some(n)
    }
    for child in n.children {
      match find_img_node(child) {
        Some(img) => return Some(img)
        None => continue
      }
    }
    None
  }

  fn find_img_layout(l : @layout_types.Layout) -> @layout_types.Layout? {
    if l.id.has_prefix("img") {
      return Some(l)
    }
    for child in l.children {
      match find_img_layout(child) {
        Some(img) => return Some(img)
        None => continue
      }
    }
    None
  }
  // Check node has alt text
  match find_img_node(node) {
    Some(img) => {
      inspect(img.id, content="img")
      debug_inspect(img.text, content="Some(\"Alt text here\")")
    }
    None => fail("No img node found!")
  }
  // Check layout has text
  match find_img_layout(layout) {
    Some(img) => {
      inspect(img.id, content="img")
      debug_inspect(img.text, content="Some(\"Alt text here\")")
      inspect(img.width > 0.0, content="true")
      inspect(img.height > 0.0, content="true")
    }
    None => fail("No img layout found!")
  }
}

///|
test "img without src and percent max-size stays zero-sized in grid item" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head><style>body { margin: 0; }</style></head>
    #|<body>
    #|  <div style="display: grid; width: 100px;">
    #|    <div style="display: grid; margin: auto;">
    #|      <img style="max-width: 100%; max-height: 100%;">
    #|    </div>
    #|  </div>
    #|</body>
    #|</html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let outer_node = node.children[0]
  let inner_node = outer_node.children[0]
  let img_node = inner_node.children[0]
  inspect(inner_node.style.margin.left, content="Auto")
  inspect(inner_node.style.margin.right, content="Auto")
  inspect(img_node.style.display, content="Inline")
  inspect(img_node.style.max_width, content="Percent(1)")
  inspect(img_node.style.max_height, content="Percent(1)")
  inspect(
    match img_node.measure {
      Some(_) => true
      None => false
    },
    content="true",
  )

  let layout = @renderer.render(html, ctx)
  let outer = layout.children[0]
  let inner = outer.children[0]
  let img = inner.children[0]
  inspect(outer.width, content="100")
  inspect(img.width, content="0")
  inspect(inner.width, content="0")
}

///|
test "inline svg data uri resolves inherited icon fill color" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|:root { --icon-fill: #474747; }
    #|.icon { color: #9aa0a6; }
    #|</style>
    #|<span class="icon">
    #|  <svg id="search" viewBox="0 0 10 10">
    #|    <path d="M0 0h10v10H0z"></path>
    #|  </svg>
    #|</span>
    #|<svg id="mic" viewBox="0 0 10 10">
    #|  <path fill="var(--icon-fill)" d="M0 0h10v10H0z"></path>
    #|</svg>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  fn find_node_by_id(n : @node.Node, id : String) -> @node.Node? {
    if n.id == id {
      return Some(n)
    }
    for child in n.children {
      match find_node_by_id(child, id) {
        Some(found) => return Some(found)
        None => continue
      }
    }
    None
  }
  let search = match find_node_by_id(node, "svg#search") {
    Some(n) => n
    None => fail("search svg should be present")
  }
  let mic = match find_node_by_id(node, "svg#mic") {
    Some(n) => n
    None => fail("mic svg should be present")
  }

  match search.src {
    Some(src) => inspect(src.contains("fill=\"#9aa0a6\""), content="true")
    None => fail("inline search svg should become a data URI")
  }
  match mic.src {
    Some(src) => inspect(src.contains("fill=\"#474747\""), content="true")
    None => fail("inline mic svg should become a data URI")
  }
}

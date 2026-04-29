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
  @node.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: None,
    sizing_mode: @types.Definite,
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
  inspect(img.style.aspect_ratio, content="Some(1)")

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
  inspect(img_node.style.aspect_ratio, content="Some(1)")
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
  inspect(svg.style.aspect_ratio, content="Some(1)")

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
  inspect(svg.style.aspect_ratio, content="Some(1)")

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
test "fieldset_multicol_ignores_first_break_before_column_after_legend" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|  #scroller {
    #|    overflow: hidden;
    #|    columns: 2;
    #|    column-fill: auto;
    #|    padding: 0;
    #|    gap: 0;
    #|    width: 400px;
    #|    height: 100px;
    #|}
    #|  fieldset {
    #|    border: 3px solid black;
    #|  }
    #|</style>
    #|<fieldset id="scroller">
    #|  <legend>Legend</legend>
    #|  <div style="break-before:column;">first</div>
    #|  <div style="break-before:column;">second</div>
    #|</fieldset>
  let body = @renderer.render(html_str, @renderer.RenderContext::default())
  let fieldset = body.children[0]
  let first = fieldset.children[1]
  let second = fieldset.children[2]
  guard (first.x - 3.0).abs() < 0.01 else {
    fail("first post-legend multicol child should stay in first column")
  }
  guard (first.y - 19.2).abs() < 0.01 else {
    fail("first post-legend multicol child should start below legend band")
  }
  guard (second.x - 203.0).abs() < 0.01 else {
    fail("second child with break-before:column should move to second column")
  }
}

///|
test "contain_size_svg_leaf_collapses_to_border_box" {
  // Regression for css-contain/contain-size-replaced-003a{b,c}.html:
  // inline svg should stay replaced and keep contain:size suppression.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|svg { border: 3px solid teal; contain: size; margin: 15px; width: auto; height: auto; }
    #|</style>
    #|<svg></svg>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let svg = root.children[0]
  inspect(svg.style.contain.size, content="true")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let svg_layout = layout.children[0]
  inspect(svg_layout.width, content="6")
  inspect(svg_layout.height, content="6")
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
  let videos : Array[@types.Layout] = []
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
test "display_contents_inline_flex_collapses_boundary_spaces" {
  // Regression for css-display/display-contents-inline-flex-001:
  // text around display:contents descendants should collapse boundary
  // whitespace in flex formatting context ("012").
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.iflex { display: inline-flex; }
    #|.contents { display: contents; }
    #|.inline { display: inline; }
    #|</style>
    #|<div class="iflex">
    #|  <div class="contents">
    #|    0
    #|    <div class="inline">1</div>
    #|    2
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let host = layout.children[0]
  inspect(host.width, content="24")
}

///|
test "display_contents_inline_flex_drops_spaces_around_block_flex_items" {
  // Regression for css-display/display-contents-inline-flex-001:
  // whitespace around block-level flex items should collapse away ("012"), not
  // be preserved as boundary spaces.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.iflex { display: inline-flex; }
    #|.contents { display: contents; }
    #|</style>
    #|<div class="iflex">
    #|  <div class="contents">
    #|    0
    #|    <div>1</div>
    #|    2
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let host = layout.children[0]
  inspect(host.width, content="24")
}

///|
test "display_contents_inline_flex_keeps_spaces_between_text_runs" {
  // Regression for css-display/display-contents-inline-flex-001:
  // when display:contents wrappers flatten into adjacent text runs, one collapsed
  // boundary space should remain ("0 1 2").
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.iflex { display: inline-flex; }
    #|.contents { display: contents; }
    #|</style>
    #|<div class="iflex">
    #|  <div class="contents">
    #|    0
    #|    <div class="contents">1</div>
    #|    2
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let host = layout.children[0]
  inspect(host.width, content="40")
}

///|
test "display_contents_child_of_inline_stays_contents_and_parent_stays_inline" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.contents { display: contents; }
    #|.inline { display: inline; }
    #|</style>
    #|<div class="contents"><div class="inline"><div class="contents">4</div></div></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let contents = root.children[0]
  let inline = contents.children[0]
  let child_contents = inline.children[0]
  inspect(inline.style.display, content="Inline")
  inspect(child_contents.style.display, content="Contents")
}

///|
test "display_contents_textarea_computes_to_none" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|textarea { display: contents; }
    #|</style>
    #|<textarea>FAIL</textarea>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let child = layout.children[0]
  inspect(child.id, content="textarea")
  inspect(child.width, content="0")
  inspect(child.height, content="0")
}

///|
test "display_contents_whitespace_inside_inline_keeps_single_space" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|</style>
    #|<span>Foo<div style="display: contents"> </div>bar</span>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let span = root.children[0]
  let text = match span.children[0].text {
    Some(value) => value
    None => ""
  }
  inspect(text, content="Foo bar")
}

///|
test "display_contents_inside_closed_details_suppresses_non_summary_text" {
  let html_str =
    #|<!doctype html>
    #|<details>
    #|  <div style="display:contents">
    #|    <summary>summary</summary>
    #|    details
    #|  </div>
    #|</details>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  fn contains_trimmed_text(node : @node.Node, target : String) -> Bool {
    match node.text {
      Some(text) => if text.trim().to_string() == target { return true }
      None => ()
    }
    for child in node.children {
      if contains_trimmed_text(child, target) {
        return true
      }
    }
    false
  }
  guard contains_trimmed_text(root, "summary") else {
    fail("closed details should keep summary text")
  }
  guard !contains_trimmed_text(root, "details") else {
    fail("closed details should suppress non-summary descendants")
  }
}

///|
test "display_contents_list_like_inline_wrapper_keeps_inline_display" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html, body { font-size: 16px; padding: 0; margin: 0; }
    #|.inline { display: inline; }
    #|.contents { display: contents; }
    #|.c2 { background: blue; color: pink; }
    #|.c3 { color: teal; }
    #|.c4 { color: green; }
    #|.b { background: inherit; }
    #|</style>
    #|<div class="contents c2">
    #|  0
    #|  <div class="contents c1">x</div>
    #|  <div class="contents c1"><div class="contents c2">y</div></div>
    #|  <div class="contents c1"><div class="contents c2"><div>1<span class="b">1</span></div></div></div>
    #|  <div class="contents c2"><div class="inline">2a<div>2<div class="contents c2">b<span class="b">b</span></div></div></div></div>
    #|  <div class="contents c3"><div class="inline">3</div></div>
    #|  <div class="inline"><div class="contents c4">4</div></div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  fn contains_trimmed_text(node : @node.Node, target : String) -> Bool {
    match node.text {
      Some(text) => if text.trim() == target { return true }
      None => ()
    }
    for child in node.children {
      if contains_trimmed_text(child, target) {
        return true
      }
    }
    false
  }
  fn find_inline_with_text_4(node : @node.Node) -> @node.Node? {
    if node.id == "div.inline" && contains_trimmed_text(node, "4") {
      return Some(node)
    }
    for child in node.children {
      match find_inline_with_text_4(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
  match find_inline_with_text_4(root) {
    Some(inline4) => {
      inspect(inline4.style.display, content="Inline")
      guard inline4.children.length() > 0 else {
        fail("inline wrapper for text 4 should have a child")
      }
      inspect(inline4.children[0].style.display, content="Contents")
    }
    None => fail("target inline wrapper with text 4 should exist")
  }
}

///|
test "display_contents_pseudo_text_participates_in_inline_flex_layout" {
  // Regression for css-display/display-contents-before-after-003:
  // ::before/::after with display:contents should contribute generated text as
  // inline content, not as zero-sized pseudo boxes.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.flex { display: inline-flex; flex-direction: column; }
    #|.flex::before { display: contents; content: "A"; }
    #|.flex::after { display: contents; content: "S"; }
    #|</style>
    #|<div class="flex"></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let host = root.children[0]
  inspect(host.children.length(), content="2")
  inspect(host.children[0].id, content="#pseudo::before")
  inspect(host.children[0].children.length(), content="1")
  inspect(host.children[0].children[0].id, content="#text")
  inspect(host.children[1].id, content="#pseudo::after")
  inspect(host.children[1].children.length(), content="1")
  inspect(host.children[1].children[0].id, content="#text")
  let wpt_like_html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.flex { display: inline-flex; flex-direction: column; }
    #|.flex::before { display: contents; content: "A"; }
    #|.flex::after { display: contents; content: "S"; }
    #|</style>
    #|P<div class="flex"></div>S
  let layout = @renderer.render(
    wpt_like_html,
    @renderer.RenderContext::default(),
  )
  let mut flex_width = -1.0
  for child in layout.children {
    if child.id == "div.flex" {
      flex_width = child.width
      break
    }
  }
  guard flex_width >= 0.0 else { fail("flex layout node should be present") }
  guard flex_width >= 8.0 else {
    fail(
      "display:contents pseudo generated text should contribute positive inline-flex width",
    )
  }
}

///|
test "display_contents_selector_matches_when_class_is_not_first" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.columns { columns: 2; }
    #|.contents { display: contents; }
    #|</style>
    #|<div class="columns">
    #|  <div class="columns contents"><div>A</div></div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let outer = root.children[0]
  let inner = outer.children[0]
  inspect(inner.style.display, content="Contents")
}

///|
test "pseudo_content_var_from_root_custom_properties_renders_text" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|:root { --a: "hello"; --b: "there"; }
    #|#a::before { content: var(--a) " " var(--b); }
    #|</style>
    #|<p id="a"></p>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let host = root.children[0]
  guard host.id == "p#a" else { fail("expected target paragraph") }
  guard host.children.length() > 0 else {
    fail("pseudo content should create inline text child")
  }
  let generated = host.children[0]
  inspect(generated.id, content="#text")
  inspect(generated.text, content="Some(\"hello there\")")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let p = layout.children[0]
  inspect(
    p.height,
    content=(
      #|16
    ),
  )
}

///|
test "pseudo_content_var_can_expand_attr_based_custom_property" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|div::before {
    #|  --my-attr: attr(data-foo);
    #|  content: var(--my-attr);
    #|}
    #|</style>
    #|<div data-foo="PASS"></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let host = root.children[0]
  guard host.id == "div" else { fail("expected target div") }
  guard host.children.length() > 0 else {
    fail("attr()-based pseudo content should create child text")
  }
  let generated = host.children[0]
  inspect(generated.id, content="#text")
  inspect(generated.text, content="Some(\"PASS\")")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  inspect(
    layout.children[0].height,
    content=(
      #|16
    ),
  )
}

///|
test "display_contents_columns_combo_keeps_contents_display_in_wpt_like_tree" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.columns { columns: 2; height: 4em; }
    #|.contents { display: contents; }
    #|</style>
    #|<div class="columns">
    #|  <div class="columns contents">
    #|    <div class="contents"><div>1</div></div>
    #|    <div class="contents"><div>2</div></div>
    #|    <div class="contents"><div>3</div></div>
    #|  </div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let outer = root.children[0]
  let inner = outer.children[0]
  inspect(inner.id, content="div.columns")
  inspect(inner.style.display, content="Contents")
}

///|
test "display_inline_with_contents_child_stays_inline_sized" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.inline { display: inline; }
    #|.contents { display: contents; }
    #|</style>
    #|<div id="root">
    #|  <div class="inline"><div class="contents">4</div></div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let outer = root.children[0]
  let inline = outer.children[0]
  inspect(inline.style.display, content="Inline")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer_layout = layout.children[0]
  let inline_layout = outer_layout.children[0]
  inspect(
    inline_layout.width,
    content=(
      #|8
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
test "balanced_multicol_child_uses_union_width_without_containment" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { min-height: 10px; margin-bottom: 10px; }
    #|.columns {
    #|  columns: 2;
    #|  column-rule-width: medium;
    #|  column-rule-style: solid;
    #|}
    #|.inner { height: 20px; }
    #|</style>
    #|<div class="columns"><div class="inner"></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let columns = layout.children[0]
  let inner = columns.children[0]
  inspect(columns.height, content="25")
  inspect(inner.width, content="800")
  inspect(inner.height, content="15")
}

///|
test "abspos_align_self_stretch_with_inset_shorthand_spans_containing_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.container { position: relative; width: 200px; height: 200px; }
    #|.abspos {
    #|  position: absolute;
    #|  inset: 50px auto 50px 50px;
    #|  margin: auto 0 auto 0;
    #|  align-self: stretch;
    #|}
    #|.abspos::before {
    #|  content: '';
    #|  min-width: 50px;
    #|  height: 100%;
    #|  aspect-ratio: 1;
    #|  display: block;
    #|}
    #|</style>
    #|<div class="container"><div class="abspos"></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let abspos = container.children[0]
  inspect(abspos.width, content="100")
  inspect(abspos.height, content="100")
}

///|
test "abspos_justify_self_stretch_with_inset_shorthand_spans_containing_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.container { position: relative; width: 200px; height: 200px; }
    #|.abspos {
    #|  position: absolute;
    #|  inset: 50px 50px auto 50px;
    #|  margin: 0 auto 0 auto;
    #|  justify-self: stretch;
    #|}
    #|.abspos::before {
    #|  content: '';
    #|  width: 100%;
    #|  min-height: 50px;
    #|  aspect-ratio: 1;
    #|  display: block;
    #|}
    #|</style>
    #|<div class="container"><div class="abspos"></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let abspos = container.children[0]
  inspect(abspos.width, content="100")
  inspect(abspos.height, content="100")
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
test "white_space_nowrap_parent_keeps_inline_block_children_on_same_line" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#scroller {
    #|  width: 600px;
    #|  white-space: nowrap;
    #|}
    #|#scroller div {
    #|  display: inline-block;
    #|  width: 600px;
    #|  height: 20px;
    #|}
    #|</style>
    #|<div id="scroller">
    #|  <div id="a"></div>
    #|  <div id="b"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let scroller = layout.children[0]
  guard scroller.children.length() >= 2 else {
    fail("scroller should include two inline-block children")
  }
  let first = scroller.children[0]
  let second = scroller.children[1]
  inspect(first.x, content="0")
  guard second.x > 500.0 else {
    fail("second inline-block should stay on the same line under nowrap")
  }
  inspect(
    second.y,
    content=(
      #|7.199999999999999
    ),
  )
}

///|
test "wpt_contain_layout_breaks_forced_column_break_stays_in_multicol" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|article {
    #|  columns: 2 1ch;
    #|  column-gap: 0;
    #|  font-family: monospace;
    #|  line-height: 1;
    #|  height: 4em;
    #|  column-fill: auto;
    #|}
    #|#forced { break-before: column; }
    #|</style>
    #|<article>
    #|  <div>
    #|    <div id="first">A<br>A</div>
    #|    <div id="forced">A<br>A</div>
    #|  </div>
    #|</article>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let article = layout.children[0]
  let wrapper = article.children[0]
  let first = wrapper.children[0]
  let forced = wrapper.children[1]
  guard forced.x > first.x else {
    fail("break-before:column child should move to the next column")
  }
  inspect(forced.y, content="0")
}

///|
test "wpt_contain_layout_forced_break_does_not_escape_parent" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|article {
    #|  columns: 2 100px;
    #|  column-fill: auto;
    #|  column-gap: 0;
    #|  float: left;
    #|  height: 400px;
    #|}
    #|#yellow-normal { border-top: yellow solid 100px; }
    #|#blue-parent {
    #|  border-top: blue solid 100px;
    #|  contain: layout;
    #|}
    #|#orange-child {
    #|  border-top: orange solid 100px;
    #|  break-before: column;
    #|}
    #|</style>
    #|<article>
    #|  <div id="yellow-normal"></div>
    #|  <div id="blue-parent"><div id="orange-child"></div></div>
    #|</article>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let article = layout.children[0]
  let blue_parent = article.children[1]
  let orange_child = blue_parent.children[0]
  inspect(blue_parent.x, content="0")
  inspect(blue_parent.y, content="100")
  inspect(blue_parent.height, content="200")
  inspect(orange_child.x, content="0")
  inspect(orange_child.y, content="100")
}

///|
test "multicol_break_inside_avoid_keeps_block_unfragmented" {
  // Regression for css-contain/contain-style-breaks-00{1,2,3}.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|article {
    #|  columns: 2 1ch;
    #|  column-gap: 0;
    #|  font-family: monospace;
    #|}
    #|#target {
    #|  break-inside: avoid;
    #|}
    #|</style>
    #|<article id="article">
    #|  <div id="target">
    #|    A<br>
    #|    A<br>
    #|    A<br>
    #|    A
    #|  </div>
    #|</article>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let article = layout.children[0]
  let target = article.children[0]
  let mut max_child_x = 0.0
  let mut min_delta_y = 0.0
  let mut prev_y = -1.0
  for child in target.children {
    if child.x > max_child_x {
      max_child_x = child.x
    }
    if prev_y >= 0.0 {
      let delta = child.y - prev_y
      if delta < min_delta_y {
        min_delta_y = delta
      }
    }
    prev_y = child.y
  }
  guard max_child_x <= 8.5 else {
    fail("break-inside:avoid block children should not spill to next column")
  }
  guard min_delta_y >= -0.1 else {
    fail("break-inside:avoid block should keep child flow in one column")
  }
}

///|
test "multicol_balance_break_before_avoid_keeps_balanced_column_boundary" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="width:100px; columns:2; column-gap:0;">
    #|  <div style="height:25px;"></div>
    #|  <div style="height:50px;"></div>
    #|  <div style="height:25px; break-before:avoid;"></div>
    #|  <div id="last" style="height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let last = target.children[3]
  inspect(target.height, content="100")
  inspect(last.x, content="50")
  inspect(last.y, content="0")
}

///|
test "multicol_auto_fill_break_avoid_moves_group_start_to_next_column" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:160px;">
    #|  <div style="height:50px;"></div>
    #|  <div style="height:50px;"></div>
    #|  <div id="third" style="height:50px;"></div>
    #|  <div id="last" style="height:50px; break-before:avoid;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let third = target.children[2]
  let last = target.children[3]
  inspect(third.x, content="50")
  inspect(third.y, content="0")
  inspect(last.x, content="50")
  inspect(last.y, content="50")
}

///|
test "multicol_nested_forced_break_at_start_moves_wrapper_to_next_column" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; column-fill:auto; column-gap:0; height:250px;">
    #|    <div id="first" style="height:100px;"></div>
    #|    <div id="wrapper"><div style="break-before:column;"></div></div>
    #|    <div id="last" style="height:100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let wrapper = target.children[1]
  let last = target.children[2]
  inspect(wrapper.x, content="50")
  inspect(wrapper.y, content="0")
  inspect(last.x, content="50")
  inspect(last.y, content="0")
}

///|
test "multicol_nested_forced_break_at_end_moves_next_sibling_to_next_column" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; column-fill:auto; column-gap:0; height:250px;">
    #|    <div id="first" style="height:100px;"></div>
    #|    <div id="wrapper"><div style="break-after:column;"></div></div>
    #|    <div id="last" style="height:100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let last = target.children[2]
  inspect(last.x, content="50")
  inspect(last.y, content="0")
}

///|
test "multicol_forced_break_trumps_break_avoid_grouping" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:110px;">
    #|  <div style="height:50px;"></div>
    #|  <div id="second" style="height:50px; break-after:column;"></div>
    #|  <div id="third" style="height:50px; break-before:avoid;"></div>
    #|  <div id="last" style="height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let second = target.children[1]
  let third = target.children[2]
  let last = target.children[3]
  inspect(second.x, content="0")
  inspect(second.y, content="50")
  inspect(third.x, content="50")
  inspect(third.y, content="0")
  inspect(last.x, content="50")
  inspect(last.y, content="50")
}

///|
test "multicol_discards_top_margin_at_fragment_start" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:100px;">
    #|  <div style="height:70px;"><div style="height:150px;"></div></div>
    #|  <div id="wrapper">
    #|    <div id="inner" style="margin-top:60px;">
    #|      <div style="height:50px;"></div>
    #|      <div id="green" style="height:50px;"></div>
    #|    </div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let first = target.children[0]
  let tall = first.children[0]
  let wrapper = target.children[1]
  let inner = wrapper.children[0]
  let green = inner.children[1]
  inspect(tall.width, content="100")
  inspect(tall.height, content="100")
  inspect(wrapper.x, content="50")
  inspect(wrapper.y, content="0")
  inspect(wrapper.width, content="50")
  inspect(inner.y, content="0")
  inspect(green.y, content="50")
}

///|
test "multicol_break_avoid_backtracks_inside_wrapper_for_following_sibling" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:160px;">
    #|  <div id="wrapper">
    #|    <div style="height:50px;"></div>
    #|    <div>
    #|      <div id="deep">
    #|        <div style="height:50px; break-inside:avoid;"></div>
    #|        <div id="moved" style="height:50px; break-inside:avoid;"></div>
    #|      </div>
    #|    </div>
    #|  </div>
    #|  <div id="tail" style="height:50px; break-before:avoid;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let wrapper = target.children[0]
  let nested = wrapper.children[1]
  let deep = nested.children[0]
  let moved = deep.children[1]
  let tail = target.children[1]
  inspect(wrapper.width, content="100")
  inspect(nested.y, content="0")
  inspect(deep.width, content="100")
  inspect(moved.x, content="50")
  inspect(moved.y, content="0")
  inspect(tail.x, content="50")
  inspect(tail.y, content="50")
}

///|
test "multicol_break_avoid_can_move_previous_sibling_to_keep_group_together" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="column-count:4; column-gap:0; column-fill:auto; width:100px; height:100px;">
    #|  <div style="width:25px; height:50px;"></div>
    #|  <div id="second" style="width:25px; height:50px;"></div>
    #|  <div id="wrapper">
    #|    <div id="keep" style="height:50px; break-before:avoid;"></div>
    #|    <div id="spill" style="height:200px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let second = target.children[1]
  let wrapper = target.children[2]
  let keep = wrapper.children[0]
  let spill = wrapper.children[1]
  inspect(second.x, content="25")
  inspect(second.y, content="0")
  inspect(keep.y, content="50")
  inspect(spill.x, content="25")
  inspect(spill.y, content="0")
}

///|
test "multicol_break_avoid_reflows_single_child_block_wrapper_descendants" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; column-fill:auto; width:250px; column-gap:50px; margin-left:-150px; height:110px;">
    #|    <div style="height:2px;"></div>
    #|    <div id="wrapper1">
    #|      <div id="wrapper2">
    #|        <div id="wrapper3">
    #|          <div style="contain:size; height:50px;"></div>
    #|          <div id="b" style="contain:size; height:50px;"></div>
    #|        </div>
    #|      </div>
    #|      <div id="c" style="break-before:avoid; contain:size; height:50px;"></div>
    #|    </div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let wrapper1 = target.children[1]
  let wrapper2 = wrapper1.children[0]
  let wrapper3 = wrapper2.children[0]
  let b = wrapper3.children[1]
  let c = wrapper1.children[1]
  inspect(wrapper2.width, content="250")
  inspect(wrapper3.width, content="250")
  inspect(b.x, content="150")
  inspect(b.y, content="0")
  inspect(c.x, content="150")
  inspect(c.y, content="42")
}

///|
test "multicol_break_avoid_moves_float_with_following_reserved_group" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; gap:0; column-fill:auto; height:150px;">
    #|    <div style="height:100px;"></div>
    #|    <div style="height:30px;"></div>
    #|    <div id="float" style="float:left; width:50%;">
    #|      <div style="height:10px; contain:size;"></div>
    #|      <div style="height:10px; contain:size;"></div>
    #|    </div>
    #|    <div id="keep" style="break-before:avoid; break-inside:avoid;">
    #|      <div id="keep-first" style="margin-left:auto; width:50%; height:20px;"></div>
    #|      <div style="height:50px;"></div>
    #|    </div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let float_box = target.children[2]
  let keep = target.children[3]
  let keep_first = keep.children[0]
  inspect(float_box.x, content="50")
  inspect(float_box.y, content="30")
  inspect(keep.x, content="50")
  inspect(keep.y, content="30")
  inspect(keep_first.x, content="25")
}

///|
test "multicol_margin_fragment_start_preserves_block_stack_width_inside_inline_wrapper" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; gap:0; column-fill:auto; width:100px; height:100px;">
    #|  <span>
    #|    <div style="height:70px;"><div style="height:150px;"></div></div>
    #|    <span>
    #|      <div style="margin-top:60px;">
    #|        <div id="first" style="height:50px;"></div>
    #|        <div id="green" style="height:50px;"></div>
    #|      </div>
    #|    </span>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let span = outer.children[0]
  let tail_span = span.children[1]
  let inner = tail_span.children[0]
  let first = inner.children[0]
  let green = inner.children[1]
  inspect(span.width, content="100")
  inspect(tail_span.x, content="50")
  inspect(tail_span.width, content="50")
  inspect(inner.width, content="50")
  inspect(first.y, content="0")
  inspect(green.x, content="0")
  inspect(green.y, content="50")
}

///|
test "multicol_margin_fragment_start_keeps_float_only_inline_wrapper_zero_sized" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; gap:0; column-fill:auto; width:100px; height:100px;">
    #|  <span>
    #|    <div style="height:70px;"><div style="height:150px;"></div></div>
    #|    <span id="tail-span">
    #|      <div id="float-wrap" style="margin-top:160px;">
    #|        <div style="float:left; width:100%;">
    #|          <div id="first" style="height:50px;"></div>
    #|          <div id="green" style="height:50px;"></div>
    #|        </div>
    #|      </div>
    #|    </span>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let span = outer.children[0]
  let tail_span = span.children[1]
  let float_wrap = tail_span.children[0]
  let float_box = float_wrap.children[0]
  let green = float_box.children[1]
  inspect(span.width, content="150")
  inspect(tail_span.x, content="100")
  inspect(tail_span.width, content="50")
  inspect(float_wrap.x, content="50")
  inspect(float_wrap.width, content="50")
  inspect(float_box.width, content="50")
  inspect(green.y, content="50")
}

///|
test "wpt_contain_inline_size_multicol_spanner_balances_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="columns:4; column-gap:0; contain:inline-size; width:fit-content; border:solid green; border-width:0 50px;">
    #|  <div id="tall" style="width:25px; height:200px;"></div>
    #|  <div id="spanner" style="column-span:all; width:400px; height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let tall = outer.children[0]
  let spanner = outer.children[1]
  inspect(outer.height, content="100")
  inspect(tall.height, content="50")
  inspect(spanner.y, content="50")
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
test "contain_size_multicol_fragment_union_matches_browser_rects" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.contain {
    #|  contain: size;
    #|  border: 1em solid green;
    #|  background: red;
    #|  column-count: 3;
    #|}
    #|.inner {
    #|  color: transparent;
    #|  width: 50px;
    #|  height: 50px;
    #|}
    #|</style>
    #|<div id="contain" class="contain"><div id="inner" class="inner">inner</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let contain = layout.children[0]
  let inner = contain.children[0]
  inspect(contain.width, content="800")
  inspect(contain.height, content="32")
  guard inner.width > 560.0 else {
    fail("fragmented union width should span later columns")
  }
  guard inner.height < 30.0 else {
    fail("fragmented union height should collapse to one fragment band")
  }
}

///|
test "contain_size_text_only_multicol_child_keeps_zero_outer_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#multi-column {
    #|  column-count: 2;
    #|  column-fill: balance;
    #|  column-gap: 4ch;
    #|  column-rule: red solid 4ch;
    #|  column-width: 2ch;
    #|  font-family: monospace;
    #|  font-size: 20px;
    #|  width: 8ch;
    #|}
    #|#size-contain { contain: size; }
    #|</style>
    #|<div id="multi-column"><div id="size-contain">AB CD EF GH</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let multicol = layout.children[0]
  let contain = multicol.children[0]
  inspect(multicol.height, content="0")
  inspect(contain.height, content="0")
}

///|
test "contain_size_abspos_monolithic_box_keeps_explicit_size_inside_multicol" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#multicol { width: 300px; column-count: 3; }
    #|#container { position: relative; }
    #|#abs-size-contain {
    #|  position: absolute;
    #|  contain: size;
    #|  width: 100px;
    #|  height: 100px;
    #|  background: green;
    #|}
    #|</style>
    #|<div id="multicol"><div id="container"><div id="abs-size-contain"></div></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let multicol = layout.children[0]
  let container = multicol.children[0]
  let abs_box = container.children[0]
  inspect(abs_box.width, content="100")
  inspect(abs_box.height, content="100")
}

///|
test "wpt_column_scroll_marker_004_fieldset_multicol_fragments" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  #container {
    #|    overflow: hidden;
    #|    columns: 3;
    #|    column-fill: auto;
    #|    gap: 0;
    #|    height: 50px;
    #|    margin: 0;
    #|    border: 15px solid green;
    #|    padding: 0;
    #|    scroll-marker-group: before;
    #|    background: red;
    #|  }
    #|  #container::scroll-marker-group {
    #|    display: flex;
    #|    height: 20px;
    #|    background: red;
    #|  }
    #|  #container::column::scroll-marker {
    #|    display: flex;
    #|    width: 20px;
    #|    height: 100%;
    #|    background: green;
    #|    content: "";
    #|  }
    #|</style>
    #|<div style="width:100px; height:100px; background:red;">
    #|  <fieldset id="container">
    #|    <legend style="width:50px; height:15px; background:green;"></legend>
    #|    <div style="height:210px; background:green;"></div>
    #|  </fieldset>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let raw_wrapper = node.children[0]
  let raw_carousel = raw_wrapper.children[0]
  inspect(
    raw_carousel.style.box_sizing,
    content=(
      #|BorderBox
    ),
  )
  inspect(
    raw_carousel.children.length(),
    content=(
      #|2
    ),
  )
  let wrapper = layout.children[0]
  let container = wrapper.children[0]
  let content = container.children[1]
  inspect(container.id, content="fieldset#container")
  inspect(content.width, content="116.66666666666666")
  inspect(content.height, content="50")
}

///|
test "wpt_targeted_column_scroll_marker_selection_001_static_layout_metrics" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  .wrapper {
    #|    display: grid;
    #|    justify-content: center;
    #|  }
    #|  .carousel {
    #|    width: 800px;
    #|    height: 200px;
    #|    overflow-x: scroll;
    #|    scroll-snap-type: x mandatory;
    #|    list-style-type: none;
    #|    scroll-behavior: smooth;
    #|    border: solid 2px grey;
    #|    padding-top: 10%;
    #|    text-align: center;
    #|    counter-set: markeridx -1;
    #|    columns: 2;
    #|
    #|    &::column::scroll-marker {
    #|      content: counter(markeridx);
    #|      counter-increment: markeridx;
    #|      align-content: center;
    #|      text-align: center;
    #|      width: 35px;
    #|      height: 35px;
    #|      border-radius: 50%;
    #|      margin: 3px;
    #|      background-color: red;
    #|    }
    #|    &::column::scroll-marker:target-current {
    #|      background-color: green;
    #|    }
    #|    &>.item {
    #|      scroll-snap-align: center;
    #|      height: 80%;
    #|      width: 158px;
    #|      border: 1px solid;
    #|      place-content: center;
    #|      display: inline-block;
    #|    }
    #|
    #|    scroll-marker-group: after;
    #|
    #|    &::scroll-marker-group {
    #|      height: 45px;
    #|      display: flex;
    #|      align-items: center;
    #|      justify-content: center;
    #|      border: solid 1px black;
    #|      border-radius: 30px;
    #|    }
    #|  }
    #|</style>
    #|<div class="wrapper" id="wrapper">
    #|  <div class="carousel" id="carousel">
    #|    <div class="item item0" tabindex=0>0</div>
    #|    <div class="item item1" tabindex=0>1</div>
    #|    <div class="item item2" tabindex=0>2</div>
    #|    <div class="item item3" tabindex=0>3</div>
    #|    <div class="item item4" tabindex=0>4</div>
    #|    <div class="item item5" tabindex=0>5</div>
    #|    <div class="item item6" tabindex=0>6</div>
    #|    <div class="item item7" tabindex=0>7</div>
    #|    <div class="item item8" tabindex=0>8</div>
    #|    <div class="item item9" tabindex=0>9</div>
    #|    <div class="item item10" tabindex=0>10</div>
    #|    <div class="item item11" tabindex=0>11</div>
    #|    <div class="item item12" tabindex=0>12</div>
    #|    <div class="item item13" tabindex=0>13</div>
    #|    <div class="item item14" tabindex=0>14</div>
    #|    <div class="item item15" tabindex=0>15</div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let raw_wrapper = node.children[0]
  let raw_carousel = raw_wrapper.children[0]
  inspect(
    raw_carousel.children.length(),
    content=(
      #|31
    ),
  )
  let wrapper = layout.children[0]
  let carousel = wrapper.children[0]
  let item0 = carousel.children[0]
  inspect(carousel.id, content="div#carousel")
  inspect(carousel.padding.top, content="80.4")
  inspect(carousel.height, content="284.4")
  inspect(
    item0.x,
    content=(
      #|30
    ),
  )
  inspect(
    item0.height,
    content=(
      #|160
    ),
  )
}

///|
test "contain_size_multicol_intrinsic_width_in_flex_includes_gaps" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.flexBaselineCheck { display: flex; align-items: baseline; }
    #|.contain {
    #|  contain: size;
    #|  border: 1em solid green;
    #|  background: red;
    #|  column-count: 3;
    #|}
    #|.inner {
    #|  color: transparent;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div class="flexBaselineCheck">
    #|  outside before
    #|  <div id="contain" class="contain"><div id="inner" class="inner">inner</div></div>
    #|  outside after
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  let contain = flex.children[1]
  let inner = contain.children[0]
  inspect(
    contain.width,
    content=(
      #|64
    ),
  )
  inspect(contain.height, content="32")
  inspect(
    inner.width,
    content=(
      #|132
    ),
  )
  guard inner.height > 30.0 && inner.height < 36.0 else {
    fail("contain:size multicol child should clip to one balanced fragment")
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
test "contain_size_fieldset_uses_empty_intrinsic_width" {
  // Regression for css-contain/contain-size-fieldset-002.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|#border { border: 1px solid black; width: min-content; }
    #|fieldset { contain: size; visibility: hidden; height: 1px; }
    #|</style>
    #|<p>This test passes if it has the same output as the reference.</p>
    #|<div id="border">
    #|  <fieldset>
    #|    <legend>legend</legend>
    #|    Fieldset contents are here.
    #|  </fieldset>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 2 else {
    fail("body should contain paragraph and border wrapper")
  }
  let border_box = layout.children[1]
  let fieldset = border_box.children[0]
  guard border_box.id == "div#border" else {
    fail("second body child should be border wrapper")
  }
  guard fieldset.id == "fieldset" else {
    fail("fieldset should remain in layout tree")
  }
  guard border_box.width <= 40.0 else {
    fail("contain:size fieldset wrapper should not grow from legend text")
  }
  guard fieldset.width <= 32.0 else {
    fail("contain:size fieldset should use empty intrinsic width")
  }
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
test "contain_size_zero_width_wrapper_wraps_text_before_br" {
  // Regression for css-contain/contain-size-063.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.abs { position: absolute; }
    #|.contained { contain: size; color: transparent; }
    #|</style>
    #|<div class="abs"><div class="contained">Arbitrary content content<br>that takes up size.<br>Block Layout</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else {
    fail("body should include abs wrapper")
  }
  let wrapper = layout.children[0]
  guard wrapper.children.length() >= 1 else {
    fail("abs wrapper should include contained child")
  }
  let contained = wrapper.children[0]
  let mut first_br_x = -1.0
  let mut first_br_y = -1.0
  for child in contained.children {
    if child.id == "br" {
      first_br_x = child.x
      first_br_y = child.y
      break
    }
  }
  guard first_br_x >= 0.0 else { fail("contained node should include br") }
  guard first_br_x <= 80.0 else {
    fail("contain:size text should wrap before br in zero-width wrapper")
  }
  guard first_br_y >= 30.0 else {
    fail("wrapped lines should push br down in zero-width wrapper")
  }
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
test "visibility_hidden_parent_preserves_visible_inline_child_for_text_overflow" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; }
    #|#parent {
    #|  display: inline-block;
    #|  vertical-align: top;
    #|  font-family: Ahem;
    #|}
    #|#element {
    #|  visibility: hidden;
    #|  text-overflow: ellipsis;
    #|  white-space: nowrap;
    #|  max-width: 4ch;
    #|  overflow: hidden;
    #|}
    #|</style>
    #|<div id="parent">
    #|  <div id="element"><span style="visibility: visible">ABCABCABCABC</span></div>
    #|</div>
  let node_root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let parent_node = node_root.children[0]
  let element_node = parent_node.children[0]
  inspect(element_node.id, content="div#element")
  inspect(element_node.children.length(), content="1")
  inspect(element_node.children[0].id, content="span")

  let layout_root = @renderer.render(
    html_str,
    @renderer.RenderContext::default(),
  )
  let parent_layout = layout_root.children[0]
  let element_layout = parent_layout.children[0]
  let span_layout = element_layout.children[0]
  inspect(parent_layout.width, content="64")
  inspect(element_layout.width, content="64")
  inspect(span_layout.width, content="192")
}

///|
test "text_overflow_ellipsis_truncates_direct_text_in_paint_tree" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; }
    #|#clip {
    #|  width: 64px;
    #|  overflow: hidden;
    #|  white-space: nowrap;
    #|  text-overflow: ellipsis;
    #|  font-size: 16px;
    #|  line-height: 16px;
    #|}
    #|</style>
    #|<div id="clip">abcdefghijk</div>
  let (node_root, layout_root) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let paint_root = @paint_node.from_node_and_layout(node_root, layout_root)
  let clip_paint = paint_root.children[0]
  guard clip_paint.id == "div#clip" else {
    fail("paint tree should keep the clip container as first child")
  }
  guard clip_paint.children.length() == 1 else {
    fail("clip container should expose a single text child")
  }
  let text_paint = clip_paint.children[0]
  inspect(text_paint.text, content="Some(\"abcde...\")")
  inspect(text_paint.width, content="64")
}

///|
test "text_overflow_ellipsis_truncates_single_inline_wrapper_text_in_paint_tree" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; }
    #|#clip {
    #|  width: 64px;
    #|  overflow: hidden;
    #|  white-space: nowrap;
    #|  text-overflow: ellipsis;
    #|  font-size: 16px;
    #|  line-height: 16px;
    #|}
    #|</style>
    #|<div id="clip"><span>abcdefghijk</span></div>
  let (node_root, layout_root) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let paint_root = @paint_node.from_node_and_layout(node_root, layout_root)
  let clip_paint = paint_root.children[0]
  guard clip_paint.id == "div#clip" else {
    fail("paint tree should keep the clip container as first child")
  }
  guard clip_paint.children.length() == 1 else {
    fail("clip container should expose the inline wrapper child")
  }
  let span_paint = clip_paint.children[0]
  inspect(span_paint.id, content="span")
  guard span_paint.children.length() == 1 else {
    fail("inline wrapper should keep a single text child")
  }
  let text_paint = span_paint.children[0]
  inspect(text_paint.text, content="Some(\"abcde...\")")
  inspect(text_paint.width, content="64")
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
test "rt_explicit_font_size_overrides_ua_half_size_default" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>rt { font-size: 1rem; }</style>
    #|<ruby><rt>PASS</rt></ruby>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let ruby = root.children[0]
  let rt = ruby.children[0]
  inspect(rt.style.font_size, content="16")
}

///|
test "rt_inline_font_size_1rem_applies" {
  let html_str =
    #|<!DOCTYPE html>
    #|<ruby><rt style="font-size: 1rem">PASS</rt></ruby>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let ruby = root.children[0]
  let rt = ruby.children[0]
  inspect(rt.style.font_size, content="16")
}

///|
test "contain_size_on_rt_is_ignored_for_intrinsic_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { overflow: hidden; position: absolute; }
    #|rt {
    #|  contain: size;
    #|  display: ruby-text;
    #|  font-size: 1rem;
    #|}
    #|</style>
    #|<div><ruby><rt>PASS</rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[0]
  guard div.children.length() > 0 else { fail("div should include ruby child") }
  let ruby = div.children[0]
  guard ruby.children.length() > 0 else { fail("ruby should include rt child") }
  let rt = ruby.children[0]
  guard rt.width >= 30.0 else {
    fail("rt width should reflect 1rem text width, not size-contained collapse")
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
    if !child.id.has_prefix("#text") {
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
test "ruby_internal_elements_default_to_inline_display" {
  let html_str =
    #|<!DOCTYPE html>
    #|<div>
    #|  <ruby><rb>RB</rb></ruby>
    #|  <ruby><rtc>RTC</rtc></ruby>
    #|  <ruby><rbc>RBC</rbc></ruby>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let wrapper = root.children[0]
  let ruby_children : Array[@node.Node] = []
  for child in wrapper.children {
    if !child.id.has_prefix("#text") {
      ruby_children.push(child)
    }
  }
  guard ruby_children.length() >= 3 else {
    fail("wrapper should include three ruby children")
  }
  let ruby_rb = ruby_children[0]
  let ruby_rtc = ruby_children[1]
  let ruby_rbc = ruby_children[2]
  guard ruby_rb.children.length() > 0 else {
    fail("first ruby should include rb")
  }
  guard ruby_rtc.children.length() > 0 else {
    fail("second ruby should include rtc")
  }
  guard ruby_rbc.children.length() > 0 else {
    fail("third ruby should include rbc")
  }
  inspect(ruby_rb.children[0].style.display, content="Inline")
  inspect(ruby_rtc.children[0].style.display, content="Inline")
  inspect(ruby_rbc.children[0].style.display, content="Inline")
}

///|
test "ruby_with_rt_contain_size_text_only_collapses_own_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { overflow: hidden; position: absolute; }
    #|rt { contain: size; display: ruby-text; font-size: 1rem; }
    #|</style>
    #|<div><ruby><rt>PASS</rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[0]
  guard div.children.length() > 0 else { fail("div should include ruby child") }
  let ruby = div.children[0]
  guard ruby.children.length() > 0 else { fail("ruby should include rt child") }
  let rt = ruby.children[0]
  guard ruby.width == 0.0 else {
    fail("ruby with only ruby-text annotation should have zero width")
  }
  guard ruby.height == 0.0 else {
    fail("ruby with only ruby-text annotation should have zero height")
  }
  guard rt.width >= 30.0 else {
    fail("rt annotation should still keep intrinsic width")
  }
}

///|
test "ruby_with_rt_non_text_child_keeps_own_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.wrapper { display: inline-block; }
    #|rt { display: ruby-text; font-size: 2em; }
    #|.contained { width: 50px; height: 10px; position: fixed; top: 0; left: 0; }
    #|</style>
    #|<div class="wrapper"><ruby><rt>&emsp;<div class="contained"></div></rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let wrapper = layout.children[0]
  guard wrapper.children.length() > 0 else {
    fail("wrapper should include ruby child")
  }
  let ruby = wrapper.children[0]
  guard ruby.width > 0.0 else {
    fail("ruby should keep non-zero width when rt has non-text child")
  }
  guard ruby.height > 0.0 else {
    fail("ruby should keep non-zero height when rt has non-text child")
  }
}

///|
test "grouped_ruby_selector_applies_font_size_to_rt_and_rtc" {
  let grouped_stylesheet = @css.parse_stylesheet(
    "rb, rbc, rt, rtc { font-size: 2em; }",
  )
  inspect(grouped_stylesheet.rules.length(), content="4")
  inspect(grouped_stylesheet.rules[0].declarations.length(), content="1")
  inspect(grouped_stylesheet.rules[1].declarations.length(), content="1")
  inspect(grouped_stylesheet.rules[2].declarations.length(), content="1")
  inspect(grouped_stylesheet.rules[3].declarations.length(), content="1")
  let rt_selector = @css.Element::new("rt")
  let cascaded = @css.cascade_element(rt_selector, [grouped_stylesheet], [])
  inspect(cascaded.get_value("font-size"), content="Some(\"2em\")")

  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|rb, rbc, rt, rtc { font-size: 2em; }
    #|</style>
    #|<div><ruby><rb>RB</rb><rt>RT</rt><rtc>RTC</rtc></ruby></div>
  let doc = @html.parse_document(html_str)
  inspect(doc.stylesheets.length(), content="1")
  let extracted_stylesheet = @css.parse_stylesheet(doc.stylesheets[0])
  inspect(extracted_stylesheet.rules.length(), content="4")
  let cascaded_extracted = @css.cascade_element(
    rt_selector,
    [extracted_stylesheet],
    [],
  )
  inspect(cascaded_extracted.get_value("font-size"), content="Some(\"2em\")")

  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let div = root.children[0]
  let ruby = div.children[0]
  let mut rb_opt : @node.Node? = None
  let mut rt_opt : @node.Node? = None
  let mut rtc_opt : @node.Node? = None
  for child in ruby.children {
    if child.id == "rb" || child.id.has_prefix("rb#") {
      rb_opt = Some(child)
    } else if child.id == "rt" || child.id.has_prefix("rt#") {
      rt_opt = Some(child)
    } else if child.id == "rtc" || child.id.has_prefix("rtc#") {
      rtc_opt = Some(child)
    }
  }
  let rb = match rb_opt {
    Some(n) => n
    None => fail("ruby should include rb")
  }
  let rt = match rt_opt {
    Some(n) => n
    None => fail("ruby should include rt")
  }
  let rtc = match rtc_opt {
    Some(n) => n
    None => fail("ruby should include rtc")
  }
  inspect(rb.style.font_size, content="32")
  inspect(rt.style.font_size, content="32")
  inspect(rtc.style.font_size, content="32")
}

///|
test "empty_ruby_with_rt_layout_keeps_strut_height" {
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
    fail(
      "ruby with contain:layout ruby-text child should keep strut-like height",
    )
  }
}

///|
test "ruby_rt_contain_size_annotation_contributes_parent_box_size" {
  // Mirrors css-contain/contain-size-005.html expectation:
  // ruby own box can be 0, but annotation still contributes to parent box size.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|div { overflow: hidden; position: absolute; }
    #|rt { contain: size; display: ruby-text; font-size: 1rem; }
    #|</style>
    #|<p>This test passes if you can see the word PASS below.
    #|<div><ruby><rt>PASS</rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[1]
  guard div.width >= 30.0 else {
    fail("annotation-only ruby should still contribute inline-size to parent")
  }
  guard div.height >= 30.0 else {
    fail(
      "annotation-only ruby should still contribute line-height band to parent",
    )
  }
}

///|
test "ruby_internal_mixed_children_expand_inline_block_intrinsic_width" {
  // Mirrors css-contain/contain-paint-ignored-cases-ruby-stacking-and-clipping-001.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.group { display: inline-block; }
    #|rb { contain: paint; }
    #|.contained { width: 70px; height: 10px; margin-left: -25px; }
    #|</style>
    #|<div class="group"><ruby><rb>&emsp;<div class="contained"></div></rb></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let group = layout.children[0]
  guard group.width >= 60.0 else {
    fail(
      "inline-block width should include ruby mixed inline/block child progression",
    )
  }
}

///|
test "ruby_rt_with_non_text_child_keeps_annotation_band_above_base" {
  // Mirrors css-contain/contain-paint-ignored-cases-ruby-containing-block-001.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.wrapper { display: inline-block; }
    #|rt { contain: paint; display: ruby-text; font-size: 2em; }
    #|.contained { width: 50px; height: 10px; top: 0; left: 0; position: fixed; }
    #|</style>
    #|<div class="wrapper"><ruby><rt>&emsp;<div class="contained"></div></rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let wrapper = layout.children[0]
  let ruby = wrapper.children[0]
  guard wrapper.height >= 50.0 else {
    fail("wrapper should keep ruby annotation + baseline band height")
  }
  guard ruby.y >= 30.0 else {
    fail("ruby base box should sit below annotation band")
  }
}

///|
test "ruby_rt_after_pseudo_content_is_reflected_in_layout" {
  // Mirrors css-contain/contain-paint-008.html behavior.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|p { margin: 0; }
    #|rt {
    #|  contain: paint;
    #|  display: ruby-text;
    #|  font-size: 1rem;
    #|  font-family: monospace;
    #|}
    #|rt::after {
    #|  content: "PASS";
    #|  position: relative;
    #|  left: 4ch;
    #|}
    #|</style>
    #|<p>This test passes if you can see the word PASS below.
    #|<div><ruby><rt></rt></ruby></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let div = layout.children[1]
  let ruby = div.children[0]
  let rt = ruby.children[0]
  guard ruby.width == 0.0 else {
    fail(
      "annotation-only ruby with contain:paint rt should collapse ruby width",
    )
  }
  guard ruby.height == 0.0 else {
    fail(
      "annotation-only ruby with contain:paint rt should collapse ruby height",
    )
  }
  guard div.height >= 30.0 else {
    fail("rt::after generated text should contribute line box height")
  }
  guard rt.x >= 30.0 else {
    fail(
      "rt::after relative left offset should shift annotation inline position",
    )
  }
  guard rt.width >= 30.0 else {
    fail("rt::after generated text should contribute annotation width")
  }
}

///|
test "pseudo_before_after_default_inline_does_not_stack_list_item_lines" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|ol { margin: 0; padding: 0; list-style: none; }
    #|li::before, li::after { content: "1"; }
    #|</style>
    #|<ol><li>A</li><li>B</li></ol>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() > 0 else { fail("body should include ol") }
  let ol = layout.children[0]
  guard ol.children.length() >= 2 else { fail("ol should include two li") }
  let first = ol.children[0]
  let second = ol.children[1]
  guard first.height <= 24.0 else {
    fail(
      "inline pseudo content should not expand li into stacked 3-line height",
    )
  }
  guard second.y <= 24.0 else {
    fail("second li should start around one line-height below first li")
  }
}

///|
test "pseudo_is_selector_generates_before_after_on_ol_and_li" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|:is(ol, li, div)::before { content: "B"; }
    #|:is(ol, li, div)::after { content: "A"; }
    #|</style>
    #|<ol><li></li></ol>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let ol = root.children[0]
  inspect(ol.id, content="ol")
  inspect(ol.children.length(), content="3")
  let li = ol.children[1]
  inspect(li.id, content="li")
  inspect(li.children.length(), content="2")
}

///|
test "pseudo_content_css_escape_non_breaking_space_keeps_text_width" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-size: 50px; line-height: 1.2; font-family: monospace; }
    #|#test::after { content: "\a0"; }
    #|</style>
    #|<div id="test"></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  guard target.width >= 20.0 else {
    fail("escaped NBSP in pseudo content should create measurable inline width")
  }
}

///|
test "pseudo_empty_content_with_block_display_generates_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#target::before { content: ""; display: block; width: 30px; height: 20px; }
    #|#target::after { content: ""; display: block; width: 30px; height: 10px; }
    #|</style>
    #|<div id="target"></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  guard target.children.length() == 2 else {
    fail("before/after pseudo boxes should be materialized as generated nodes")
  }
  guard target.height >= 30.0 else {
    fail("generated pseudo boxes should contribute to host block-size")
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

  @node.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
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
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
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
  inspect(
    textarea.height,
    content=(
      #|0
    ),
  )
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
test "contain_size_button_inner_overflow_does_not_expand_inline_line_height" {
  // Regression for css-contain/contain-size-button-002.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|button {
    #|  contain: size;
    #|  margin: 0;
    #|  border: 1em solid green;
    #|  vertical-align: top;
    #|}
    #|.inner {
    #|  width: 100px;
    #|  height: 100px;
    #|  color: transparent;
    #|}
    #|</style>
    #|<button id="a"><div class="inner">inner</div></button>
    #|<br id="line">
    #|<button id="b"><div class="inner">inner</div></button>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let first = layout.children[0]
  let second = layout.children[2]
  inspect(first.height, content="28")
  guard second.y <= 40.0 else {
    fail("contain:size button line should not grow from inner overflow content")
  }
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
test "wpt_table_cell_overflow_auto_respects_max_width" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="width: 100px; height: 100px; border: solid;">
    #|  <div id="cell" style="display: table-cell; max-width: 100px; height: 100px; background: green; overflow-x: auto; vertical-align: top;">
    #|    <div style="width: 120px; height: 50px; background: hotpink;"></div>
    #|  </div>
    #|</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let wrapper = node.children[0]
  let cell = wrapper.children[0]
  inspect(cell.style.display, content="TableCell")
  inspect(cell.style.max_width, content="Length(100)")
  inspect(cell.style.height, content="Length(100)")

  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let container = layout.children[0]
  let laid_out_cell = container.children[0]
  inspect(laid_out_cell.width, content="100")
}

///|
test "wpt_table_cell_child_overflow_measure_keeps_explicit_height" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="cell" style="width: 100px; height: 100px; display: table-cell; background: green;">
    #|  <div id="scroller" style="overflow: auto; height: 100%;">
    #|    <div style="height: 200px;"></div>
    #|  </div>
    #|</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let cell = node.children[0]
  inspect(cell.style.display, content="TableCell")
  inspect(cell.style.height, content="Length(100)")

  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let laid_out_cell = layout.children[0]
  let scroller = laid_out_cell.children[0]
  inspect(laid_out_cell.height, content="100")
  inspect(scroller.height, content="100")
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
test "table omitted td end tags do not double last cell width with trailing indentation" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-spacing: 0; }
    #|td {
    #|  contain: size;
    #|  font-size: 50px;
    #|}
    #|</style>
    #|<table>
    #|  <tr>
    #|    <td>5<td>6<td>7<td>8
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  guard row.children.length() == 4 else {
    fail("row should keep four cells with omitted td end tags")
  }
  let first_width = row.children[0].width
  let last_width = row.children[3].width
  guard last_width <= first_width + 1.0 else {
    fail(
      "last cell should not include trailing indentation as extra text width",
    )
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
  inspect(
    anchor.height,
    content=(
      #|20
    ),
  )
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
  @node.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)

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

  @node.setup()
  let layout_ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = @node.compute_layout_in_context(root, layout_ctx)
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
  inspect(
    container.height,
    content=(
      #|100
    ),
  )
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
  inspect(
    span.height,
    content=(
      #|120
    ),
  )
  inspect(span.x, content="200")
}

///|
test "contain_layout_br_keeps_browser_like_baseline_offset" {
  // Regression for css-contain/contain-layout-ink-overflow-014.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#outer {
    #|  font-family: monospace;
    #|  font-size: 100px;
    #|  line-height: 1.5;
    #|  width: 4ch;
    #|  height: 2.8ch;
    #|  overflow: scroll;
    #|}
    #|#inner {
    #|  contain: layout;
    #|  height: 0;
    #|}
    #|</style>
    #|<div id="outer"><div id="inner">&nbsp;<br>FAIL</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  guard layout.children.length() >= 1 else {
    fail("body should include outer wrapper")
  }
  let outer = layout.children[0]
  guard outer.id == "div#outer" else {
    fail("first body child should be outer wrapper")
  }
  guard outer.children.length() >= 1 else {
    fail("outer wrapper should include contain:layout child")
  }
  let inner = outer.children[0]
  let mut br_y = -1.0
  for child in inner.children {
    if child.id == "br" {
      br_y = child.y
      break
    }
  }
  guard br_y >= 0.0 else { fail("inner should include br node") }
  guard br_y <= 30.0 else {
    fail(
      "br should stay near browser-like baseline offset under tall line-height",
    )
  }
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
  guard target_cell.height <= 125.0 else {
    fail("table cell height should stay close to normal line-height metrics")
  }
  inspect(span.height, content="120")
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
test "relative tfoot offset does not inflate parent auto height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-collapse: collapse; }
    #|td { padding: 0; }
    #|td > div { width: 50px; height: 50px; }
    #|.group { display: inline-block; position: relative; width: 150px; height: 200px; }
    #|.indicator { position: absolute; left: 0; top: 150px; width: 50px; height: 50px; background: red; }
    #|.relative { position: relative; top: 100px; background: green; }
    #|</style>
    #|<div class="group">
    #|  <div>
    #|    <div class="indicator"></div>
    #|    <table>
    #|      <tbody><tr><td><div></div></td></tr></tbody>
    #|      <tfoot class="relative"><tr><td><div></div></td></tr></tfoot>
    #|    </table>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let group = layout.children[0]
  let inner = group.children[0]
  let table = inner.children[1]
  inspect(inner.id, content="div")
  inspect(table.id, content="table")
  inspect(inner.height, content="100")
  inspect(table.height, content="100")
}

///|
test "relative tfoot abs child does not inflate parent auto height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|table { border-collapse: collapse; }
    #|td { padding: 0; }
    #|td > div { width: 50px; height: 50px; }
    #|.group { display: inline-block; position: relative; width: 150px; height: 200px; }
    #|.indicator { position: absolute; left: 0; top: 150px; width: 50px; height: 50px; background: red; }
    #|.relative { position: relative; top: 50px; background: white; }
    #|.absolute { position: absolute; top: 50px; background: green; }
    #|</style>
    #|<div class="group">
    #|  <div>
    #|    <div class="indicator"></div>
    #|    <table>
    #|      <tbody><tr><td><div></div></td></tr></tbody>
    #|      <tfoot class="relative">
    #|        <tr><td style="width:50px;height:50px"><div class="absolute"></div></td></tr>
    #|      </tfoot>
    #|    </table>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let group = layout.children[0]
  let inner = group.children[0]
  let table = inner.children[1]
  inspect(inner.id, content="div")
  inspect(table.id, content="table")
  inspect(inner.height, content="100")
  inspect(table.height, content="100")
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
  inspect(
    grid.height,
    content=(
      #|10000000000
    ),
  )
  inspect(
    grid_item.height,
    content=(
      #|10000000000
    ),
  )
  inspect(scroll_outer.height, content="100")
  inspect(
    scroll_inner.height,
    content=(
      #|10000000000
    ),
  )
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
  inspect(
    item.height,
    content=(
      #|10
    ),
  )
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
  inspect(
    layout.height,
    content=(
      #|16
    ),
  )
}

///|
test "scroll_snap_center_applies_initial_horizontal_offset" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.scroller {
    #|  width: 50px;
    #|  height: 50px;
    #|  overflow: hidden;
    #|  white-space: nowrap;
    #|  scroll-snap-type: x mandatory;
    #|  padding: 0 20px;
    #|  box-sizing: border-box;
    #|}
    #|.scroller > div {
    #|  display: inline-block;
    #|  width: 45px;
    #|  height: 45px;
    #|  margin: 5px;
    #|  box-sizing: border-box;
    #|  scroll-snap-align: center;
    #|}
    #|</style>
    #|<div class="scroller">
    #|  <div></div>
    #|  <div></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let node_tree = @renderer.render_to_node(html_str, ctx)
  let scroller_node = node_tree.children[0]
  let first_node = scroller_node.children[0]
  inspect(scroller_node.style.scroll_snap_type.axis, content="X")
  inspect(scroller_node.style.scroll_snap_type.strictness, content="Mandatory")
  inspect(first_node.style.scroll_snap_align_x, content="Center")
  inspect(first_node.style.scroll_snap_align_y, content="Center")

  let layout = @renderer.render(html_str, ctx)
  let scroller = layout.children[0]
  let first = scroller.children[0]

  inspect(scroller.width, content="50")
  inspect(first.x, content="2.5")
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
test "empty_body_root_with_html_viewport_styles_keeps_viewport_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html {
    #|  scrollbar-gutter: stable both-edges;
    #|  background-image: linear-gradient(to right, green, blue);
    #|}
    #|</style>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.height, content="600")
}

///|
test "frameset_root_without_content_keeps_viewport_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<frameset style="overflow:scroll"></frameset>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.height, content="600")
  let frameset = layout.children[0]
  inspect(frameset.id, content="frameset")
  inspect(frameset.height, content="600")
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
test "quirks_table_cell_inline_size_preserves_table_display_model" {
  let html_str =
    #|<!~quirks>
    #|<style>
    #|  td {
    #|    width: 50px;
    #|    padding: 10px;
    #|    border: 1px solid black;
    #|    box-sizing: border-box;
    #|  }
    #|</style>
    #|<table>
    #|  <tr><td>A</td></tr>
    #|</table>
  let ctx = @renderer.RenderContext::default()
  let node_root = @renderer.render_to_node(html_str, ctx)
  let mut table_node : @node.Node? = None
  for child in node_root.children {
    if child.id == "table" {
      table_node = Some(child)
      break
    }
  }
  let table = match table_node {
    Some(node) => node
    None => {
      inspect(false, content="table_node_not_found")
      return
    }
  }
  let tbody = table.children[0]
  let tr = tbody.children[0]
  let td = tr.children[0]
  inspect(table.style.display, content="Table")
  inspect(table.style.width, content="Auto")
  inspect(tbody.style.display, content="TableRowGroup")
  inspect(tr.style.display, content="TableRow")
  inspect(td.style.display, content="TableCell")

  let layout_root = @renderer.render(html_str, ctx)
  let mut table_layout : @types.Layout? = None
  for child in layout_root.children {
    if child.id == "table" {
      table_layout = Some(child)
      break
    }
  }
  let table_box = match table_layout {
    Some(node) => node
    None => {
      inspect(false, content="table_layout_not_found")
      return
    }
  }
  inspect(table_box.width, content="54")
}

///|
test "mixed_inline_and_table_child_keeps_table_shrink_width" {
  let html_str =
    #|<!doctype html>
    #|<a>Spec</a>
    #|<table><tr><td>A</td></tr></table>
  let ctx = @renderer.RenderContext::default()
  let layout_root = @renderer.render(html_str, ctx)
  let link = layout_root.children[0]
  let table = layout_root.children[1]

  inspect(link.id, content="a")
  inspect(
    link.width,
    content=(
      #|32
    ),
  )
  inspect(table.id, content="table")
  inspect(
    table.width,
    content=(
      #|12
    ),
  )
}

///|
test "wpt_visibility_collapse_border_spacing_002_layout" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|table#t {
    #|  border-spacing: 50px 100px;
    #|}
    #|td {
    #|  width: 100px;
    #|  padding: 0;
    #|}
    #|tr + tr {
    #|  visibility: collapse;
    #|}
    #|</style>
    #|<table id="t">
    #|  <tr><td rowspan="2"></td></tr>
    #|  <tr></tr>
    #|</table>
  let ctx = @renderer.RenderContext::default()
  let node_root = @renderer.render_to_node(html_str, ctx)
  let mut table_node : @node.Node? = None
  for child in node_root.children {
    if child.id == "table#t" {
      table_node = Some(child)
      break
    }
  }
  let table = match table_node {
    Some(node) => node
    None => {
      inspect(false, content="table_node_not_found")
      return
    }
  }
  let tbody = table.children[0]
  let collapsed_row = tbody.children[1]
  inspect(table.style.border_spacing, content="50")
  inspect(table.style.border_spacing_vertical, content="100")
  inspect(tbody.style.display, content="TableRowGroup")
  inspect(collapsed_row.style.visibility, content="Collapse")

  let layout_root = @renderer.render(html_str, ctx)
  let mut table_layout : @types.Layout? = None
  for child in layout_root.children {
    if child.id == "table#t" {
      table_layout = Some(child)
      break
    }
  }
  let table_box = match table_layout {
    Some(layout) => layout
    None => {
      inspect(false, content="table_layout_not_found")
      return
    }
  }
  inspect(table_box.height, content="200")
  inspect(table_box.children[0].height, content="0")
  inspect(table_box.children[0].children[1].y, content="0")
}

///|
test "overflow alignment table keeps sixth cell width in node and layout" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0 }
    #|th, td { padding: 0; }
    #|thead { display: table-footer-group; }
    #|.indicator { width: 72px; height: 72px; }
    #|.indicator > div { width: 24px; height: 24px; }
    #|.indicator > .tl, .indicator > .tc, .indicator > .cl, .indicator > .cc, .indicator > .bl, .indicator > .bc { float: left; }
    #|.indicator > .tr, .indicator > .cr, .indicator > .br { float: right; }
    #|.indicator > .cl, .indicator > .bl { clear: both; }
    #|.test { width: 24px; height: 24px; overflow: hidden; place-content: safe center; }
    #|</style>
    #|<table>
    #|  <thead><tr><th colspan="6">x</th></tr></thead>
    #|  <tbody>
    #|    <tr>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|      <td><div class="test"><div class="indicator"><div class="tl"></div><div class="tc"></div><div class="tr"></div><div class="cl"></div><div class="cc"></div><div class="cr"></div><div class="bl"></div><div class="bc"></div><div class="br"></div></div></div></td>
    #|    </tr>
    #|  </tbody>
    #|</table>
  let ctx = @renderer.RenderContext::default()
  let node_root = @renderer.render_to_node(html_str, ctx)
  let layout_root = @renderer.render(html_str, ctx)
  let table_node = node_root.children[0]
  let tbody_node = table_node.children[1]
  let target_cell_node = tbody_node.children[0].children[5]
  let target_test = tbody_node.children[0].children[5].children[0]
  inspect(target_cell_node.id, content="td")
  inspect(target_test.id, content="div.test")
  inspect(target_test.style.display, content="Block")
  inspect(target_test.style.width, content="Length(24)")
  inspect(target_test.style.height, content="Length(24)")

  let table_layout = layout_root.children[0]
  let tbody_layout = table_layout.children[1]
  let target_cell = tbody_layout.children[0].children[5]
  let target_test_layout = target_cell.children[0]
  inspect(target_cell.width, content="24")
  inspect(target_cell.height, content="24")
  inspect(target_test_layout.width, content="24")
  inspect(target_test_layout.height, content="24")
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
test "ua_default_h1_uses_larger_heading_metrics" {
  let html_str =
    #|<!doctype html>
    #|<style>html, body { margin: 0; padding: 0; }</style>
    #|<h1>Visibility collapse</h1>
    #|<a href="#">Spec</a>
  let ctx = @renderer.RenderContext::default()
  let layout_root = @renderer.render(html_str, ctx)
  let h1 = layout_root.children[0]
  let link = layout_root.children[1]
  guard h1.height > 30.0 else {
    fail("h1 should use larger UA heading metrics")
  }
  guard link.y > 50.0 else {
    fail("following inline content should be pushed by heading bottom margin")
  }
}

///|
test "ua_block_defaults_apply_margins_on_the_correct_axis" {
  let html_str =
    #|<!doctype html>
    #|<style>html, body { margin: 0; padding: 0; } div { width: 400px; }</style>
    #|<div>
    #|  <p>Paragraph</p>
    #|  <pre>Preformatted</pre>
    #|  <blockquote>Quoted</blockquote>
    #|</div>
  let layout_root = @renderer.render(
    html_str,
    @renderer.RenderContext::default(),
  )
  let wrapper = layout_root.children[0]
  let p = wrapper.children[0]
  let pre = wrapper.children[1]
  let quote = wrapper.children[2]

  inspect(p.x, content="0")
  inspect(pre.x, content="0")
  inspect(quote.x, content="40")
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

///|
test "wpt_intrinsic_percent_replaced_019_like_abspos_flex_basis_content_uses_definite_cross_chain" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer { width: 500px; }
    #|.abspos-cb {
    #|  position: relative;
    #|  height: 0;
    #|  width: 0;
    #|  padding: 9%;
    #|  border: 5px solid green;
    #|}
    #|.flex-container {
    #|  height: 100%;
    #|  width: 100%;
    #|  position: absolute;
    #|  display: flex;
    #|  border: 5px solid green;
    #|  box-sizing: border-box;
    #|  top: 0;
    #|  left: 0;
    #|}
    #|.item {
    #|  border: 5px solid green;
    #|  height: 100%;
    #|  flex-basis: content;
    #|  box-sizing: border-box;
    #|}
    #|canvas {
    #|  width: 100%;
    #|  height: 100%;
    #|  border: 5px solid green;
    #|  background: green;
    #|  box-sizing: border-box;
    #|}
    #|</style>
    #|<div class="outer">
    #|  <div class="abspos-cb">
    #|    <div class="flex-container">
    #|      <div class="item">
    #|        <canvas width="10" height="10"></canvas>
    #|      </div>
    #|    </div>
    #|  </div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let outer = root.children[0]
  let abspos_cb = outer.children[0]
  let flex = abspos_cb.children[0]
  let item = flex.children[0]
  let canvas = item.children[0]
  inspect(flex.style.width, content="Percent(1)")
  inspect(flex.style.height, content="Percent(1)")
  inspect(item.style.height, content="Percent(1)")
  inspect(canvas.style.width, content="Percent(1)")
  inspect(canvas.style.height, content="Percent(1)")
  inspect(canvas.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let laid_out_outer = layout.children[0]
  let laid_out_abspos_cb = laid_out_outer.children[0]
  let laid_out_flex = laid_out_abspos_cb.children[0]
  let laid_out_item = laid_out_flex.children[0]
  let laid_out_canvas = laid_out_item.children[0]
  inspect(laid_out_abspos_cb.width, content="100")
  inspect(laid_out_flex.width, content="90")
  inspect(laid_out_flex.height, content="90")
  inspect(laid_out_item.width, content="80")
  inspect(laid_out_item.height, content="80")
  inspect(laid_out_canvas.width, content="70")
  inspect(laid_out_canvas.height, content="70")
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
test "wpt_intrinsic_percent_replaced_dynamic_005_like_abspos_auto_height_tracks_canvas" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="position: relative; width: 100px; height: 100px;">
    #|  <div id="target" style="position: absolute; top:0; background: green;">
    #|    <canvas width="1" height="1" style="height: 100%;"></canvas>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let canvas = target.children[0]
  inspect(target.height, content="1")
  inspect(canvas.y, content="0")
  inspect(canvas.height, content="1")
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

///|
test "html_abspos_root_keeps_html_as_layout_root" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html {
    #|  display: flex;
    #|  position: absolute;
    #|  left: 10px;
    #|  right: 20px;
    #|  top: 30px;
    #|  bottom: 40px;
    #|  border: 5px solid black;
    #|  box-sizing: border-box;
    #|}
    #|body { margin: 0; }
    #|</style>
    #|<body>root abs test</body>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  inspect(layout.id, content="html")
  guard (layout.width - 770.0).abs() < 0.01 else {
    fail("absolute-positioned html root width should honor left/right insets")
  }
  guard (layout.height - 530.0).abs() < 0.01 else {
    fail("absolute-positioned html root height should honor top/bottom insets")
  }
  let body = layout.children[0]
  inspect(body.id, content="body")
  guard body.height > 500.0 else {
    fail("body should stretch in cross-axis inside html:flex container")
  }
}

///|
test "html_fixed_root_keeps_html_as_layout_root" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html {
    #|  display: grid;
    #|  position: fixed;
    #|  left: 10px;
    #|  right: 20px;
    #|  top: 30px;
    #|  bottom: 40px;
    #|  border: 5px solid black;
    #|  box-sizing: border-box;
    #|}
    #|body { margin: 0; }
    #|</style>
    #|<body>root fixed test</body>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  inspect(layout.id, content="html")
  guard (layout.width - 770.0).abs() < 0.01 else {
    fail("fixed-positioned html root width should honor left/right insets")
  }
  guard (layout.height - 530.0).abs() < 0.01 else {
    fail("fixed-positioned html root height should honor top/bottom insets")
  }
  let body = layout.children[0]
  inspect(body.id, content="body")
  guard body.height > 500.0 else {
    fail("body should stretch in cross-axis inside html:grid container")
  }
}

///|
test "abspos_canvas_display_table_respects_explicit_css_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#wrap { position: relative; }
    #|canvas {
    #|  position: absolute;
    #|  display: table;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div id="wrap"><canvas width="200"></canvas></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let node_wrap = node.children[0]
  let node_canvas = node_wrap.children[0]
  inspect(node_canvas.style.width, content="Length(100)")
  inspect(node_canvas.style.height, content="Length(100)")
  let wrap = layout.children[0]
  let canvas = wrap.children[0]
  inspect(canvas.id, content="canvas")
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
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
test "cellpadding_attribute_sets_cell_padding" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<table cellpadding="10"><tr><td>test</td></tr></table>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  fn find_td(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("td") {
      return Some(n)
    }
    for child in n.children {
      match find_td(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
  match find_td(node) {
    Some(td) => {
      inspect(
        td.style.padding.top,
        content=(
          #|Length(10)
        ),
      )
      inspect(
        td.style.padding.left,
        content=(
          #|Length(10)
        ),
      )
    }
    None => inspect(false, content="td not found")
  }
}

///|
test "nested_table_cell_height_ignores_surrounding_whitespace" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body {
    #|  margin: 0;
    #|  font-family: Verdana, Geneva, sans-serif;
    #|  font-size: 10pt;
    #|  color: #828282;
    #|}
    #|td {
    #|  font-family: Verdana, Geneva, sans-serif;
    #|  font-size: 10pt;
    #|  color: #828282;
    #|}
    #|.pagetop {
    #|  font-family: Verdana, Geneva, sans-serif;
    #|  font-size: 10pt;
    #|  color: #222;
    #|  line-height: 12px;
    #|}
    #|.hnname { margin-left: 1px; margin-right: 5px; }
    #|a:link { color: #000; text-decoration: none; }
    #|</style>
    #|<table id="hnmain" border="0" cellpadding="0" cellspacing="0" width="85%" bgcolor="#f6f6ef">
    #|  <tbody>
    #|    <tr id="outer-row">
    #|      <td id="outer-cell" bgcolor="#ff6600">
    #|        <table id="inner" border="0" cellpadding="0" cellspacing="0" width="100%" style="padding:2px">
    #|          <tbody>
    #|            <tr id="inner-row">
    #|              <td id="logo" style="width:18px;padding-right:4px">
    #|                <a><img src="missing.svg" width="18" height="18" style="border:1px white solid;display:block"></a>
    #|              </td>
    #|              <td id="nav" style="line-height:12pt;height:10px">
    #|                <span class="pagetop"><b class="hnname"><a>Hacker News</a></b><a>new</a> | <a>past</a></span>
    #|              </td>
    #|              <td id="login" style="text-align:right;padding-right:4px">
    #|                <span class="pagetop"><a>login</a></span>
    #|              </td>
    #|            </tr>
    #|          </tbody>
    #|        </table>
    #|      </td>
    #|    </tr>
    #|  </tbody>
    #|</table>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let outer_row = tbody.children[0]
  let outer_cell = outer_row.children[0]
  let inner_table = outer_cell.children[0]
  let inner_tbody = inner_table.children[0]
  let inner_row = inner_tbody.children[0]
  inspect(table.height, content="22")
  inspect(outer_row.height, content="22")
  inspect(outer_cell.height, content="22")
  inspect(inner_table.height, content="22")
  inspect(inner_row.height, content="18")
}

///|
test "empty_td_has_zero_content_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td></td><td>text</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let empty_td = row.children[0]
  let text_td = row.children[1]
  inspect(empty_td.id, content="td")
  inspect(text_td.id, content="td")
  // The text td has content so its height is determined by text metrics.
  // The empty td should have zero content height and not inflate the row.
  // Row height should be driven entirely by the text td.
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    empty_td.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "all_empty_td_row_has_zero_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td></td><td></td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let td1 = row.children[0]
  let td2 = row.children[1]
  // In Chrome, a row with only empty tds has height 0.
  inspect(
    row.height,
    content=(
      #|0
    ),
  )
  inspect(
    td1.height,
    content=(
      #|0
    ),
  )
  inspect(
    td2.height,
    content=(
      #|0
    ),
  )
}

///|
test "empty_td_with_colspan_has_zero_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td colspan="2"></td><td>text</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let colspan_td = row.children[0]
  let text_td = row.children[1]
  // Row height should be driven by the text cell only
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    colspan_td.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
fn node_id_matches_tag(node_id : String, tag : String) -> Bool {
  node_id == tag ||
  node_id.has_prefix(tag + "#") ||
  node_id.has_prefix(tag + ".")
}

///|
fn find_node_by_tag_id(node : @node.Node, tag : String) -> @node.Node? {
  if node_id_matches_tag(node.id, tag) {
    return Some(node)
  }
  for child in node.children {
    match find_node_by_tag_id(child, tag) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn find_text_node_by_content(node : @node.Node, text : String) -> @node.Node? {
  match node.text {
    Some(content) if content == text => return Some(node)
    _ => ()
  }
  for child in node.children {
    match find_text_node_by_content(child, text) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
test "empty_td_with_line_height_has_zero_content_height" {
  // Test that an empty td does not get inflated by line-height
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0;line-height:40px}table{border-spacing:0}td{padding:0}</style>
    #|<table>
    #|  <tr>
    #|    <td></td>
    #|    <td></td>
    #|  </tr>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  // In Chrome, a row with only empty tds has height 0
  // even when line-height is large
  inspect(
    row.height,
    content=(
      #|0
    ),
  )
}

///|
test "whitespace_only_td_has_zero_content_height" {
  // HTML with whitespace inside td tags (from indentation)
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0;line-height:40px}table{border-spacing:0}td{padding:0}</style>
    #|<table>
    #|  <tr>
    #|    <td>   </td>
    #|    <td>text</td>
    #|  </tr>
    #|</table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let ws_td = row.children[0]
  // Whitespace-only text in a td is collapsed to a single space,
  // but it's still text content so it participates in line-height.
  // Row height is 19.2 driven by the text cell (line-height:40px would be 40
  // if the whitespace cell contributed, but create_text_node collapses it
  // to a leaf since parent display is TableCell).
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    ws_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "empty_td_does_not_inflate_row_with_large_line_height" {
  // Key test: empty td with large line-height should NOT inflate row height
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0;line-height:40px}table{border-spacing:0}td{padding:0}</style>
    #|<table><tr><td></td><td>x</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let empty_td = row.children[0]
  let text_td = row.children[1]
  // Row height = 19.2 (= 16 * 1.2). The line-height:40px on body
  // appears to not propagate to the table cell's text metric height.
  // This is a separate issue from empty-td inflation.
  // For the empty-td issue, the key fact is: empty td = 0 content height.
  inspect(
    row.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    empty_td.height,
    content=(
      #|19.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "empty_td_cellpadding_does_not_inflate_row" {
  // With cellpadding, empty td should still have zero content,
  // but padding is added around the zero content
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body{margin:0}</style>
    #|<table cellpadding="10" cellspacing="0"><tr><td></td><td>x</td></tr></table>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let table = layout.children[0]
  let tbody = table.children[0]
  let row = tbody.children[0]
  let empty_td = row.children[0]
  let text_td = row.children[1]
  // In Chrome, empty td with cellpadding=10 has height = 20 (just padding)
  // text td has height = 19.2 (text) + 20 (padding) = 39.2
  // Row height = max(20, 39.2) = 39.2
  inspect(
    row.height,
    content=(
      #|39.2
    ),
  )
  inspect(
    empty_td.height,
    content=(
      #|39.2
    ),
  )
  inspect(
    text_td.height,
    content=(
      #|39.2
    ),
  )
}

///|
test "ua_text_decoration_applies_to_semantic_inline_tags" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<body>
    #|  <a href="#">link</a>
    #|  <u>underline</u>
    #|  <s>strike</s>
    #|</body>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  match find_node_by_tag_id(node, "a") {
    Some(a) => inspect(a.style.text_decoration_underline, content="true")
    None => inspect(false, content="a not found")
  }
  match find_text_node_by_content(node, "underline") {
    Some(u_text) =>
      inspect(u_text.style.text_decoration_underline, content="true")
    None => inspect(false, content="u text not found")
  }
  match find_text_node_by_content(node, "strike") {
    Some(s_text) =>
      inspect(s_text.style.text_decoration_line_through, content="true")
    None => inspect(false, content="s text not found")
  }
}

///|
test "text_decoration_none_overrides_ua_underline" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|a { text-decoration: none; }
    #|</style>
    #|<a href="#">no underline</a>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  match find_node_by_tag_id(node, "a") {
    Some(a) => inspect(a.style.text_decoration_underline, content="false")
    None => inspect(false, content="a not found")
  }
}

///|
test "link_color_overridden_by_css" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|a:link { color: #000000; }
    #|</style>
    #|<a href="#">black link</a>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  fn find_a(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("a") {
      return Some(n)
    }
    for child in n.children {
      match find_a(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
  match find_a(node) {
    Some(a) => {
      // CSS a:link { color: #000 } should override UA blue (#0000ee)
      inspect(a.style.color.r, content="0")
      inspect(a.style.color.g, content="0")
      inspect(a.style.color.b, content="0")
    }
    None => inspect(false, content="a not found")
  }
}

///|
test "letter_spacing_applied_to_text_measure" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|p { letter-spacing: 2px; font-size: 16px; }
    #|</style>
    #|<p>hello</p>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  fn find_p(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("p") {
      return Some(n)
    }
    for child in n.children {
      match find_p(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
  match find_p(node) {
    Some(p) => inspect(p.style.letter_spacing, content="2")
    None => inspect(false, content="p not found")
  }
}

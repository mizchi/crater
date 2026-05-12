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
test "color_scheme_dark_resolves_light_dark_background" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.panel { color-scheme: dark; background-color: light-dark(#f7f7f8, #212426); }
    #|</style>
    #|<div class="panel">Panel</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let panel = root.children[0]
  inspect(panel.style.background_color.to_hex(), content="#212426")
}

///|
test "color_scheme_dark_inherits_to_light_dark_child_background" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.theme { color-scheme: dark; }
    #|.child { background-color: light-dark(#ffffff, #18191b); }
    #|</style>
    #|<section class="theme"><div class="child">Child</div></section>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let child = root.children[0].children[0]
  inspect(child.style.background_color.to_hex(), content="#18191b")
}

///|
test "css_variable_dark_toggle_inherits_from_root" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|:root {
    #|  --color-gray-10: #212426;
    #|  --color-gray-90: #f7f7f8;
    #|  --csstools-color-scheme--light: initial;
    #|  --toggle: var(--csstools-color-scheme--light) var(--color-gray-10);
    #|  --color-background-primary: var(--toggle, var(--color-gray-90));
    #|}
    #|.homepage--dark {
    #|  --csstools-color-scheme--light: ;
    #|  background-color: var(--color-background-primary);
    #|  color-scheme: dark;
    #|}
    #|</style>
    #|<main class="homepage--dark">Home</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let home = root.children[0]
  inspect(home.style.background_color.to_hex(), content="#212426")
}

///|
test "double_hyphen_class_selector_matches" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.homepage--dark { background-color: #212426; color: #ffffff; }
    #|</style>
    #|<main class="homepage homepage--dark">Home</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let home = root.children[0]
  inspect(home.style.background_color.to_hex(), content="#212426")
  inspect(home.style.color.to_hex(), content="#ffffff")
}

///|
test "mdn_color_scheme_fallback_rules_resolve_dark_background" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html { --csstools-color-scheme--light: initial; color-scheme: light dark; }
    #|:root {
    #|  --csstools-light-dark-toggle-5e0f49fc-1: var(--csstools-color-scheme--light) var(--color-gray-10);
    #|  --color-background-primary: var(--csstools-light-dark-toggle-5e0f49fc-1,var(--color-gray-90));
    #|}
    #|@supports (color:light-dark(red,red)) {
    #|  :root { --color-background-primary: light-dark(var(--color-gray-90),var(--color-gray-10)); }
    #|}
    #|:root {
    #|  --color-gray-90: #f7f7f8;
    #|  --color-gray-10: #212426;
    #|}
    #|.homepage--dark {
    #|  --csstools-color-scheme--light: ;
    #|  background-color: var(--color-background-primary);
    #|  color-scheme: dark;
    #|}
    #|</style>
    #|<main class="homepage homepage--dark">Home</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let home = root.children[0]
  inspect(home.style.background_color.to_hex(), content="#212426")
}

///|
test "mdn_a11y_menu_calc_offset_resolves_offscreen" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.a11y-menu {
    #|  --offset: 20em;
    #|  left: 2px;
    #|  position: absolute;
    #|  top: calc(var(--offset)*-1);
    #|}
    #|</style>
    #|<ul class="a11y-menu"><li><a href="#main">Skip</a></li></ul>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let menu = root.children[0]
  inspect(menu.style.inset.top, content="Length(-320)")
}

///|
test "empty_inline_custom_element_between_blocks_does_not_add_line_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|header { line-height: 32px; }
    #|nav { display: block; height: 40px; }
    #|mdn-search-modal { display: inline; }
    #|.breadcrumbs { display: block; height: 30px; }
    #|</style>
    #|<header><nav></nav><mdn-search-modal></mdn-search-modal><div class="breadcrumbs"></div></header>
  let (_node, layout) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let header = layout.children[0]
  inspect(header.height, content="70")
}

///|
test "whitespace_inline_custom_element_between_blocks_does_not_add_line_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|header { line-height: 32px; }
    #|nav { display: block; height: 40px; }
    #|mdn-search-modal { display: inline; }
    #|.breadcrumbs { display: block; height: 30px; }
    #|</style>
    #|<header>
    #|  <nav></nav>
    #|  <mdn-search-modal></mdn-search-modal>
    #|  <div class="breadcrumbs"></div>
    #|</header>
  let (_node, layout) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let header = layout.children[0]
  inspect(header.height, content="70")
}

///|
test "mixed_block_parent_ignores_overflowing_descendants_of_fixed_height_child" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|header { line-height: 32px; }
    #|nav { display: grid; height: 46.4px; overflow: visible; }
    #|nav > div { height: 90.4px; }
    #|mdn-search-modal { display: inline; }
    #|.breadcrumbs { display: flex; height: 32px; }
    #|</style>
    #|<header>
    #|  <nav><div></div></nav>
    #|  <mdn-search-modal></mdn-search-modal>
    #|  <div class="breadcrumbs"></div>
    #|</header>
  let (_node, layout) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let header = layout.children[0]
  inspect(header.height, content="78.4")
}

///|
test "apple_system_normal_line_height_matches_browser_component_metrics" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body {
    #|  margin: 0;
    #|  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    #|  font-size: 14px;
    #|}
    #|.alert { padding: 12px 16px; }
    #|.title { font-size: 1rem; margin-bottom: 4px; }
    #|.desc { font-size: 0.875rem; }
    #|</style>
    #|<div class="alert"><div class="title">Error</div><div class="desc">Something went wrong.</div></div>
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(node.style.font_family, content="-apple-system")
  inspect(node.style.line_height, content="17")
  let node_alert = node.children[0]
  inspect(node_alert.style.font_family, content="-apple-system")
  inspect(node_alert.style.line_height, content="17")
  inspect(node_alert.children[0].style.line_height, content="18")
  inspect(node_alert.children[1].style.line_height, content="17")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let alert = layout.children[0]
  inspect(alert.height, content="63")
  inspect(alert.children[0].height, content="18")
  inspect(alert.children[1].height, content="17")
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
  inspect(second.y < 10.0, content="true")
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
  inspect(anchor.height, content="24")
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
  inspect(container.height, content="120")
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
  inspect(layout.height < ctx.viewport_height, content="true")
  inspect(
    layout.height,
    content=(
      #|19.2
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
test "body child percent height stays auto when body height is indefinite" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  body { margin: 0; min-height: 100vh; }
    #|  #page {
    #|    display: flex;
    #|    flex-direction: column;
    #|    height: 100%;
    #|    min-height: 100vh;
    #|    overflow: clip;
    #|  }
    #|  #content { height: 1200px; }
    #|</style>
    #|<div id="page"><div id="content"></div></div>
  let ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @renderer.render(html_str, ctx)
  let page = layout.children[0]
  let content = page.children[0]
  inspect(page.id, content="div#page")
  inspect(content.height, content="1200")
  guard page.height > 1100.0 else {
    fail(
      "height:100% child under indefinite body height should use content height",
    )
  }
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
fn node_text_contains(node : @node.Node, needle : String) -> Bool {
  match node.text {
    Some(content) if content.contains(needle) => return true
    _ => ()
  }
  for child in node.children {
    if node_text_contains(child, needle) {
      return true
    }
  }
  false
}

///|
test "render_to_node skips body style text in inline collection" {
  let html_str =
    #|<!DOCTYPE html>
    #|<div id="wrap"><style>[data-mask]{visibility:hidden!important}</style><span>ok</span></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(node_text_contains(root, "[data-mask]"), content="false")
  inspect(node_text_contains(root, "ok"), content="true")
}

///|
test "render_to_node does not fallback-match descendant pseudo selector on body substring" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>.markdown-body [data-footnote-ref]::before { content: "["; }</style>
    #|<div>ok</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(node_text_contains(root, "["), content="false")
  inspect(node_text_contains(root, "ok"), content="true")
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

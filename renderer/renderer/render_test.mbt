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
  inspect(second.y < 10.0, content="true")
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
  inspect(anchor.height, content="24")
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

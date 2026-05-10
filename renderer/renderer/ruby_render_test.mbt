///|
// Ruby layout renderer regression tests split from render_test.mbt.

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

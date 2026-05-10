///|
// Generated content and pseudo-element renderer regression tests split from
// render_test.mbt.

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
      #|19.2
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
      #|19.2
    ),
  )
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

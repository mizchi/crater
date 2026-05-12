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
  debug_inspect(text_paint.text, content="Some(\"abcde...\")")
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
  debug_inspect(text_paint.text, content="Some(\"abcde...\")")
  inspect(text_paint.width, content="64")
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

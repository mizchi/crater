///|
// display: contents renderer regression tests split from render_test.mbt and
// renderer_test.mbt.

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
test "display_contents keeps inline parent shrink-to-fit and preserves child span" {
  let html =
    #|<!DOCTYPE html>
    #|<meta charset="utf-8">
    #|<style>
    #|#contents {
    #|  display: contents;
    #|}
    #|</style>
    #|<p>You should see the word PASS and no red below.</p>
    #|<span>
    #|  P<div id="contents">A<span>S</span></div>S
    #|</span>
  let ctx = @renderer.RenderContext::default()
  let node_tree = @renderer.render_to_node(html, ctx)
  let span_node = node_tree.children[1]
  inspect(span_node.id, content="span")
  inspect(span_node.children.length(), content="3")
  inspect(span_node.children[1].id, content="div#contents")
  inspect(
    span_node.children[1].children.length(),
    content=(
      #|1
    ),
  )
  inspect(
    span_node.children[1].children[0].id,
    content=(
      #|#text
    ),
  )

  let layout = @renderer.render(html, ctx)

  let inline_parent = layout.children[1]
  inspect(inline_parent.id, content="span")
  inspect(inline_parent.width < 200.0, content="true")

  fn find_child(
    children : Array[@types.Layout],
    id : String,
  ) -> @types.Layout? {
    for child in children {
      if child.id == id {
        return Some(child)
      }
    }
    None
  }

  match find_child(inline_parent.children, "div#contents") {
    Some(contents_layout) => {
      inspect(contents_layout.width, content="0")
      inspect(contents_layout.height, content="0")
      inspect(
        contents_layout.children.length(),
        content=(
          #|1
        ),
      )
      inspect(contents_layout.children[0].id, content="#text")
    }
    None => fail("div#contents layout not found")
  }
}

///|
test "display_contents text contributes to flex item intrinsic width" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|  .flex { display: flex; }
    #|  .inline { display: inline; }
    #|  .contents { display: contents; }
    #|</style>
    #|<div class="flex">
    #|  <div class="inline"><div class="contents">4</div></div>
    #|  <div><div class="contents">5a</div></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  let flex = layout.children[0]
  inspect(flex.id, content="div.flex")
  inspect(flex.children.length(), content="2")
  inspect(flex.children[0].id, content="div.inline")
  inspect(flex.children[1].id, content="div")
  inspect(flex.children[0].width, content="8")
  inspect(flex.children[1].width, content="16")
}

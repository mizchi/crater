///|
// Content flow renderer regression tests split from renderer_test.mbt.

///|
test "debug_text_wrapping_in_narrow_container" {
  let html =
    #|<div style="width: 100px">
    #|This is a long text that should wrap within the container width
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let container = layout.children[0]
  inspect(container.width, content="100")
  inspect(container.children.length() > 0, content="true")
  if container.children.length() > 0 {
    let text_layout = container.children[0]
    inspect(text_layout.width <= 100.0, content="true")
    inspect(text_layout.height > 50.0, content="true")
  }
}

///|
test "debug_mixed_inline_block_content" {
  let html =
    #|<div style="width: 300px">
    #|<p>This is paragraph one with some long text content.</p>
    #|<p>This is paragraph two with more long text content that needs to wrap.</p>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let container = layout.children[0]
  inspect(container.width, content="300")
  inspect(container.children.length(), content="2")
  if container.children.length() >= 2 {
    let p1 = container.children[0]
    let p2 = container.children[1]
    inspect(p2.y > p1.y, content="true")
    let p1_bottom = p1.y + p1.height
    let overlap = p1_bottom > p2.y
    inspect(overlap, content="false")
  }
}

///|
test "debug_heading_text_rendering" {
  let html = "<h1>Signal Boosting</h1>"

  let doc = @html.parse_document(html)
  fn find_h1(elem : @html.Element) -> @html.Element? {
    if elem.tag == "h1" {
      return Some(elem)
    }
    for child in elem.children {
      match child {
        @html.Node::Element(child_elem) =>
          match find_h1(child_elem) {
            Some(h1) => return Some(h1)
            None => ()
          }
        @html.Node::Text(_) => ()
      }
    }
    None
  }

  match find_h1(doc.root) {
    Some(h1) => {
      inspect(h1.tag, content="h1")
      inspect(h1.children.length(), content="1")
      if h1.children.length() > 0 {
        match h1.children[0] {
          @html.Node::Text(text) => inspect(text, content="Signal Boosting")
          @html.Node::Element(e) => inspect(e.tag, content="")
        }
      }
    }
    None => inspect("h1 not found", content="")
  }

  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let mut h1_found = false
  for child in node.children {
    if child.id == "h1" {
      h1_found = true
      inspect(child.children.length(), content="1")
    }
  }
  inspect(h1_found, content="true")
}

///|
test "debug_h2_with_anchor" {
  let html = "<h2><a href=\"#\">Link Text in H2</a></h2>"
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let h2 = node.children[0]
  inspect(h2.id, content="h2")
  inspect(h2.children.length(), content="1")
  if h2.children.length() > 0 {
    let text = h2.children[0]
    inspect(text.id, content="a")
  }
}

///|
test "debug_inline_text_with_block_sibling" {
  let html =
    #|<div style="width: 200px">
    #|Welcome to the site
    #|<p style="margin: 0">This is a paragraph</p>
    #|More text after the paragraph
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let container = layout.children[0]
  inspect(container.width, content="200")
  for i = 0; i < container.children.length() - 1; i = i + 1 {
    let child = container.children[i]
    let next = container.children[i + 1]
    let child_bottom = child.y + child.height
    let overlap = child_bottom > next.y
    assert_true(
      !overlap,
      msg="Children " +
        i.to_string() +
        " and " +
        (i + 1).to_string() +
        " overlap: " +
        child_bottom.to_string() +
        " > " +
        next.y.to_string(),
    )
  }
}

///|
test "tall_content_scrollability" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; padding: 16px; }
    #|h1 { font-size: 32px; margin: 16px 0; }
    #|h2 { font-size: 24px; margin: 12px 0; }
    #|p { font-size: 16px; line-height: 1.6; margin: 12px 0; }
    #|pre { background: #f5f5f5; padding: 16px; margin: 16px 0; }
    #|code { font-size: 14px; }
    #|</style>
    #|</head>
    #|<body>
    #|<article>
    #|  <h1>MoonBit Useful Tips</h1>
    #|  <p>This is the introduction paragraph with some content about MoonBit programming language and its features.</p>
    #|
    #|  <h2>Section 1: Getting Started</h2>
    #|  <p>First paragraph of section one with detailed explanation of the topic. This text should be long enough to wrap multiple lines in a narrow viewport.</p>
    #|  <pre><code>fn main() {
    #|      #|}</code></pre>
    #|  <p>Additional explanation after the code block explaining what the code does and how it works in practice.</p>
    #|
    #|  <h2>Section 2: Advanced Features</h2>
    #|  <p>Second section with more advanced content. This paragraph contains detailed technical information.</p>
    #|  <pre><code>struct Point {
    #|  x: Int
    #|  y: Int
    #|}
    #|
    #|fn Point::new(x: Int, y: Int) -> Point {
    #|  { x, y }
    #|}</code></pre>
    #|  <p>Explanation of structs and methods in MoonBit with examples and best practices.</p>
    #|
    #|  <h2>Section 3: Pattern Matching</h2>
    #|  <p>Pattern matching is a powerful feature in MoonBit that allows you to match values against patterns.</p>
    #|  <pre><code>fn describe(opt: Int?) -> String {
    #|  match opt {
    #|    Some(n) => "Has value: " + n.to_string()
    #|    None => "No value"
    #|  }
    #|}</code></pre>
    #|  <p>More details about pattern matching and its various use cases in real applications.</p>
    #|
    #|  <h2>Section 4: Error Handling</h2>
    #|  <p>Error handling in MoonBit uses Result types for explicit error management.</p>
    #|  <p>This approach ensures that errors are handled at compile time rather than runtime.</p>
    #|
    #|  <h2>Conclusion</h2>
    #|  <p>MoonBit provides a modern approach to systems programming with safety and performance.</p>
    #|  <p>Thank you for reading this article. Feel free to explore more resources.</p>
    #|</article>
    #|</body>
    #|</html>

  let viewport_width = 320.0
  let viewport_height = 200.0
  let ctx : @renderer.RenderContext = {
    viewport_width,
    viewport_height,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)

  inspect(layout.height > viewport_height, content="true")
  let min_expected_height = viewport_height * 2.0
  inspect(layout.height > min_expected_height, content="true")
  let scrollable_height = layout.height - viewport_height
  inspect(scrollable_height > 0.0, content="true")
  let font_height = 16.0
  let max_scroll_chars = ((layout.height - viewport_height) / font_height).to_int()
  inspect(max_scroll_chars > 0, content="true")
}

///|
/// Tests for HTML5 TreeBuilder

///|
/// Helper to find body element in parsed tree
fn find_body_v2(elem : @html.Element) -> @html.Element {
  // If the element is body, return it
  if elem.tag == "body" {
    return elem
  }
  // If the element is html, look for body child
  if elem.tag == "html" {
    for child in elem.children {
      match child {
        @html.Node::Element(e) => if e.tag == "body" { return e }
        _ => ()
      }
    }
  }
  // Return a dummy body if not found
  elem
}

///|
test "tree_builder/simple text" {
  let html = "Test"
  let result = @html.parse_fragment_v2(html)
  inspect(result.tag, content="html")
  let body = find_body_v2(result)
  inspect(body.tag, content="body")
  inspect(body.children.length() >= 1, content="true")
}

///|
test "tree_builder/simple element" {
  let html = "<div>Hello</div>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    _ => ()
  }
}

///|
test "tree_builder/nested elements" {
  let html = "<div><span>Hello</span></div>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  match body.children[0] {
    @html.Node::Element(div) => {
      inspect(div.tag, content="div")
      match div.children[0] {
        @html.Node::Element(span) => inspect(span.tag, content="span")
        _ => ()
      }
    }
    _ => ()
  }
}

///|
test "tree_builder/table basic" {
  let html = "<table><tr><td>Cell</td></tr></table>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    _ => ()
  }
}

///|
test "tree_builder/heading implicit close" {
  let html = "<h1>First<h2>Second"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // Should have 2 children: h1 and h2
  let mut h1_found = false
  let mut h2_found = false
  for child in body.children {
    match child {
      @html.Node::Element(e) =>
        if e.tag == "h1" {
          h1_found = true
        } else if e.tag == "h2" {
          h2_found = true
        }
      _ => ()
    }
  }
  inspect(h1_found, content="true")
  inspect(h2_found, content="true")
}

///|
test "tree_builder/void elements" {
  let html = "<br><hr><img>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // Check that void elements are self-closing
  let mut br_found = false
  let mut hr_found = false
  let mut img_found = false
  for child in body.children {
    match child {
      @html.Node::Element(e) =>
        match e.tag {
          "br" => br_found = true
          "hr" => hr_found = true
          "img" => img_found = true
          _ => ()
        }
      _ => ()
    }
  }
  inspect(br_found, content="true")
  inspect(hr_found, content="true")
  inspect(img_found, content="true")
}

///|
test "tree_builder/li implicit close" {
  let html = "<ul><li>A<li>B<li>C</ul>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  match body.children[0] {
    @html.Node::Element(ul) => {
      inspect(ul.tag, content="ul")
      // Count li elements
      let mut li_count = 0
      for child in ul.children {
        match child {
          @html.Node::Element(e) if e.tag == "li" => li_count = li_count + 1
          _ => ()
        }
      }
      inspect(li_count, content="3")
    }
    _ => ()
  }
}

///|
test "tree_builder/foster parenting anchor" {
  // This is tests1_79: <table><a href="blah">aba<tr>...
  // The <a> before the table content should be foster parented
  let html = "<table><a href=\"blah\">aba<tr><td>cell</td></tr></table>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // Check what's the first child - should be anchor (foster parented)
  // or table depending on implementation
  let mut first_tag = ""
  for child in body.children {
    match child {
      @html.Node::Element(e) => {
        first_tag = e.tag
        break
      }
      @html.Node::Text(_) => ()
    }
  }
  // With foster parenting, the anchor should come first
  // Without it, the table comes first
  inspect(first_tag, content="a")
}

///|
test "tree_builder/plaintext in table" {
  // tests2_12: <table><plaintext><td>
  let html = "<table><plaintext><td>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // With foster parenting, plaintext should come before table
  let mut first_tag = ""
  for child in body.children {
    match child {
      @html.Node::Element(e) => {
        first_tag = e.tag
        break
      }
      @html.Node::Text(_) => ()
    }
  }
  inspect(first_tag, content="plaintext")
}

///|
test "tree_builder/document parsing with style" {
  // Test full document parsing with style in head
  let html = "<!doctype html><html><head><style>.row { display: flex; }</style></head><body><div>Test</div></body></html>"
  let result = @html.parse_document_v2(html)
  inspect(result.tag, content="html")
  // Check for body as child of html
  let mut has_body = false
  for child in result.children {
    match child {
      @html.Node::Element(e) if e.tag == "body" => has_body = true
      _ => ()
    }
  }
  inspect(has_body, content="true")
}

///|
test "tree_builder/document parsing moves metadata elements out of body flow" {
  let html =
    #|<!DOCTYPE html>
    #|<title>Variable reference without whitespace</title>
    #|<link rel=match href=reference/variable-reference-without-whitespace-ref.html>
    #|<meta rel=assert content="should stay out of body">
    #|<style>p { color: red; }</style>
    #|<p>Visible paragraph
  let result = @html.parse_document_v2(html)
  let body = find_body_v2(result)

  let tags : Array[String] = []
  let texts : Array[String] = []
  for child in body.children {
    match child {
      @html.Node::Element(e) => tags.push(e.tag)
      @html.Node::Text(t) =>
        if !t.trim().is_empty() {
          texts.push(t.trim().to_string())
        }
    }
  }

  inspect(tags, content="[\"p\"]")
  inspect(texts, content="[]")
}

///|
test "tree_builder/style raw text mode" {
  // CSS content with < character should not be parsed as HTML tags
  let html = "<html><head><style>div > p { color: red; }</style></head><body><p>Hello</p></body></html>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // Body should have p element, not CSS text
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => inspect("unexpected text", content="element")
  }
  // Head should have style element with CSS text content
  let head = match result.children[0] {
    @html.Node::Element(e) if e.tag == "head" => e
    _ => panic()
  }
  let style = match head.children[0] {
    @html.Node::Element(e) if e.tag == "style" => e
    _ => panic()
  }
  // Style should contain the CSS as text
  match style.children[0] {
    @html.Node::Text(t) => inspect(t, content="div > p { color: red; }")
    _ => inspect("no text", content="expected text child")
  }
}

///|
test "tree_builder/style with svg in data uri" {
  // This is the Wikipedia case: CSS contains SVG data URIs with < characters
  let html = "<html><head><style>background: url(\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg'/>\");</style></head><body><p>Content</p></body></html>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => inspect("unexpected text", content="element")
  }
}

///|
test "tree_builder/script raw text mode" {
  let html = "<script>if (a < b && c > d) { alert('test'); }</script><p>After</p>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // Should have script and p as children (script may be in head)
  let mut found_p = false
  for child in body.children {
    match child {
      @html.Node::Element(e) if e.tag == "p" => found_p = true
      _ => ()
    }
  }
  inspect(found_p, content="true")
}

///|
test "tree_builder/wikipedia style with nested svg and @supports" {
  // Simulates Wikipedia CSS: url() with SVG data URIs + @supports blocks
  let html = "<html><head><style>.a{background:url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\"><path d=\"M19 3H1v14h18z\"/></svg>')}.b{color:red}@supports((mask-image:none)){.c{mask-image:url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M1 1\"/></svg>')}}</style></head><body><p>Content</p></body></html>"
  let result = @html.parse_fragment_v2(html)
  let body = find_body_v2(result)
  // Body should NOT have CSS text as children
  let mut css_leaked = false
  for child in body.children {
    match child {
      @html.Node::Text(t) =>
        if t.contains("background") ||
          t.contains("@supports") ||
          t.contains("mask-image") {
          css_leaked = true
        }
      _ => ()
    }
  }
  inspect(css_leaked, content="false")
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    _ => inspect("not element", content="p")
  }
}

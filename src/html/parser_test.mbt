///|
/// Tests for HTML parser
test "parse simple element" {
  let html = "<div></div>"
  let elem = @html.parse(html)
  inspect(elem is Some(_), content="true")
  match elem {
    Some(e) => inspect(e.tag, content="div")
    None => ()
  }
}

///|
test "parse element with id" {
  let html = "<div id=\"main\"></div>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.tag, content="div")
      inspect(e.id, content="Some(\"main\")")
    }
    None => ()
  }
}

///|
test "parse element with classes" {
  let html = "<div class=\"foo bar\"></div>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.classes.length(), content="2")
      inspect(e.classes[0], content="foo")
      inspect(e.classes[1], content="bar")
    }
    None => ()
  }
}

///|
test "parse element with style" {
  let html = "<div style=\"width: 100px; height: 50px\"></div>"
  match @html.parse(html) {
    Some(e) => inspect(e.style, content="Some(\"width: 100px; height: 50px\")")
    None => ()
  }
}

///|
test "parse nested elements" {
  let html = "<div><span></span><p></p></div>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.tag, content="div")
      inspect(e.children.length(), content="2")
    }
    None => ()
  }
}

///|
test "parse self-closing element" {
  let html = "<div><br/><hr /></div>"
  match @html.parse(html) {
    Some(e) => inspect(e.children.length(), content="2")
    None => ()
  }
}

///|
test "parse void elements without slash" {
  // Void elements like br, hr, img don't need closing tags
  let html = "<div><br><hr><p>text</p></div>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.tag, content="div")
      // Should have 3 children: br, hr, p (not br containing hr and p!)
      inspect(e.children.length(), content="3")
      match e.children[0] {
        @html.Node::Element(br) => inspect(br.tag, content="br")
        _ => ()
      }
      match e.children[1] {
        @html.Node::Element(hr) => inspect(hr.tag, content="hr")
        _ => ()
      }
      match e.children[2] {
        @html.Node::Element(p) => inspect(p.tag, content="p")
        _ => ()
      }
    }
    None => ()
  }
}

///|
test "parse complex layout" {
  let html =
    #|<div id="root" style="width: 400px; height: 300px">
    #|  <header style="height: 50px">Header</header>
    #|  <main style="display: flex">
    #|    <aside style="width: 100px">Sidebar</aside>
    #|    <article>Content</article>
    #|  </main>
    #|</div>
  match @html.parse(html) {
    Some(e) => {
      inspect(e.tag, content="div")
      inspect(e.id, content="Some(\"root\")")
      // May include whitespace text nodes between elements
      inspect(e.children.length() >= 2, content="true")
    }
    None => ()
  }
}

///|
test "parse_document with style tag" {
  let html =
    #|<html>
    #|  <head>
    #|    <style>body { color: red; } h1 { font-size: 20px; }</style>
    #|  </head>
    #|  <body>
    #|    <h1>Hello</h1>
    #|  </body>
    #|</html>
  let doc = @html.parse_document(html)
  inspect(doc.root.tag, content="html")
  inspect(doc.stylesheets.length(), content="1")
  inspect(doc.stylesheets[0].contains("color: red"), content="true")
}

///|
test "parse_document with link stylesheet" {
  let html =
    #|<html>
    #|  <head>
    #|    <link rel="stylesheet" href="/style.css" />
    #|    <link rel="stylesheet" href="https://example.com/theme.css" />
    #|  </head>
    #|  <body></body>
    #|</html>
  let doc = @html.parse_document(html)
  inspect(doc.stylesheet_links.length(), content="2")
  inspect(doc.stylesheet_links[0], content="/style.css")
  inspect(doc.stylesheet_links[1], content="https://example.com/theme.css")
}

///|
test "parse anchor with text" {
  let html = "<a href=\"test\">Learn more</a>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.tag, content="a")
      inspect(e.children.length(), content="1")
      match e.children[0] {
        @html.Node::Text(t) => inspect(t, content="Learn more")
        @html.Node::Element(_) => inspect(false, content="should be text")
      }
    }
    None => inspect(false, content="should parse")
  }
}

///|
test "parse paragraph with nested anchor" {
  let html = "<p><a href=\"test\">Learn more</a></p>"
  match @html.parse(html) {
    Some(p) => {
      inspect(p.tag, content="p")
      inspect(p.children.length(), content="1")
      match p.children[0] {
        @html.Node::Element(a) => {
          inspect(a.tag, content="a")
          inspect(a.children.length(), content="1")
          match a.children[0] {
            @html.Node::Text(t) => inspect(t, content="Learn more")
            _ => inspect(false, content="a should have text child")
          }
        }
        _ => inspect(false, content="p should have element child")
      }
    }
    None => inspect(false, content="should parse")
  }
}

///|
test "parse html with body and children" {
  let html =
    #|<html>
    #|<head></head>
    #|<body>
    #|<div><h1>Test</h1></div>
    #|</body>
    #|</html>
  let doc = @html.parse_document(html)
  inspect(doc.root.tag, content="html")
  // html has 2+ children (may include whitespace text nodes between elements)
  inspect(doc.root.children.length() >= 2, content="true")
  // Find body element (skip whitespace text nodes)
  let mut body_elem : @html.Element? = None
  for child in doc.root.children {
    match child {
      @html.Node::Element(e) => if e.tag == "body" { body_elem = Some(e) }
      _ => ()
    }
  }
  match body_elem {
    Some(body) => {
      inspect(body.tag, content="body")
      // body may have whitespace text nodes
      inspect(body.children.length() >= 1, content="true")
      // Find div inside body
      for child in body.children {
        match child {
          @html.Node::Element(div) =>
            if div.tag == "div" {
              inspect(div.children.length() >= 1, content="true")
              break
            }
          _ => ()
        }
      }
    }
    _ => ()
  }
}

///|
test "parse html entities in text" {
  let html = "<p>Hello&nbsp;World &amp; &lt;test&gt;</p>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.tag, content="p")
      match e.children[0] {
        @html.Node::Text(t) =>
          // nbsp is \u00A0 (non-breaking space)
          inspect(t, content="Hello World & <test>")
        _ => inspect(false, content="should be text")
      }
    }
    None => inspect(false, content="should parse")
  }
}

///|
test "parse numeric html entities" {
  let html = "<p>&#60;&#x3E;</p>"
  match @html.parse(html) {
    Some(e) =>
      match e.children[0] {
        @html.Node::Text(t) => inspect(t, content="<>")
        _ => inspect(false, content="should be text")
      }
    None => inspect(false, content="should parse")
  }
}

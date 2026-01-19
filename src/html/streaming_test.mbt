///|
/// Tests for streaming HTML parser - comparing with regular parser

///|
/// Count elements in an element tree
fn stb_count_elements(elem : @html.Element) -> Int {
  let mut count = 1
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) =>
        count = count + stb_count_elements(child_elem)
      _ => ()
    }
  }
  count
}

///|
test "streaming_parser/simple div" {
  let html = "<div></div>"
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  inspect(regular_count, content="4") // html, head, body (div is inside body)
  inspect(streaming_count, content="4")
}

///|
test "streaming_parser/nested elements" {
  let html = "<div><span>hello</span><p>world</p></div>"
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular: " + regular_count.to_string())
  println("Streaming: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
test "streaming_parser/article structure" {
  let html =
    #|<html>
    #|<head><title>Test</title></head>
    #|<body>
    #|<article>
    #|  <header><h1>Title</h1></header>
    #|  <section>
    #|    <p>Paragraph 1</p>
    #|    <p>Paragraph 2</p>
    #|    <p>Paragraph 3</p>
    #|  </section>
    #|  <footer>Footer</footer>
    #|</article>
    #|</body>
    #|</html>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular elements: " + regular_count.to_string())
  println("Streaming elements: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
test "streaming_parser/many paragraphs" {
  let buf = StringBuilder::new()
  buf.write_string("<html><body>")
  for i = 0; i < 100; i = i + 1 {
    buf.write_string("<p>Paragraph ")
    buf.write_string(i.to_string())
    buf.write_string("</p>")
  }
  buf.write_string("</body></html>")
  let html = buf.to_string()
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular elements: " + regular_count.to_string())
  println("Streaming elements: " + streaming_count.to_string())
  // Should have: html, head, body, and 100 p elements = 103
  inspect(regular_count, content="103")
  inspect(streaming_count, content="103")
}

///|
test "streaming_parser/small chunks" {
  let html = "<div><span>hello</span><p>world</p></div>"
  // Use very small chunk size to test chunk boundary handling
  let streaming_small = @html.parse_document_streaming(html, 5)
  let streaming_large = @html.parse_document_streaming(html, 1024)
  let small_count = stb_count_elements(streaming_small.root)
  let large_count = stb_count_elements(streaming_large.root)
  println("Small chunks: " + small_count.to_string())
  println("Large chunks: " + large_count.to_string())
  inspect(small_count == large_count, content="true")
}

///|
test "streaming_parser/deep nesting" {
  let html =
    #|<div>
    #|  <div>
    #|    <div>
    #|      <div>
    #|        <div>
    #|          <p>Deep content</p>
    #|        </div>
    #|      </div>
    #|    </div>
    #|  </div>
    #|</div>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular: " + regular_count.to_string())
  println("Streaming: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
test "streaming_parser/script and style tags" {
  let html =
    #|<html>
    #|<head>
    #|  <style>.foo { color: red; }</style>
    #|  <script>console.log("hello")</script>
    #|</head>
    #|<body>
    #|  <div>Content</div>
    #|</body>
    #|</html>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular: " + regular_count.to_string())
  println("Streaming: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
test "streaming_parser/self-closing tags" {
  let html =
    #|<div>
    #|  <img src="test.png">
    #|  <br>
    #|  <input type="text">
    #|  <hr>
    #|</div>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular: " + regular_count.to_string())
  println("Streaming: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
test "streaming_parser/comments" {
  let html =
    #|<div>
    #|  <!-- This is a comment -->
    #|  <p>Content</p>
    #|  <!-- Another comment -->
    #|</div>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular: " + regular_count.to_string())
  println("Streaming: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
test "streaming_parser/mixed content" {
  let html =
    #|<div>
    #|  Text before
    #|  <span>inline</span>
    #|  Text after
    #|  <p>Block</p>
    #|</div>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_count = stb_count_elements(regular.root)
  let streaming_count = stb_count_elements(streaming.root)
  println("Regular: " + regular_count.to_string())
  println("Streaming: " + streaming_count.to_string())
  inspect(regular_count == streaming_count, content="true")
}

///|
fn stb_collect_text(elem : @html.Element) -> String {
  let buf = StringBuilder::new()
  fn walk(e : @html.Element) {
    for child in e.children {
      match child {
        @html.Node::Element(child_elem) => walk(child_elem)
        @html.Node::Text(t) => {
          buf.write_string(t)
          buf.write_string("|")
        }
      }
    }
  }

  walk(elem)
  buf.to_string()
}

///|
test "streaming_parser/table with CJK text" {
  let html =
    #|<html><body>
    #|<table>
    #|  <tr><td>コードブロック</td><td>動作</td></tr>
    #|  <tr><td>mbt check</td><td>LSP で検査される</td></tr>
    #|</table>
    #|</body></html>
  let regular = @html.parse_document(html)
  let streaming = @html.parse_document_streaming(html, 1024)
  let regular_text = stb_collect_text(regular.root)
  let streaming_text = stb_collect_text(streaming.root)
  println("Regular text: " + regular_text)
  println("Streaming text: " + streaming_text)
  inspect(regular_text == streaming_text, content="true")
}

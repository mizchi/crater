///|
test "ua default line-height does not reset inherited font metrics on inline descendants" {
  let html =
    #|<!doctype html>
    #|<style>
    #|#host { font-size: 20px; line-height: 30px; }
    #|</style>
    #|<div id="host"><span id="child">hello</span></div>
  let node = render_to_node(html, RenderContext::default())
  let host = node.children[0]
  inspect(host.id, content="div#host")
  inspect(host.style.font_size, content="20")
  inspect(host.style.line_height, content="30")

  let child = host.children[0]
  inspect(child.id, content="span#child")
  inspect(child.style.font_size, content="20")
  inspect(child.style.line_height, content="30")

  let text = child.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="20")
  inspect(text.style.line_height, content="30")
}

///|
test "font-size inheritance in full render" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>#div1 { font-size: 20px; width: 30px; }</style>
    #|</head>
    #|<body>
    #|<div id="div1"><a>aaa</a></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)

  let div1 = node.children[0]
  inspect(div1.id, content="div#div1")
  inspect(div1.style.font_size, content="20")

  let text = div1.children[0]
  inspect(text.id, content="a")
  inspect(text.style.font_size, content="20")
}

///|
test "font shorthand inherits line-height to descendant text nodes" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>body { font: 10px/1 monospace; }</style>
    #|</head>
    #|<body>
    #|<div id="outer"><span id="inner">X X</span></div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let inner = outer.children[0]
  inspect(inner.id, content="span#inner")
  inspect(inner.style.font_size, content="10")
  inspect(inner.style.line_height, content="10")
  let text = inner.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="10")
  inspect(text.style.line_height, content="10")
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "font-family and spacing inherit to descendant text nodes" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>body { font-family: serif; letter-spacing: 2px; word-spacing: 3px; }</style>
    #|</head>
    #|<body>
    #|<div id="outer"><span id="inner">hello world</span></div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_family, content="serif")
  inspect(outer.style.letter_spacing, content="2")
  inspect(outer.style.word_spacing, content="3")
  let inner = outer.children[0]
  inspect(inner.id, content="span#inner")
  inspect(inner.style.font_family, content="serif")
  inspect(inner.style.letter_spacing, content="2")
  inspect(inner.style.word_spacing, content="3")
  let text = inner.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_family, content="serif")
  inspect(text.style.letter_spacing, content="2")
  inspect(text.style.word_spacing, content="3")
}

///|
test "body defaults descendant text nodes to serif font-family" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="outer">hello world</div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(node.id, content="body")
  inspect(node.style.font_family, content="serif")
  inspect(node.style.margin.top, content="Length(8)")
  inspect(node.style.margin.left, content="Length(8)")
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_family, content="serif")
  let text = outer.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_family, content="serif")
}

///|
test "implicit body font shorthand reaches descendant text measure" {
  let html =
    #|<!doctype html>
    #|<style>body { font: 10px/1 monospace; }</style>
    #|<div id="outer">X X</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="10")
  inspect(text.style.line_height, content="10")
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "body font shorthand survives preceding grid declarations" {
  let html =
    #|<!doctype html>
    #|<style>
    #|body {
    #|  display: grid;
    #|  grid-template-columns: repeat(auto-fill, 50px 50px 50px);
    #|  grid-auto-rows: 50px;
    #|  font: 10px/1 monospace;
    #|}
    #|</style>
    #|<div id="outer">X X</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(node.id, content="body")
  inspect(node.style.font_size, content="10")
  inspect(node.style.line_height, content="10")
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "body font shorthand survives string @import prelude" {
  let html =
    #|<!doctype html>
    #|<style>
    #|@import "/fonts/ahem.css"; /* optional */
    #|body {
    #|  font: 10px/1 monospace;
    #|}
    #|</style>
    #|<div id="outer">X X</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "later body font style overrides earlier reset style" {
  let html =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|</style>
    #|<style>
    #|@import "/fonts/ahem.css"; /* optional */
    #|body {
    #|  display: grid;
    #|  grid-template-columns: repeat(auto-fill, 50px 50px 50px);
    #|  grid-auto-rows: 50px;
    #|  font: 10px/1 monospace;
    #|}
    #|</style>
    #|<div id="outer">X X</div>
  let doc = @html.parse_document(html)
  inspect(doc.stylesheets.length(), content="2")
  inspect(doc.stylesheets[0].contains("font-size: 16px"), content="true")
  inspect(doc.stylesheets[1].contains("font: 10px/1 monospace"), content="true")
  let cascaded = @css.cascade_element_indexed(
    @css.Element::new("body"),
    [
      @css.IndexedStylesheet::new(@css.parse_stylesheet(doc.stylesheets[0])),
      @css.IndexedStylesheet::new(@css.parse_stylesheet(doc.stylesheets[1])),
    ],
    [],
    None,
  )
  let body_style = @css.compute_style(cascaded, @css.ComputeContext::new())
  inspect(body_style.font_size, content="10")
  inspect(body_style.line_height, content="10")
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(node.id, content="body")
  inspect(node.style.font_size, content="10")
  inspect(node.style.line_height, content="10")
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "later font shorthand overrides earlier reset longhands in computed style" {
  let reset = @css.parse_stylesheet(
    "body { font-size: 16px; line-height: 1.2; }",
  )
  let authored = @css.parse_stylesheet("body { font: 10px/1 monospace; }")
  let body = @css.Element::new("body")
  let cascaded = @css.cascade_element_indexed(
    body,
    [@css.IndexedStylesheet::new(reset), @css.IndexedStylesheet::new(authored)],
    [],
    None,
  )
  debug_inspect(
    cascaded.get_value("font"),
    content="Some(\"10px/1 monospace\")",
  )
  let style = @css.compute_style(cascaded, @css.ComputeContext::new())
  inspect(style.font_size, content="10")
  inspect(style.line_height, content="10")
}

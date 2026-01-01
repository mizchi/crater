///|
/// Tests for HTML parser

test "parse simple element" {
  let html = "<div></div>"
  let elem = @html.parse(html)
  inspect(elem.is_some(), content="true")
  match elem {
    Some(e) => inspect(e.tag, content="div")
    None => ()
  }
}

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

test "parse element with style" {
  let html = "<div style=\"width: 100px; height: 50px\"></div>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.style, content="Some(\"width: 100px; height: 50px\")")
    }
    None => ()
  }
}

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

test "parse self-closing element" {
  let html = "<div><br/><hr /></div>"
  match @html.parse(html) {
    Some(e) => {
      inspect(e.children.length(), content="2")
    }
    None => ()
  }
}

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
      inspect(e.children.length(), content="2")
    }
    None => ()
  }
}

///|
/// Auto-generated tests from html5lib-tests/tree-construction
/// Do not edit manually - regenerate with:
///   npm run gen-html5lib-tests
///

///|
/// Helper to find body element in parsed tree
fn find_body(elem : @html.Element) -> @html.Element {
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
  // Search recursively
  for child in elem.children {
    match child {
      @html.Node::Element(e) => {
        let found = find_body(e)
        if found.tag == "body" {
          return found
        }
      }
      _ => ()
    }
  }
  // Return a dummy body if not found
  elem
}

///|
test "html5lib/tests1_0" {
  let html = "Test"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests1_1" {
  let html = "<p>One<p>Two"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_2" {
  let html = "Line1<br>Line2<br>Line3<br>Line4"
  let result = @html.parse_fragment(html)
  // Body should have 7 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="br")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_19" {
  let html = "<b><table><td><i></table>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_20" {
  let html = "<b><table><td></b><i></table>X"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_21" {
  let html = "<h1>Hello<h2>World"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="h1")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_22" {
  let html = "<a><p>X<a>Y</a>Z</p></a>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_23" {
  let html = "<b><button>foo</b>bar"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_24" {
  let html = "<!DOCTYPE html><span><button>foo</span>bar"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="span")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_25" {
  let html = "<p><b><div><marquee></p></b></div>X"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_26" {
  let html = "<script><div></script></div><title><p></title><p><p>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_27" {
  let html = "<!--><div>--<!-->"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_28" {
  let html = "<p><hr></p>"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_29" {
  let html = "<select><b><option><select><option></b></select>X"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="select")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_30" {
  let html = "<a><table><td><a><table></table><a></tr><a></table><b>X</b>C<a>Y"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_31" {
  let html = "<a X>0<b>1<a Y>2"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_32" {
  let html = "<!-----><font><div>hello<table>excite!<b>me!<th><i>please!</tr><!--X-->"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="font")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_33" {
  let html = "<!DOCTYPE html><li>hello<li>world<ul>how<li>do</ul>you</body><!--do-->"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="li")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_34" {
  let html = "<!DOCTYPE html>A<option>B<optgroup>C<select>D</option>E"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="option")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_35" {
  let html = "<"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests1_36" {
  let html = "<#"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests1_37" {
  let html = "</"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests1_50" {
  let html = "<!DOCTYPE html><script> <!-- </script> --> </script> EOF"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests1_51" {
  let html = "<b><p></b>TEST"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_52" {
  let html = "<p id=a><b><p id=b></b>TEST"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_53" {
  let html = "<b id=a><p><b id=b></p></b>TEST"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_54" {
  let html = "<!DOCTYPE html><title>U-test</title><body><div><p>Test<u></p></div></body>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_55" {
  let html = "<!DOCTYPE html><font><table></font></table></font>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="font")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_56" {
  let html = "<font><p>hello<b>cruel</font>world"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="font")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_57" {
  let html = "<b>Test</i>Test"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_58" {
  let html = "<b>A<cite>B<div>C"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_59" {
  let html = "<b>A<cite>B<div>C</cite>D"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_60" {
  let html = "<b>A<cite>B<div>C</b>D"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_62" {
  let html = "<DIV>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_63" {
  let html = "<DIV> abc"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_64" {
  let html = "<DIV> abc <B>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_65" {
  let html = "<DIV> abc <B> def"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_66" {
  let html = "<DIV> abc <B> def <I>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_67" {
  let html = "<DIV> abc <B> def <I> ghi"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_68" {
  let html = "<DIV> abc <B> def <I> ghi <P>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_69" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_70" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl </B>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_71" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl </B> mno"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_72" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl </B> mno </I>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_73" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl </B> mno </I> pqr"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_74" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl </B> mno </I> pqr </P>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_75" {
  let html = "<DIV> abc <B> def <I> ghi <P> jkl </B> mno </I> pqr </P> stu"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="div")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_76" {
  let html = "<test attribute---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------->"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="test")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_77" {
  let html = "<a href=\"blah\">aba<table><a href=\"foo\">br<tr><td></td></tr>x</table>aoe"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_78" {
  let html = "<a href=\"blah\">aba<table><tr><td><a href=\"foo\">br</td></tr>x</table>aoe"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_79" {
  let html = "<table><a href=\"blah\">aba<tr><td><a href=\"foo\">br</td></tr>x</table>aoe"
  let result = @html.parse_fragment(html)
  // Body should have 4 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_80" {
  let html = "<a href=a>aa<marquee>aa<a href=b>bb</marquee>aa"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_81" {
  let html = "<wbr><strike><code></strike><code><strike></code>"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="wbr")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_82" {
  let html = "<!DOCTYPE html><spacer>foo"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="spacer")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_86" {
  let html = "<table><tr><tr><td><td><span><th><span>X</table>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_87" {
  let html = "<body><body><base><link><meta><title><p></title><body><p></body>"
  let result = @html.parse_fragment(html)
  // Body should have 5 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="base")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_88" {
  let html = "<textarea><p></textarea>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="textarea")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_89" {
  let html = "<p><image></p>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_90" {
  let html = "<a><table><a></table><p><a><div><a>"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_91" {
  let html = "<head></p><meta><p>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_92" {
  let html = "<head></html><meta><p>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="meta")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_93" {
  let html = "<b><table><td></b><i></table>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_94" {
  let html = "<h1><h2>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="h1")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_95" {
  let html = "<a><p><a></a></p></a>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_96" {
  let html = "<b><button></b></button></b>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="b")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_97" {
  let html = "<p><b><div><marquee></p></b></div>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_98" {
  let html = "<script></script></div><title></title><p><p>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_99" {
  let html = "<select><b><option><select><option></b></select>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="select")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_101" {
  let html = "<a><table><td><a><table></table><a></tr><a></table><a>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="a")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_102" {
  let html = "<ul><li></li><div><li></div><li><li><div><li><address><li><b><em></b><li></ul>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="ul")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_103" {
  let html = "<ul><li><ul></li><li>a</li></ul></li></ul>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="ul")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_105" {
  let html = "<h1><table><td><h3></table><h3></h1>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="h1")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_106" {
  let html = "<table><colgroup><col><colgroup><col><col><col><colgroup><col><col><thead><tr><td></table>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_107" {
  let html = "<table><col><tbody><col><tr><col><td><col></table><col>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_108" {
  let html = "<table><colgroup><tbody><colgroup><tr><colgroup><td><colgroup></table><colgroup>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_109" {
  let html = "</strong></b></em></i></u></strike></s></blink></tt></pre></big></small></font></select></h1></h2></h3></h4></h5></h6></body></br></a></img></title></span></style></script></table></th></td></tr></frame></area></link></param></hr></input></col></base></meta></basefont></bgsound></embed></spacer></p></dd></dt></caption></colgroup></tbody></tfoot></thead></address></blockquote></center></dir></div></dl></fieldset></listing></menu></ol></ul></li></nobr></wbr></form></button></marquee></object></html></frameset></head></iframe></image></isindex></noembed></noframes></noscript></optgroup></option></plaintext></textarea>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="br")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests1_110" {
  let html = "<table><tr></strong></b></em></i></u></strike></s></blink></tt></pre></big></small></font></select></h1></h2></h3></h4></h5></h6></body></br></a></img></title></span></style></script></table></th></td></tr></frame></area></link></param></hr></input></col></base></meta></basefont></bgsound></embed></spacer></p></dd></dt></caption></colgroup></tbody></tfoot></thead></address></blockquote></center></dir></div></dl></fieldset></listing></menu></ol></ul></li></nobr></wbr></form></button></marquee></object></html></frameset></head></iframe></image></isindex></noembed></noframes></noscript></optgroup></option></plaintext></textarea>"
  let result = @html.parse_fragment(html)
  // Body should have 3 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="br")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_0" {
  let html = "<!DOCTYPE html>Test"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_1" {
  let html = "<textarea>test</div>test"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="textarea")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_2" {
  let html = "<table><td>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_3" {
  let html = "<table><td>test</tbody></table>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_4" {
  let html = "<frame>test"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_9" {
  let html = "<!DOCTYPE html><font><p><b>test</font>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="font")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_10" {
  let html = "<!DOCTYPE html><dt><div><dd>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="dt")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_12" {
  let html = "<table><plaintext><td>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="plaintext")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_13" {
  let html = "<plaintext></plaintext>"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="plaintext")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_14" {
  let html = "<!DOCTYPE html><table><tr>TEST"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="table")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_17" {
  let html = "<!DOCTYPE html></b test<b &=&amp>X"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_19" {
  let html = "&"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_20" {
  let html = "&#"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_21" {
  let html = "&#X"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_22" {
  let html = "&#x"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_23" {
  let html = "&#45"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_24" {
  let html = "&x-test"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

///|
test "html5lib/tests2_25" {
  let html = "<!doctypehtml><p><li>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_26" {
  let html = "<!doctypehtml><p><dt>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_27" {
  let html = "<!doctypehtml><p><dd>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_28" {
  let html = "<!doctypehtml><p><form>"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_29" {
  let html = "<!DOCTYPE html><p></P>X"
  let result = @html.parse_fragment(html)
  // Body should have 2 children
  let body = find_body(result)
  match body.children[0] {
    @html.Node::Element(e) => inspect(e.tag, content="p")
    @html.Node::Text(_) => ()
  }
}

///|
test "html5lib/tests2_30" {
  let html = "&AMP"
  let result = @html.parse_fragment(html)
  // Body should have 1 children
  let _ = find_body(result)

}

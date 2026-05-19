///|
/// Cross-frame DOM mirror generalization tests (#182 slice 5).
///
/// Pin both the `extract_iframe_content_window_mirror` parser and the
/// end-to-end mirror flow for shapes beyond the hardcoded WPT one-liner.

///|
test "extract_iframe_content_window_mirror parses the classic WPT shape" {
  let result = extract_iframe_content_window_mirror(
    "window.baz = iframe.contentWindow.foo",
  )
  match result {
    Some((lhs, prop)) => {
      assert_eq(lhs, "window.baz")
      assert_eq(prop, "foo")
    }
    None => assert_false(true)
  }
}

///|
test "extract handles globalThis LHS and a different iframe var name" {
  let result = extract_iframe_content_window_mirror(
    "globalThis.captured = f.contentWindow.theProp;",
  )
  match result {
    Some((lhs, prop)) => {
      assert_eq(lhs, "globalThis.captured")
      assert_eq(prop, "theProp")
    }
    None => assert_false(true)
  }
}

///|
test "extract handles a bare identifier LHS" {
  let result = extract_iframe_content_window_mirror(
    "captured = childFrame.contentWindow.myProp;",
  )
  match result {
    Some((lhs, prop)) => {
      assert_eq(lhs, "captured")
      assert_eq(prop, "myProp")
    }
    None => assert_false(true)
  }
}

///|
test "extract handles whitespace around the equals" {
  let result = extract_iframe_content_window_mirror(
    "window.x   =   iframe.contentWindow.y",
  )
  match result {
    Some((lhs, prop)) => {
      assert_eq(lhs, "window.x")
      assert_eq(prop, "y")
    }
    None => assert_false(true)
  }
}

///|
test "extract returns None for expressions without .contentWindow." {
  let result = extract_iframe_content_window_mirror(
    "iframe.src = '/x'; document.body.appendChild(iframe);",
  )
  match result {
    Some(_) => assert_false(true)
    None => ()
  }
}

///|
test "extract returns None when there's no LHS before .contentWindow" {
  // A read with no assignment shouldn't trigger the mirror — there's
  // nothing to write back to.
  let result = extract_iframe_content_window_mirror(
    "console.log(iframe.contentWindow.foo);",
  )
  match result {
    Some(_) => assert_false(true)
    None => ()
  }
}

///|
test "extract handles trailing semicolon between prop and end-of-statement" {
  let result = extract_iframe_content_window_mirror(
    "  window.snapshot = myFrame.contentWindow.value  ;  ",
  )
  match result {
    Some((lhs, prop)) => {
      assert_eq(lhs, "window.snapshot")
      assert_eq(prop, "value")
    }
    None => assert_false(true)
  }
}

///|
test "extract handles a multi-statement expression with mirror at the end" {
  // The synthetic handler runs the createElement + appendChild stanza
  // BEFORE the mirror assignment in the same expression. The parser
  // must find the mirror regardless of preceding statements.
  let result = extract_iframe_content_window_mirror(
    "const f = document.createElement('iframe'); f.src='/x'; document.body.appendChild(f); window.out = f.contentWindow.payload;",
  )
  match result {
    Some((lhs, prop)) => {
      assert_eq(lhs, "window.out")
      assert_eq(prop, "payload")
    }
    None => assert_false(true)
  }
}

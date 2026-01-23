///|
/// Integration tests for JavaScript Runtime (JS target only)

///|
test "execute simple expression" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let result = ctx.execute("1 + 2")
  inspect(result.success, content="true")
  inspect(result.value, content="3")
}

///|
test "execute console.log" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let result = ctx.execute("console.log('hello'); 42")
  inspect(result.success, content="true")
  inspect(result.value, content="42")
  inspect(ctx.get_logs().length(), content="1")
  inspect(ctx.get_logs()[0], content="hello")
}

///|
test "execute document.createElement" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'test-div');
    #|div._mockId
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Should return a mock ID (positive integer >= 1000)
  let node_id = result.value
  assert_true(node_id != "" && node_id != "undefined")
}

///|
test "execute DOM manipulation" {
  let dom = @dom.DomTree::new()

  // Create initial structure in DOM
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'my-div');
    #|div.textContent = 'Hello from JS';
    #|document.body.appendChild(div);
    #|document.getElementById('my-div').textContent
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="Hello from JS")
}

///|
test "DOM operations are applied to DomTree" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'created-by-js');
    #|div.setAttribute('class', 'test-class');
    #|document.body.appendChild(div);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify the element was actually created in DomTree
  let found = dom.query_selector(doc, "#created-by-js")
  match found {
    Ok(Some(node_id)) => {
      // Check the attribute was set
      let class_attr = dom.get_attribute(node_id, "class")
      match class_attr {
        Ok(Some(v)) => inspect(v, content="test-class")
        _ => assert_true(false) // Should have class attribute
      }
    }
    _ => assert_true(false) // Element should exist
  }
}

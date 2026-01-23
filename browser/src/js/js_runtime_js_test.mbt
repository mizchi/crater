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

///|
test "insertBefore inserts element before reference node" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)

  // Create two elements and use insertBefore
  let code =
    #|const first = document.createElement('div');
    #|first.setAttribute('id', 'first');
    #|const second = document.createElement('div');
    #|second.setAttribute('id', 'second');
    #|const third = document.createElement('div');
    #|third.setAttribute('id', 'third');
    #|document.body.appendChild(first);
    #|document.body.appendChild(third);
    #|document.body.insertBefore(second, third);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify order: first, second, third
  let children = dom.get_children(body)
  match children {
    Ok(kids) => {
      inspect(kids.length(), content="3")
      // Check that second is before third (index 1)
      let second_tag = dom.get_attribute(kids[1], "id")
      match second_tag {
        Ok(Some(v)) => inspect(v, content="second")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "insertBefore with null reference appends to end" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)

  // insertBefore with null should append
  let code =
    #|const first = document.createElement('div');
    #|first.setAttribute('id', 'first');
    #|const second = document.createElement('div');
    #|second.setAttribute('id', 'second');
    #|document.body.appendChild(first);
    #|document.body.insertBefore(second, null);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify order: first, second (second appended at end)
  let children = dom.get_children(body)
  match children {
    Ok(kids) => {
      inspect(kids.length(), content="2")
      let second_tag = dom.get_attribute(kids[1], "id")
      match second_tag {
        Ok(Some(v)) => inspect(v, content="second")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "replaceChild replaces old child with new child" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)

  // Create three elements and replace the second one
  let code =
    #|const first = document.createElement('div');
    #|first.setAttribute('id', 'first');
    #|const second = document.createElement('div');
    #|second.setAttribute('id', 'second');
    #|const third = document.createElement('div');
    #|third.setAttribute('id', 'third');
    #|const replacement = document.createElement('span');
    #|replacement.setAttribute('id', 'replacement');
    #|document.body.appendChild(first);
    #|document.body.appendChild(second);
    #|document.body.appendChild(third);
    #|document.body.replaceChild(replacement, second);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify order: first, replacement, third
  let children = dom.get_children(body)
  match children {
    Ok(kids) => {
      inspect(kids.length(), content="3")
      // Check that replacement is at index 1
      let replacement_id = dom.get_attribute(kids[1], "id")
      match replacement_id {
        Ok(Some(v)) => inspect(v, content="replacement")
        _ => assert_true(false)
      }
      // Check that third is still at index 2
      let third_id = dom.get_attribute(kids[2], "id")
      match third_id {
        Ok(Some(v)) => inspect(v, content="third")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "cloneNode shallow clone copies element and attributes" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const original = document.createElement('div');
    #|original.setAttribute('id', 'original');
    #|original.setAttribute('class', 'test-class');
    #|const child = document.createElement('span');
    #|child.setAttribute('id', 'child');
    #|original.appendChild(child);
    #|const clone = original.cloneNode(false);
    #|clone.setAttribute('id', 'clone');
    #|document.body.appendChild(original);
    #|document.body.appendChild(clone);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify both original and clone exist
  let children = dom.get_children(body)
  match children {
    Ok(kids) => {
      inspect(kids.length(), content="2")
      // Original should have the child
      let original_children = dom.get_children(kids[0])
      match original_children {
        Ok(oc) => inspect(oc.length(), content="1")
        _ => assert_true(false)
      }
      // Clone should NOT have children (shallow)
      let clone_children = dom.get_children(kids[1])
      match clone_children {
        Ok(cc) => inspect(cc.length(), content="0")
        _ => assert_true(false)
      }
      // Clone should have the class attribute copied
      let clone_class = dom.get_attribute(kids[1], "class")
      match clone_class {
        Ok(Some(v)) => inspect(v, content="test-class")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "cloneNode deep clone copies element with children" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const original = document.createElement('div');
    #|original.setAttribute('id', 'original');
    #|const child1 = document.createElement('span');
    #|child1.setAttribute('id', 'child1');
    #|const child2 = document.createElement('span');
    #|child2.setAttribute('id', 'child2');
    #|original.appendChild(child1);
    #|original.appendChild(child2);
    #|const clone = original.cloneNode(true);
    #|clone.setAttribute('id', 'clone');
    #|document.body.appendChild(clone);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify clone has children
  let children = dom.get_children(body)
  match children {
    Ok(kids) => {
      inspect(kids.length(), content="1")
      // Clone should have 2 children (deep copy)
      let clone_children = dom.get_children(kids[0])
      match clone_children {
        Ok(cc) => {
          inspect(cc.length(), content="2")
          // First child should have id="child1"
          let child1_id = dom.get_attribute(cc[0], "id")
          match child1_id {
            Ok(Some(v)) => inspect(v, content="child1")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "classList manipulation" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|div.classList.add('foo', 'bar');
    #|div.classList.remove('foo');
    #|div.classList.toggle('baz');
    #|document.body.appendChild(div);
    #|div.className
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Should have "bar baz"
  assert_true(result.value.contains("bar"))
  assert_true(result.value.contains("baz"))
}

///|
test "hasAttribute and hasAttributes" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const hasNone = div.hasAttributes();
    #|div.setAttribute('id', 'test');
    #|const hasId = div.hasAttribute('id');
    #|const hasClass = div.hasAttribute('class');
    #|const hasAttrs = div.hasAttributes();
    #|[hasNone, hasId, hasClass, hasAttrs].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="false,true,false,true")
}

///|
test "contains method" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const parent = document.createElement('div');
    #|const child = document.createElement('span');
    #|const grandchild = document.createElement('a');
    #|const unrelated = document.createElement('p');
    #|child.appendChild(grandchild);
    #|parent.appendChild(child);
    #|[
    #|  parent.contains(child),
    #|  parent.contains(grandchild),
    #|  parent.contains(parent),
    #|  parent.contains(unrelated),
    #|  child.contains(parent)
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,false,false")
}

///|
test "matches and closest" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'myDiv');
    #|div.className = 'container';
    #|const span = document.createElement('span');
    #|span.className = 'inner';
    #|div.appendChild(span);
    #|document.body.appendChild(div);
    #|[
    #|  div.matches('div'),
    #|  div.matches('#myDiv'),
    #|  div.matches('.container'),
    #|  span.closest('.container') === div,
    #|  span.closest('div') === div
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "getElementsByTagName and getElementsByClassName" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div1 = document.createElement('div');
    #|div1.className = 'item';
    #|const div2 = document.createElement('div');
    #|div2.className = 'item special';
    #|const span = document.createElement('span');
    #|span.className = 'item';
    #|document.body.appendChild(div1);
    #|document.body.appendChild(div2);
    #|document.body.appendChild(span);
    #|const byTag = document.getElementsByTagName('div');
    #|const byClass = document.getElementsByClassName('item');
    #|const bySpecial = document.getElementsByClassName('special');
    #|[byTag.length, byClass.length, bySpecial.length].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="2,3,1")
}

///|
test "createComment" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const comment = document.createComment('This is a comment');
    #|document.body.appendChild(comment);
    #|[comment.nodeType, comment.nodeName, comment.textContent].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="8|#comment|This is a comment")
}

///|
test "createDocumentFragment" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const frag = document.createDocumentFragment();
    #|const div1 = document.createElement('div');
    #|div1.setAttribute('id', 'frag1');
    #|const div2 = document.createElement('div');
    #|div2.setAttribute('id', 'frag2');
    #|frag.appendChild(div1);
    #|frag.appendChild(div2);
    #|[frag.nodeType, frag.childNodes.length].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="11,2")
}

///|
test "previousSibling and lastChild" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const span1 = document.createElement('span');
    #|span1.setAttribute('id', 'first');
    #|const span2 = document.createElement('span');
    #|span2.setAttribute('id', 'second');
    #|const span3 = document.createElement('span');
    #|span3.setAttribute('id', 'third');
    #|div.appendChild(span1);
    #|div.appendChild(span2);
    #|div.appendChild(span3);
    #|[
    #|  div.lastChild.id,
    #|  span2.previousSibling.id,
    #|  span3.previousSibling.id,
    #|  span1.previousSibling === null ? 'null' : 'not null'
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="third,first,second,null")
}

///|
test "append and prepend" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const span1 = document.createElement('span');
    #|span1.setAttribute('id', 'first');
    #|const span2 = document.createElement('span');
    #|span2.setAttribute('id', 'second');
    #|div.append(span1);
    #|div.prepend(span2);
    #|document.body.appendChild(div);
    #|[div.firstChild.id, div.lastChild.id].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="second,first")
}

///|
test "remove method" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const span = document.createElement('span');
    #|div.appendChild(span);
    #|document.body.appendChild(div);
    #|const beforeRemove = div.childNodes.length;
    #|span.remove();
    #|const afterRemove = div.childNodes.length;
    #|[beforeRemove, afterRemove].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="1,0")
}

///|
test "nodeType constants" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const el = document.createElement('div');
    #|const text = document.createTextNode('hello');
    #|const comment = document.createComment('comment');
    #|const frag = document.createDocumentFragment();
    #|[el.nodeType, text.nodeType, comment.nodeType, frag.nodeType, document.nodeType].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="1,3,8,11,9")
}

///|
test "isEqualNode and isSameNode" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div1 = document.createElement('div');
    #|div1.setAttribute('id', 'test');
    #|div1.className = 'foo';
    #|const div2 = document.createElement('div');
    #|div2.setAttribute('id', 'test');
    #|div2.className = 'foo';
    #|const div3 = document.createElement('div');
    #|div3.setAttribute('id', 'other');
    #|[
    #|  div1.isEqualNode(div2),
    #|  div1.isEqualNode(div3),
    #|  div1.isSameNode(div1),
    #|  div1.isSameNode(div2)
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,false,true,false")
}

///|
test "normalize merges adjacent text nodes" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const t1 = document.createTextNode('Hello');
    #|const t2 = document.createTextNode(' ');
    #|const t3 = document.createTextNode('World');
    #|div.appendChild(t1);
    #|div.appendChild(t2);
    #|div.appendChild(t3);
    #|const before = div.childNodes.length;
    #|div.normalize();
    #|const after = div.childNodes.length;
    #|[before, after, div.textContent].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="3|1|Hello World")
}

///|
test "splitText divides text node" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const text = document.createTextNode('HelloWorld');
    #|div.appendChild(text);
    #|const newText = text.splitText(5);
    #|[text.textContent, newText.textContent, div.childNodes.length].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="Hello|World|2")
}

///|
test "wholeText returns combined adjacent text" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const t1 = document.createTextNode('Hello');
    #|const t2 = document.createTextNode(' ');
    #|const t3 = document.createTextNode('World');
    #|div.appendChild(t1);
    #|div.appendChild(t2);
    #|div.appendChild(t3);
    #|t2.wholeText
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="Hello World")
}

///|
test "attributes collection" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'myId');
    #|div.setAttribute('class', 'myClass');
    #|div.setAttribute('data-value', '123');
    #|const attrs = div.attributes;
    #|[attrs.length, attrs.item(0).name, attrs.getNamedItem('id').value].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Attributes order may vary, just check length and getNamedItem works
  assert_true(result.value.contains("3"))
  assert_true(result.value.contains("myId"))
}

///|
test "document properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|[
    #|  document.URL,
    #|  document.compatMode,
    #|  document.characterSet,
    #|  document.contentType
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="about:blank|CSS1Compat|UTF-8|text/html")
}

///|
test "getRootNode returns root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const span = document.createElement('span');
    #|div.appendChild(span);
    #|document.body.appendChild(div);
    #|[
    #|  span.getRootNode().tagName,
    #|  div.getRootNode().tagName
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="HTML,HTML")
}

///|
test "namespaceURI and baseURI" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|[div.namespaceURI, div.baseURI, div.prefix === null ? 'null' : div.prefix].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="http://www.w3.org/1999/xhtml|about:blank|null")
}

///|
test "insertAdjacentElement" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const container = document.createElement('div');
    #|const middle = document.createElement('span');
    #|middle.setAttribute('id', 'middle');
    #|container.appendChild(middle);
    #|document.body.appendChild(container);
    #|const before = document.createElement('p');
    #|before.setAttribute('id', 'before');
    #|const after = document.createElement('p');
    #|after.setAttribute('id', 'after');
    #|const first = document.createElement('p');
    #|first.setAttribute('id', 'first');
    #|const last = document.createElement('p');
    #|last.setAttribute('id', 'last');
    #|middle.insertAdjacentElement('beforebegin', before);
    #|middle.insertAdjacentElement('afterend', after);
    #|container.insertAdjacentElement('afterbegin', first);
    #|container.insertAdjacentElement('beforeend', last);
    #|container.childNodes.map(c => c.id).join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="first,before,middle,after,last")
}

///|
test "lookupNamespaceURI and isDefaultNamespace" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|[
    #|  div.lookupNamespaceURI(null),
    #|  div.isDefaultNamespace('http://www.w3.org/1999/xhtml'),
    #|  div.isDefaultNamespace('http://other')
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="http://www.w3.org/1999/xhtml|true|false")
}

///|
test "createRange" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const range = document.createRange();
    #|const div = document.createElement('div');
    #|range.selectNode(div);
    #|[range.collapsed, typeof range.cloneContents].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,function")
}

///|
test "createTreeWalker" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const div = document.createElement('div');
    #|const span = document.createElement('span');
    #|div.appendChild(span);
    #|const walker = document.createTreeWalker(div);
    #|[walker.root === div, walker.currentNode === div, typeof walker.firstChild].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,function")
}

///|
test "importNode and adoptNode" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const original = document.createElement('div');
    #|original.setAttribute('id', 'original');
    #|const imported = document.importNode(original, false);
    #|const container = document.createElement('div');
    #|container.appendChild(original);
    #|const adopted = document.adoptNode(original);
    #|[imported.id, adopted.id, container.childNodes.length].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="original,original,0")
}

///|
test "attachShadow" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('span');
    #|shadow.appendChild(inner);
    #|[shadow.mode, shadow.host === host, host.shadowRoot === shadow].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="open,true,true")
}

// ============================================
// WPT-style DOM tests
// ============================================

///|
test "WPT: CharacterData.appendData" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|// Test Text.appendData
    #|const text = document.createTextNode('test');
    #|text.appendData('bar');
    #|results.push(text.data === 'testbar');
    #|// Test Comment.appendData
    #|const comment = document.createComment('test');
    #|comment.appendData('bar');
    #|results.push(comment.data === 'testbar');
    #|// Empty string
    #|const t2 = document.createTextNode('test');
    #|t2.appendData('');
    #|results.push(t2.data === 'test');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: CharacterData.deleteData" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const text = document.createTextNode('test');
    #|text.deleteData(1, 2);
    #|results.push(text.data === 'tt');
    #|const t2 = document.createTextNode('test');
    #|t2.deleteData(0, 4);
    #|results.push(t2.data === '');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true")
}

///|
test "WPT: CharacterData.insertData" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const text = document.createTextNode('test');
    #|text.insertData(2, 'XX');
    #|results.push(text.data === 'teXXst');
    #|const t2 = document.createTextNode('test');
    #|t2.insertData(0, 'YY');
    #|results.push(t2.data === 'YYtest');
    #|const t3 = document.createTextNode('test');
    #|t3.insertData(4, 'ZZ');
    #|results.push(t3.data === 'testZZ');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: CharacterData.replaceData" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const text = document.createTextNode('test');
    #|text.replaceData(1, 2, 'XX');
    #|results.push(text.data === 'tXXt');
    #|const t2 = document.createTextNode('test');
    #|t2.replaceData(0, 4, 'new');
    #|results.push(t2.data === 'new');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true")
}

///|
test "WPT: CharacterData.substringData" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const text = document.createTextNode('test');
    #|results.push(text.substringData(0, 4) === 'test');
    #|results.push(text.substringData(1, 2) === 'es');
    #|results.push(text.substringData(2, 10) === 'st');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: Document.createComment properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const c = document.createComment('test');
    #|results.push(c.data === 'test');
    #|results.push(c.nodeValue === 'test');
    #|results.push(c.textContent === 'test');
    #|results.push(c.length === 4);
    #|results.push(c.nodeType === 8);
    #|results.push(c.nodeName === '#comment');
    #|results.push(c.hasChildNodes() === false);
    #|results.push(c.childNodes.length === 0);
    #|results.push(c.firstChild === null);
    #|results.push(c.lastChild === null);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="true,true,true,true,true,true,true,true,true,true",
  )
}

///|
test "WPT: Document.createTextNode properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const t = document.createTextNode('test');
    #|results.push(t.data === 'test');
    #|results.push(t.nodeValue === 'test');
    #|results.push(t.textContent === 'test');
    #|results.push(t.length === 4);
    #|results.push(t.nodeType === 3);
    #|results.push(t.nodeName === '#text');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "WPT: ChildNode.before basic" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|// before() with text
    #|const parent = document.createElement('div');
    #|const child = document.createElement('span');
    #|parent.appendChild(child);
    #|child.before('hello');
    #|results.push(parent.childNodes.length === 2);
    #|results.push(parent.firstChild.textContent === 'hello');
    #|// before() with element
    #|const p2 = document.createElement('div');
    #|const c2 = document.createElement('span');
    #|const x = document.createElement('x');
    #|p2.appendChild(c2);
    #|c2.before(x);
    #|results.push(p2.firstChild === x);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: ChildNode.after basic" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const parent = document.createElement('div');
    #|const child = document.createElement('span');
    #|parent.appendChild(child);
    #|child.after('world');
    #|results.push(parent.childNodes.length === 2);
    #|results.push(parent.lastChild.textContent === 'world');
    #|// after() with element
    #|const p2 = document.createElement('div');
    #|const c2 = document.createElement('span');
    #|const y = document.createElement('y');
    #|p2.appendChild(c2);
    #|c2.after(y);
    #|results.push(p2.lastChild === y);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: ChildNode.replaceWith" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const parent = document.createElement('div');
    #|const child = document.createElement('span');
    #|const replacement = document.createElement('p');
    #|parent.appendChild(child);
    #|child.replaceWith(replacement);
    #|results.push(parent.childNodes.length === 1);
    #|results.push(parent.firstChild === replacement);
    #|results.push(child.parentNode === null);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: ParentNode.append" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const parent = document.createElement('div');
    #|const x = document.createElement('x');
    #|const y = document.createElement('y');
    #|parent.append(x, 'text', y);
    #|results.push(parent.childNodes.length === 3);
    #|results.push(parent.childNodes[0] === x);
    #|results.push(parent.childNodes[1].textContent === 'text');
    #|results.push(parent.childNodes[2] === y);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "WPT: ParentNode.prepend" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const parent = document.createElement('div');
    #|const existing = document.createElement('existing');
    #|parent.appendChild(existing);
    #|const x = document.createElement('x');
    #|parent.prepend(x, 'text');
    #|results.push(parent.childNodes.length === 3);
    #|results.push(parent.childNodes[0] === x);
    #|results.push(parent.childNodes[1].textContent === 'text');
    #|results.push(parent.childNodes[2] === existing);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "WPT: Node.cloneNode shallow" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'original');
    #|div.setAttribute('class', 'test');
    #|const child = document.createElement('span');
    #|div.appendChild(child);
    #|const clone = div.cloneNode(false);
    #|results.push(clone.getAttribute('id') === 'original');
    #|results.push(clone.getAttribute('class') === 'test');
    #|results.push(clone.childNodes.length === 0);
    #|results.push(clone !== div);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "WPT: Node.cloneNode deep" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|const child = document.createElement('span');
    #|child.setAttribute('id', 'child');
    #|div.appendChild(child);
    #|const clone = div.cloneNode(true);
    #|results.push(clone.childNodes.length === 1);
    #|results.push(clone.firstChild.getAttribute('id') === 'child');
    #|results.push(clone.firstChild !== child);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "WPT: Node.contains" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const parent = document.createElement('div');
    #|const child = document.createElement('span');
    #|const grandchild = document.createElement('a');
    #|child.appendChild(grandchild);
    #|parent.appendChild(child);
    #|results.push(parent.contains(parent) === true);
    #|results.push(parent.contains(child) === true);
    #|results.push(parent.contains(grandchild) === true);
    #|results.push(child.contains(parent) === false);
    #|results.push(parent.contains(null) === false);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "HTMLElement: title, lang, dir properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|results.push(div.title === '');
    #|div.title = 'My Title';
    #|results.push(div.title === 'My Title');
    #|results.push(div.lang === '');
    #|div.lang = 'en';
    #|results.push(div.lang === 'en');
    #|results.push(div.dir === '');
    #|div.dir = 'rtl';
    #|results.push(div.dir === 'rtl');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "HTMLElement: hidden, inert properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|results.push(div.hidden === false);
    #|div.hidden = true;
    #|results.push(div.hidden === true);
    #|results.push(div.hasAttribute('hidden'));
    #|div.hidden = false;
    #|results.push(div.hidden === false);
    #|results.push(!div.hasAttribute('hidden'));
    #|results.push(div.inert === false);
    #|div.inert = true;
    #|results.push(div.inert === true);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true,true")
}

///|
test "HTMLElement: draggable, spellcheck properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|results.push(div.draggable === false);
    #|div.draggable = true;
    #|results.push(div.draggable === true);
    #|results.push(div.spellcheck === true);
    #|div.spellcheck = false;
    #|results.push(div.getAttribute('spellcheck') === 'false');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "HTMLElement: innerText, outerText properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|div.innerText = 'Hello World';
    #|results.push(div.innerText === 'Hello World');
    #|results.push(div.outerText === 'Hello World');
    #|div.outerText = 'Changed';
    #|results.push(div.textContent === 'Changed');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "HTMLElement: dataset property" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|div.dataset.userId = '123';
    #|results.push(div.getAttribute('data-user-id') === '123');
    #|results.push(div.dataset.userId === '123');
    #|div.dataset.userRole = 'admin';
    #|results.push(div.getAttribute('data-user-role') === 'admin');
    #|delete div.dataset.userId;
    #|results.push(!div.hasAttribute('data-user-id'));
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "HTMLElement: popover methods" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|div.showPopover();
    #|results.push(div._popoverState === 'showing');
    #|div.hidePopover();
    #|results.push(div._popoverState === 'hidden');
    #|results.push(div.togglePopover() === true);
    #|results.push(div._popoverState === 'showing');
    #|results.push(div.togglePopover() === false);
    #|results.push(div._popoverState === 'hidden');
    #|results.push(div.togglePopover(true) === true);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true,true")
}

///|
test "HTMLElement: tabIndex, contentEditable properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|results.push(div.tabIndex === 0);
    #|div.tabIndex = 5;
    #|results.push(div.tabIndex === 5);
    #|results.push(div.getAttribute('tabindex') === '5');
    #|results.push(div.contentEditable === 'inherit');
    #|div.contentEditable = 'true';
    #|results.push(div.isContentEditable === true);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "HTMLElement: attachInternals" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|const internals = div.attachInternals();
    #|results.push(internals !== null);
    #|results.push(internals.shadowRoot === null);
    #|results.push(internals.form === null);
    #|results.push(internals.willValidate === false);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "HTMLElement: offset properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|results.push(typeof div.offsetTop === 'number');
    #|results.push(typeof div.offsetLeft === 'number');
    #|results.push(typeof div.offsetWidth === 'number');
    #|results.push(typeof div.offsetHeight === 'number');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "Event: constructor and properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const evt = new Event('click', { bubbles: true, cancelable: true });
    #|results.push(evt.type === 'click');
    #|results.push(evt.bubbles === true);
    #|results.push(evt.cancelable === true);
    #|results.push(evt.defaultPrevented === false);
    #|results.push(typeof evt.timeStamp === 'number');
    #|results.push(evt.isTrusted === false);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "Event: preventDefault and stopPropagation" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const evt = new Event('click', { cancelable: true });
    #|results.push(evt.defaultPrevented === false);
    #|evt.preventDefault();
    #|results.push(evt.defaultPrevented === true);
    #|results.push(evt._propagationStopped === false);
    #|evt.stopPropagation();
    #|results.push(evt._propagationStopped === true);
    #|results.push(evt._immediatePropagationStopped === false);
    #|evt.stopImmediatePropagation();
    #|results.push(evt._immediatePropagationStopped === true);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "Event: initEvent" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const evt = new Event('');
    #|evt.initEvent('submit', true, false);
    #|results.push(evt.type === 'submit');
    #|results.push(evt.bubbles === true);
    #|results.push(evt.cancelable === false);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "Window: basic properties" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|results.push(window.window === window);
    #|results.push(window.self === window);
    #|results.push(window.document === document);
    #|results.push(typeof window.innerWidth === 'number');
    #|results.push(typeof window.innerHeight === 'number');
    #|results.push(window.devicePixelRatio === 1);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "Window: location and navigator" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|results.push(window.location.href === 'about:blank');
    #|results.push(window.location.protocol === 'about:');
    #|results.push(typeof window.navigator.userAgent === 'string');
    #|results.push(window.navigator.language === 'en');
    #|results.push(Array.isArray(window.navigator.languages));
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "Window: timers" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const timeoutId = setTimeout(() => {}, 100);
    #|results.push(typeof timeoutId === 'number');
    #|clearTimeout(timeoutId);
    #|const intervalId = setInterval(() => {}, 100);
    #|results.push(typeof intervalId === 'number');
    #|clearInterval(intervalId);
    #|const rafId = requestAnimationFrame(() => {});
    #|results.push(typeof rafId === 'number');
    #|cancelAnimationFrame(rafId);
    #|results.push(true);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "Window: scroll methods" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|results.push(window.scrollX === 0);
    #|results.push(window.scrollY === 0);
    #|window.scrollTo({ left: 100, top: 200 });
    #|results.push(window.scrollX === 100);
    #|results.push(window.scrollY === 200);
    #|window.scrollBy({ left: 50, top: 50 });
    #|results.push(window.scrollX === 150);
    #|results.push(window.scrollY === 250);
    #|results.push(window.pageXOffset === 150);
    #|results.push(window.pageYOffset === 250);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true,true,true")
}

///|
test "Window: getComputedStyle and matchMedia" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const div = document.createElement('div');
    #|const style = window.getComputedStyle(div);
    #|results.push(typeof style === 'object');
    #|const mq = window.matchMedia('(min-width: 768px)');
    #|results.push(mq.media === '(min-width: 768px)');
    #|results.push(typeof mq.matches === 'boolean');
    #|results.push(typeof mq.addListener === 'function');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "Window: alert" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|alert('Hello World');
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="done")
  inspect(ctx.get_logs().length() > 0, content="true")
}

///|
test "Storage: localStorage basic operations" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|localStorage.setItem('key1', 'value1');
    #|results.push(localStorage.getItem('key1') === 'value1');
    #|results.push(localStorage.length === 1);
    #|localStorage.setItem('key2', 'value2');
    #|results.push(localStorage.length === 2);
    #|results.push(localStorage.key(0) !== null);
    #|localStorage.removeItem('key1');
    #|results.push(localStorage.getItem('key1') === null);
    #|localStorage.clear();
    #|results.push(localStorage.length === 0);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "FormData: basic operations" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const fd = new FormData();
    #|fd.append('name', 'John');
    #|fd.append('name', 'Jane');
    #|results.push(fd.get('name') === 'John');
    #|results.push(fd.getAll('name').length === 2);
    #|results.push(fd.has('name'));
    #|fd.set('name', 'Bob');
    #|results.push(fd.getAll('name').length === 1);
    #|fd.delete('name');
    #|results.push(!fd.has('name'));
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "URLSearchParams: basic operations" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const params = new URLSearchParams('a=1&b=2');
    #|results.push(params.get('a') === '1');
    #|results.push(params.get('b') === '2');
    #|params.append('c', '3');
    #|results.push(params.has('c'));
    #|params.set('a', '10');
    #|results.push(params.get('a') === '10');
    #|results.push(params.toString().indexOf('a=10') >= 0);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "URL: basic parsing" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const url = new URL('https://example.com:8080/path?query=1#hash');
    #|results.push(url.protocol === 'https:');
    #|results.push(url.hostname === 'example.com');
    #|results.push(url.port === '8080');
    #|results.push(url.pathname === '/path');
    #|results.push(url.search === '?query=1');
    #|results.push(url.hash === '#hash');
    #|results.push(url.searchParams.get('query') === '1');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true,true")
}

///|
test "MutationObserver: basic usage" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|let callbackCalled = false;
    #|const observer = new MutationObserver(function(mutations) { callbackCalled = true; });
    #|const div = document.createElement('div');
    #|observer.observe(div, { childList: true });
    #|results.push(observer._targets.length === 1);
    #|observer.disconnect();
    #|results.push(observer._targets.length === 0);
    #|const records = observer.takeRecords();
    #|results.push(Array.isArray(records));
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "DOMRect: basic usage" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const rect = new DOMRect(10, 20, 100, 50);
    #|results.push(rect.x === 10);
    #|results.push(rect.y === 20);
    #|results.push(rect.width === 100);
    #|results.push(rect.height === 50);
    #|results.push(rect.top === 20);
    #|results.push(rect.right === 110);
    #|results.push(rect.bottom === 70);
    #|results.push(rect.left === 10);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true,true,true")
}

///|
test "IntersectionObserver: basic usage" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const observer = new IntersectionObserver(function(entries) {}, { threshold: 0.5 });
    #|results.push(observer.root === null);
    #|results.push(observer.rootMargin === '0px');
    #|results.push(observer.thresholds.length === 1);
    #|const div = document.createElement('div');
    #|observer.observe(div);
    #|results.push(observer._targets.length === 1);
    #|observer.disconnect();
    #|results.push(observer._targets.length === 0);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

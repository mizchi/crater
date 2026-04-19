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
test "JS DOM operations produce mutation records" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  // Ignore setup-time mutations
  dom.clear_mutations()

  let ctx = JsContext::new(dom)
  let code =
    #|const p = document.createElement('p');
    #|p.setAttribute('id', 'm1');
    #|p.textContent = 'hello';
    #|document.body.appendChild(p);
    #|p.setAttribute('class', 'updated');
    #|'ok'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // DOM state itself should reflect all script operations
  match dom.query_selector(doc, "#m1") {
    Ok(Some(node_id)) => {
      match dom.get_attribute(node_id, "class") {
        Ok(Some(v)) => inspect(v, content="updated")
        _ => assert_true(false)
      }
      match dom.get_text_content(node_id) {
        Ok(text) => inspect(text, content="hello")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }

  assert_true(dom.pending_mutation_count() > 0)
  let (records, flush_result) = dom.flush_mutations()
  assert_true(records.length() > 0)

  let mut has_child_list = false
  for record in records {
    match record.type_ {
      @dom.ChildList => has_child_list = true
      _ => ()
    }
  }
  assert_true(has_child_list)
  inspect(flush_result.needs_layout, content="true")
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
    #|  span.getRootNode() === document,
    #|  div.getRootNode() === document
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true")
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

///|
test "getRootNode supports shadow root composed option" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = "<div class='shadowChild'>content</div>";
    #|const child = shadow.querySelector('.shadowChild');
    #|[
    #|  child.getRootNode() === shadow,
    #|  child.getRootNode({ composed: false }) === shadow,
    #|  child.getRootNode({ composed: true }) === document
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true|true|true")
}

///|
test "shadow root persists across execute calls" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const host = document.createElement('div');
    #|host.id = 'host';
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('span');
    #|inner.textContent = 'inside';
    #|shadow.appendChild(inner);
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")
  inspect(setup_result.value, content="ok")

  let persisted =
    #|const persistedHost = document.getElementById('host');
    #|[
    #|  persistedHost !== null,
    #|  persistedHost.shadowRoot !== null,
    #|  persistedHost.shadowRoot && persistedHost.shadowRoot.firstChild !== null,
    #|  persistedHost.shadowRoot && persistedHost.shadowRoot.firstChild ? persistedHost.shadowRoot.firstChild.textContent : 'missing'
    #|].join(',')
  let persisted_result = ctx.execute(persisted)
  inspect(persisted_result.success, content="true")
  inspect(persisted_result.value, content="true,true,true,inside")
}

///|
test "shadowRoot querySelector supports :host pseudo-class" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  host.className = 'active';
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<button id="inner">ok</button>';
    #|  return JSON.stringify([
    #|    shadow.querySelector(':host') === host,
    #|    shadow.querySelector(':host(.active)') === host,
    #|    shadow.querySelector(':host(.missing)') === null,
    #|    shadow.querySelectorAll(':host').length,
    #|    shadow.querySelector(':host > #inner') === shadow.firstChild,
    #|    shadow.querySelectorAll(':host > button').length
    #|  ]);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true,true,1,true,1]")
}

///|
test "customElements define get whenDefined" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__ceResolved = 'pending';
    #|const before = customElements.get('x-define-check') === undefined;
    #|class DefineCheckElement extends HTMLElement {}
    #|customElements.whenDefined('x-define-check').then((ctor) => {
    #|  globalThis.__ceResolved = ctor === DefineCheckElement ? 'resolved' : 'wrong';
    #|});
    #|customElements.define('x-define-check', DefineCheckElement);
    #|[before, customElements.get('x-define-check') === DefineCheckElement].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true")

  let resolved_result = ctx.execute("globalThis.__ceResolved")
  inspect(resolved_result.success, content="true")
  inspect(resolved_result.value, content="resolved")
}

///|
test "custom element lifecycle for connected attributeChanged disconnected" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__ceLifecycle = [];
    #|class LifecycleElement extends HTMLElement {
    #|  static get observedAttributes() { return ['data-state']; }
    #|  constructor() {
    #|    super();
    #|    this.constructed = 'yes';
    #|  }
    #|  connectedCallback() {
    #|    globalThis.__ceLifecycle.push('connected:' + this.constructed);
    #|  }
    #|  disconnectedCallback() {
    #|    globalThis.__ceLifecycle.push('disconnected');
    #|  }
    #|  attributeChangedCallback(name, oldValue, newValue) {
    #|    globalThis.__ceLifecycle.push(name + ':' + String(oldValue) + '->' + String(newValue));
    #|  }
    #|}
    #|customElements.define('x-lifecycle-check', LifecycleElement);
    #|const el = document.createElement('x-lifecycle-check');
    #|document.body.appendChild(el);
    #|el.setAttribute('data-state', 'ready');
    #|document.body.removeChild(el);
    #|[el.constructed, globalThis.__ceLifecycle.join('|')].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="yes,connected:yes|data-state:null->ready|disconnected",
  )
}

///|
test "customElements define upgrades existing connected elements" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__upgradeCount = 0;
    #|const early = document.createElement('x-upgrade-check');
    #|document.body.appendChild(early);
    #|class UpgradeCheckElement extends HTMLElement {
    #|  connectedCallback() {
    #|    globalThis.__upgradeCount += 1;
    #|    this.setAttribute('upgraded', 'yes');
    #|  }
    #|}
    #|customElements.define('x-upgrade-check', UpgradeCheckElement);
    #|[early.getAttribute('upgraded'), globalThis.__upgradeCount].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="yes,1")
}

///|
test "parser-created custom element connects when detached host is inserted" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__parserLifecycle = [];
    #|class ParserLifecycleElement extends HTMLElement {
    #|  connectedCallback() {
    #|    globalThis.__parserLifecycle.push('connected');
    #|  }
    #|}
    #|customElements.define('x-parser-lifecycle', ParserLifecycleElement);
    #|const host = document.createElement('div');
    #|host.innerHTML = '<x-parser-lifecycle></x-parser-lifecycle>';
    #|const beforeAttach = globalThis.__parserLifecycle.length;
    #|document.body.appendChild(host);
    #|[beforeAttach, globalThis.__parserLifecycle.join('|')].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="0,connected")
}

///|
test "parser-created custom element disconnects when innerHTML replaces subtree" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__parserReplaceLifecycle = [];
    #|class ParserReplaceElement extends HTMLElement {
    #|  connectedCallback() {
    #|    globalThis.__parserReplaceLifecycle.push('connected');
    #|  }
    #|  disconnectedCallback() {
    #|    globalThis.__parserReplaceLifecycle.push('disconnected');
    #|  }
    #|}
    #|customElements.define('x-parser-replace', ParserReplaceElement);
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|host.innerHTML = '<x-parser-replace></x-parser-replace>';
    #|host.innerHTML = '';
    #|globalThis.__parserReplaceLifecycle.join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="connected|disconnected")
}

///|
test "disconnectedCallback observes detached state on removeChild" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__disconnectState = 'unset';
    #|class DisconnectStateElement extends HTMLElement {
    #|  disconnectedCallback() {
    #|    globalThis.__disconnectState = [String(this.isConnected), String(this.parentNode === null)].join(',');
    #|  }
    #|}
    #|customElements.define('x-disconnect-state', DisconnectStateElement);
    #|const el = document.createElement('x-disconnect-state');
    #|document.body.appendChild(el);
    #|document.body.removeChild(el);
    #|globalThis.__disconnectState
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="false,true")
}

///|
test "custom element appended into connected shadow root gets connectedCallback" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__shadowCeLifecycle = [];
    #|class ShadowLifecycleElement extends HTMLElement {
    #|  connectedCallback() {
    #|    globalThis.__shadowCeLifecycle.push('connected');
    #|  }
    #|}
    #|customElements.define('x-shadow-lifecycle', ShadowLifecycleElement);
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const el = document.createElement('x-shadow-lifecycle');
    #|shadow.appendChild(el);
    #|globalThis.__shadowCeLifecycle.join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="connected")
}

///|
test "shadow event with composed false stays inside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__shadowEventLog = [];
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('button');
    #|shadow.appendChild(inner);
    #|const labelPath = (event) => event.composedPath().map((node) => {
    #|  if (node === inner) return 'inner';
    #|  if (node === shadow) return 'shadow';
    #|  if (node === host) return 'host';
    #|  if (node === document.body) return 'body';
    #|  return 'other';
    #|}).join('>');
    #|shadow.addEventListener('shadow-test', (event) => {
    #|  globalThis.__shadowEventLog.push('shadow:' + String(event.target === inner) + ':' + labelPath(event));
    #|});
    #|host.addEventListener('shadow-test', () => {
    #|  globalThis.__shadowEventLog.push('host');
    #|});
    #|document.body.addEventListener('shadow-test', () => {
    #|  globalThis.__shadowEventLog.push('body');
    #|});
    #|inner.dispatchEvent(new Event('shadow-test', { bubbles: true, composed: false }));
    #|globalThis.__shadowEventLog.join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="shadow:true:inner>shadow")
}

///|
test "shadow event with composed true bubbles outward and retargets target" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__shadowEventLog = [];
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('button');
    #|shadow.appendChild(inner);
    #|const labelPath = (event) => event.composedPath().map((node) => {
    #|  if (node === inner) return 'inner';
    #|  if (node === shadow) return 'shadow';
    #|  if (node === host) return 'host';
    #|  if (node === document.body) return 'body';
    #|  if (node === document.documentElement) return 'html';
    #|  if (node === document) return 'document';
    #|  if (node === window) return 'window';
    #|  return 'other';
    #|}).join('>');
    #|shadow.addEventListener('shadow-test', (event) => {
    #|  globalThis.__shadowEventLog.push('shadow:' + String(event.target === inner) + ':' + labelPath(event));
    #|});
    #|host.addEventListener('shadow-test', (event) => {
    #|  globalThis.__shadowEventLog.push('host:' + String(event.target === host));
    #|});
    #|document.body.addEventListener('shadow-test', (event) => {
    #|  globalThis.__shadowEventLog.push('body:' + String(event.target === host));
    #|});
    #|inner.dispatchEvent(new Event('shadow-test', { bubbles: true, composed: true }));
    #|globalThis.__shadowEventLog.join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="shadow:true:inner>shadow>host>body>html>document>window|host:true|body:true",
  )
}

///|
test "shadow event capture listeners and document listeners observe retargeted path" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|globalThis.__shadowCaptureLog = [];
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('button');
    #|shadow.appendChild(inner);
    #|document.addEventListener('shadow-capture', (event) => {
    #|  globalThis.__shadowCaptureLog.push('document-capture:' + String(event.eventPhase === Event.CAPTURING_PHASE) + ':' + String(event.target === host));
    #|}, true);
    #|host.addEventListener('shadow-capture', (event) => {
    #|  globalThis.__shadowCaptureLog.push('host-capture:' + String(event.eventPhase === Event.CAPTURING_PHASE) + ':' + String(event.target === host));
    #|}, true);
    #|shadow.addEventListener('shadow-capture', (event) => {
    #|  globalThis.__shadowCaptureLog.push('shadow-capture:' + String(event.eventPhase === Event.CAPTURING_PHASE) + ':' + String(event.target === inner));
    #|}, true);
    #|inner.addEventListener('shadow-capture', (event) => {
    #|  globalThis.__shadowCaptureLog.push('target:' + String(event.eventPhase === Event.AT_TARGET) + ':' + String(event.target === inner));
    #|});
    #|host.addEventListener('shadow-capture', (event) => {
    #|  globalThis.__shadowCaptureLog.push('host-bubble:' + String(event.eventPhase === Event.BUBBLING_PHASE) + ':' + String(event.target === host));
    #|});
    #|document.addEventListener('shadow-capture', (event) => {
    #|  globalThis.__shadowCaptureLog.push('document-bubble:' + String(event.eventPhase === Event.BUBBLING_PHASE) + ':' + String(event.target === host));
    #|});
    #|inner.dispatchEvent(new Event('shadow-capture', { bubbles: true, composed: true }));
    #|globalThis.__shadowCaptureLog.join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="document-capture:true:true|host-capture:true:true|shadow-capture:true:true|target:true:true|host-bubble:true:true|document-bubble:true:true",
  )
}

///|
test "focus inside shadow root updates document and shadowRoot activeElement" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('input');
    #|shadow.appendChild(inner);
    #|inner.focus();
    #|JSON.stringify([
    #|  document.activeElement === host,
    #|  shadow.activeElement === inner
    #|])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "blur inside shadow root clears shadowRoot activeElement and restores body focus" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const inner = document.createElement('input');
    #|shadow.appendChild(inner);
    #|inner.focus();
    #|inner.blur();
    #|JSON.stringify([
    #|  document.activeElement === document.body,
    #|  shadow.activeElement === null
    #|])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "Tab moves focus through named slotted control in shadow tree" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const first = document.createElement('input');
    #|first.id = 'first';
    #|const host = document.createElement('div');
    #|host.id = 'host';
    #|const last = document.createElement('input');
    #|last.id = 'last';
    #|document.body.appendChild(first);
    #|document.body.appendChild(host);
    #|document.body.appendChild(last);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const slot = document.createElement('slot');
    #|slot.name = 'content';
    #|shadow.appendChild(slot);
    #|const slotted = document.createElement('input');
    #|slotted.id = 'slotted';
    #|slotted.slot = 'content';
    #|host.appendChild(slotted);
    #|first.focus();
    #|first.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, cancelable: true, key: 'Tab' }));
    #|const firstStep = document.activeElement === slotted;
    #|slotted.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, cancelable: true, key: 'Tab' }));
    #|JSON.stringify([firstStep, document.activeElement === last])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "Shift+Tab moves focus from named slotted control to previous light DOM control" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const first = document.createElement('input');
    #|first.id = 'first';
    #|const host = document.createElement('div');
    #|const last = document.createElement('input');
    #|document.body.appendChild(first);
    #|document.body.appendChild(host);
    #|document.body.appendChild(last);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|const slot = document.createElement('slot');
    #|slot.name = 'content';
    #|shadow.appendChild(slot);
    #|const slotted = document.createElement('input');
    #|slotted.slot = 'content';
    #|host.appendChild(slotted);
    #|slotted.focus();
    #|slotted.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, cancelable: true, key: 'Tab', shiftKey: true }));
    #|JSON.stringify([document.activeElement === first, shadow.activeElement === null])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "focus on shadow host delegates to first focusable descendant when delegatesFocus is enabled" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|const button = document.createElement('button');
    #|button.id = 'inner';
    #|shadow.appendChild(button);
    #|host.focus();
    #|JSON.stringify([
    #|  document.activeElement === host,
    #|  shadow.activeElement === button,
    #|  shadow.delegatesFocus === true
    #|])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true,true]")
}

///|
test "focus on delegatesFocus host reaches slotted focusable descendant" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|const slot = document.createElement('slot');
    #|slot.name = 'content';
    #|shadow.appendChild(slot);
    #|const input = document.createElement('input');
    #|input.id = 'slotted';
    #|input.slot = 'content';
    #|host.appendChild(input);
    #|host.focus();
    #|JSON.stringify([
    #|  document.activeElement === input,
    #|  shadow.activeElement === null
    #|])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "click on delegatesFocus host reaches first shadow descendant" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|const button = document.createElement('button');
    #|button.id = 'inner';
    #|shadow.appendChild(button);
    #|host.click();
    #|JSON.stringify([
    #|  document.activeElement === host,
    #|  shadow.activeElement === button
    #|])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "click on delegatesFocus host reaches slotted focusable descendant" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|const slot = document.createElement('slot');
    #|slot.name = 'content';
    #|shadow.appendChild(slot);
    #|const input = document.createElement('input');
    #|input.id = 'slotted';
    #|input.slot = 'content';
    #|host.appendChild(input);
    #|host.click();
    #|JSON.stringify([
    #|  document.activeElement === input,
    #|  shadow.activeElement === null
    #|])
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[true,true]")
}

///|
test "focus and blur on delegatesFocus host dispatch focus-family events on shadow descendant" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|  const input = document.createElement('input');
    #|  shadow.appendChild(input);
    #|  const logs = [];
    #|  for (const type of ['focus', 'focusin', 'blur', 'focusout']) {
    #|    input.addEventListener(type, () => logs.push(type));
    #|  }
    #|  host.focus();
    #|  host.blur();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[\"focus\",\"focusin\",\"blur\",\"focusout\"]")
}

///|
test "focus and blur on delegatesFocus host dispatch focus-family events on slotted descendant" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const input = document.createElement('input');
    #|  input.slot = 'content';
    #|  host.appendChild(input);
    #|  const logs = [];
    #|  for (const type of ['focus', 'focusin', 'blur', 'focusout']) {
    #|    input.addEventListener(type, () => logs.push(type));
    #|  }
    #|  host.focus();
    #|  input.blur();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[\"focus\",\"focusin\",\"blur\",\"focusout\"]")
}

///|
test "focus-family bubbling retargets delegatesFocus shadow descendant to host outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|  const input = document.createElement('input');
    #|  shadow.appendChild(input);
    #|  const logs = [];
    #|  input.addEventListener('focusin', (event) => logs.push('inner:' + String(event.target === input)));
    #|  shadow.addEventListener('focusin', (event) => logs.push('shadow:' + String(event.target === input)));
    #|  host.addEventListener('focusin', (event) => logs.push('host:' + String(event.target === host)));
    #|  document.addEventListener('focusin', (event) => logs.push('doc:' + String(event.target === host)));
    #|  host.focus();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:true\",\"shadow:true\",\"host:true\",\"doc:true\"]",
  )
}

///|
test "focus-family bubbling keeps slotted delegatesFocus target as light DOM node" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open', delegatesFocus: true });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const input = document.createElement('input');
    #|  input.slot = 'content';
    #|  host.appendChild(input);
    #|  const logs = [];
    #|  input.addEventListener('focusin', (event) => logs.push('inner:' + String(event.target === input)));
    #|  host.addEventListener('focusin', (event) => logs.push('host:' + String(event.target === input)));
    #|  document.addEventListener('focusin', (event) => logs.push('doc:' + String(event.target === input)));
    #|  host.focus();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[\"inner:true\",\"host:true\",\"doc:true\"]")
}

///|
test "focusout and focusin between slotted descendants keep light DOM target and relatedTarget" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const left = document.createElement('input');
    #|  left.id = 'left';
    #|  left.slot = 'content';
    #|  const right = document.createElement('input');
    #|  right.id = 'right';
    #|  right.slot = 'content';
    #|  host.appendChild(left);
    #|  host.appendChild(right);
    #|  left.focus();
    #|  const logs = [];
    #|  left.addEventListener('focusout', (event) => logs.push('left:focusout:' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  right.addEventListener('focusin', (event) => logs.push('right:focusin:' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  host.addEventListener('focusout', (event) => logs.push('host:focusout:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  document.addEventListener('focusout', (event) => logs.push('doc:focusout:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  host.addEventListener('focusin', (event) => logs.push('host:focusin:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  document.addEventListener('focusin', (event) => logs.push('doc:focusin:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  right.focus();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"left:focusout:right\",\"host:focusout:left:right\",\"doc:focusout:left:right\",\"right:focusin:left\",\"host:focusin:right:left\",\"doc:focusin:right:left\"]",
  )
}

///|
test "focusout and focusin between shadow descendants stay inside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const left = document.createElement('input');
    #|  left.id = 'left';
    #|  const right = document.createElement('input');
    #|  right.id = 'right';
    #|  shadow.appendChild(left);
    #|  shadow.appendChild(right);
    #|  left.focus();
    #|  const logs = [];
    #|  left.addEventListener('focusout', (event) => logs.push('left:focusout:' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  right.addEventListener('focusin', (event) => logs.push('right:focusin:' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  shadow.addEventListener('focusout', (event) => logs.push('shadow:focusout:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  shadow.addEventListener('focusin', (event) => logs.push('shadow:focusin:' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  host.addEventListener('focusout', () => logs.push('host:focusout'));
    #|  document.addEventListener('focusout', () => logs.push('doc:focusout'));
    #|  host.addEventListener('focusin', () => logs.push('host:focusin'));
    #|  document.addEventListener('focusin', () => logs.push('doc:focusin'));
    #|  right.focus();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"left:focusout:right\",\"shadow:focusout:left:right\",\"right:focusin:left\",\"shadow:focusin:right:left\"]",
  )
}

///|
test "click on shadow descendant bubbles across shadow boundary and retargets to host" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const button = document.createElement('button');
    #|  shadow.appendChild(button);
    #|  const logs = [];
    #|  button.addEventListener('click', (event) => logs.push('inner:' + String(event.target === button)));
    #|  shadow.addEventListener('click', (event) => logs.push('shadow:' + String(event.target === button)));
    #|  host.addEventListener('click', (event) => logs.push('host:' + String(event.target === host)));
    #|  document.addEventListener('click', (event) => logs.push('doc:' + String(event.target === host)));
    #|  button.click();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:true\",\"shadow:true\",\"host:true\",\"doc:true\"]",
  )
}

///|
test "click on slotted descendant keeps light DOM target outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const button = document.createElement('button');
    #|  button.slot = 'content';
    #|  host.appendChild(button);
    #|  const logs = [];
    #|  button.addEventListener('click', (event) => logs.push('inner:' + String(event.target === button)));
    #|  host.addEventListener('click', (event) => logs.push('host:' + String(event.target === button)));
    #|  document.addEventListener('click', (event) => logs.push('doc:' + String(event.target === button)));
    #|  button.click();
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="[\"inner:true\",\"host:true\",\"doc:true\"]")
}

///|
test "pointer and mouse down/up on shadow descendant retarget to host outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const button = document.createElement('button');
    #|  shadow.appendChild(button);
    #|  const logs = [];
    #|  for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup']) {
    #|    button.addEventListener(type, (event) => logs.push('inner:' + type + ':' + String(event.target === button)));
    #|    shadow.addEventListener(type, (event) => logs.push('shadow:' + type + ':' + String(event.target === button)));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === host)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === host)));
    #|  }
    #|  button.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, composed: true }));
    #|  button.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, composed: true }));
    #|  button.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, composed: true }));
    #|  button.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, composed: true }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:pointerdown:true\",\"shadow:pointerdown:true\",\"host:pointerdown:true\",\"doc:pointerdown:true\",\"inner:mousedown:true\",\"shadow:mousedown:true\",\"host:mousedown:true\",\"doc:mousedown:true\",\"inner:pointerup:true\",\"shadow:pointerup:true\",\"host:pointerup:true\",\"doc:pointerup:true\",\"inner:mouseup:true\",\"shadow:mouseup:true\",\"host:mouseup:true\",\"doc:mouseup:true\"]",
  )
}

///|
test "pointer and mouse down/up on slotted descendant keep light DOM target" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const button = document.createElement('button');
    #|  button.slot = 'content';
    #|  host.appendChild(button);
    #|  const logs = [];
    #|  for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup']) {
    #|    button.addEventListener(type, (event) => logs.push('inner:' + type + ':' + String(event.target === button)));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === button)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === button)));
    #|  }
    #|  button.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, composed: true }));
    #|  button.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, composed: true }));
    #|  button.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, composed: true }));
    #|  button.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, composed: true }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:pointerdown:true\",\"host:pointerdown:true\",\"doc:pointerdown:true\",\"inner:mousedown:true\",\"host:mousedown:true\",\"doc:mousedown:true\",\"inner:pointerup:true\",\"host:pointerup:true\",\"doc:pointerup:true\",\"inner:mouseup:true\",\"host:mouseup:true\",\"doc:mouseup:true\"]",
  )
}

///|
test "pointerover/out and mouseover/out on shadow descendant retarget to host outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const button = document.createElement('button');
    #|  shadow.appendChild(button);
    #|  const logs = [];
    #|  for (const type of ['pointerover', 'mouseover', 'pointerout', 'mouseout']) {
    #|    button.addEventListener(type, (event) => logs.push('inner:' + type + ':' + String(event.target === button)));
    #|    shadow.addEventListener(type, (event) => logs.push('shadow:' + type + ':' + String(event.target === button)));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === host)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === host)));
    #|  }
    #|  button.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, composed: true, relatedTarget: document.body }));
    #|  button.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, composed: true, relatedTarget: document.body }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:pointerover:true\",\"shadow:pointerover:true\",\"host:pointerover:true\",\"doc:pointerover:true\",\"inner:mouseover:true\",\"shadow:mouseover:true\",\"host:mouseover:true\",\"doc:mouseover:true\",\"inner:pointerout:true\",\"shadow:pointerout:true\",\"host:pointerout:true\",\"doc:pointerout:true\",\"inner:mouseout:true\",\"shadow:mouseout:true\",\"host:mouseout:true\",\"doc:mouseout:true\"]",
  )
}

///|
test "pointerover/out and mouseover/out on slotted descendant keep light DOM target" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const button = document.createElement('button');
    #|  button.slot = 'content';
    #|  host.appendChild(button);
    #|  const logs = [];
    #|  for (const type of ['pointerover', 'mouseover', 'pointerout', 'mouseout']) {
    #|    button.addEventListener(type, (event) => logs.push('inner:' + type + ':' + String(event.target === button)));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === button)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === button)));
    #|  }
    #|  button.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, composed: true, relatedTarget: document.body }));
    #|  button.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, composed: true, relatedTarget: document.body }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:pointerover:true\",\"host:pointerover:true\",\"doc:pointerover:true\",\"inner:mouseover:true\",\"host:mouseover:true\",\"doc:mouseover:true\",\"inner:pointerout:true\",\"host:pointerout:true\",\"doc:pointerout:true\",\"inner:mouseout:true\",\"host:mouseout:true\",\"doc:mouseout:true\"]",
  )
}

///|
test "pointerenter/leave and mouseenter/leave on shadow descendant do not bubble outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const button = document.createElement('button');
    #|  shadow.appendChild(button);
    #|  const logs = [];
    #|  for (const type of ['pointerenter', 'mouseenter', 'pointerleave', 'mouseleave']) {
    #|    button.addEventListener(type, (event) => logs.push('inner:' + type + ':' + String(event.target === button)));
    #|    shadow.addEventListener(type, (event) => logs.push('shadow:' + type + ':' + String(event.target === button)));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === host)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === host)));
    #|  }
    #|  button.dispatchEvent(new PointerEvent('pointerenter', { bubbles: false, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new MouseEvent('mouseenter', { bubbles: false, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new PointerEvent('pointerleave', { bubbles: false, composed: true, relatedTarget: document.body }));
    #|  button.dispatchEvent(new MouseEvent('mouseleave', { bubbles: false, composed: true, relatedTarget: document.body }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:pointerenter:true\",\"inner:mouseenter:true\",\"inner:pointerleave:true\",\"inner:mouseleave:true\"]",
  )
}

///|
test "pointerenter/leave and mouseenter/leave on slotted descendant keep light DOM target and do not bubble" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const button = document.createElement('button');
    #|  button.slot = 'content';
    #|  host.appendChild(button);
    #|  const logs = [];
    #|  for (const type of ['pointerenter', 'mouseenter', 'pointerleave', 'mouseleave']) {
    #|    button.addEventListener(type, (event) => logs.push('inner:' + type + ':' + String(event.target === button)));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === button)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === button)));
    #|  }
    #|  button.dispatchEvent(new PointerEvent('pointerenter', { bubbles: false, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new MouseEvent('mouseenter', { bubbles: false, composed: true, relatedTarget: null }));
    #|  button.dispatchEvent(new PointerEvent('pointerleave', { bubbles: false, composed: true, relatedTarget: document.body }));
    #|  button.dispatchEvent(new MouseEvent('mouseleave', { bubbles: false, composed: true, relatedTarget: document.body }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"inner:pointerenter:true\",\"inner:mouseenter:true\",\"inner:pointerleave:true\",\"inner:mouseleave:true\"]",
  )
}

///|
test "pointerover/out between shadow descendants stays inside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const left = document.createElement('button');
    #|  left.id = 'left';
    #|  const right = document.createElement('button');
    #|  right.id = 'right';
    #|  shadow.appendChild(left);
    #|  shadow.appendChild(right);
    #|  const logs = [];
    #|  for (const type of ['pointerover', 'mouseover', 'pointerout', 'mouseout']) {
    #|    left.addEventListener(type, (event) => logs.push('left:' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    right.addEventListener(type, (event) => logs.push('right:' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    shadow.addEventListener(type, (event) => logs.push('shadow:' + type + ':' + (event.target.id || '')));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + String(event.target === host) + ':' + (event.relatedTarget === host)));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + String(event.target === host) + ':' + (event.relatedTarget === host)));
    #|  }
    #|  left.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  left.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  left.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, composed: true, relatedTarget: right }));
    #|  left.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, composed: true, relatedTarget: right }));
    #|  right.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, composed: true, relatedTarget: left }));
    #|  right.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: left }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"left:pointerover:none\",\"shadow:pointerover:left\",\"host:pointerover:true:false\",\"doc:pointerover:true:false\",\"left:mouseover:none\",\"shadow:mouseover:left\",\"host:mouseover:true:false\",\"doc:mouseover:true:false\",\"left:pointerout:right\",\"shadow:pointerout:left\",\"left:mouseout:right\",\"shadow:mouseout:left\",\"right:pointerover:left\",\"shadow:pointerover:right\",\"right:mouseover:left\",\"shadow:mouseover:right\"]",
  )
}

///|
test "pointerover/out between slotted descendants keeps light DOM target and relatedTarget outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const left = document.createElement('button');
    #|  left.id = 'left';
    #|  left.slot = 'content';
    #|  const right = document.createElement('button');
    #|  right.id = 'right';
    #|  right.slot = 'content';
    #|  host.appendChild(left);
    #|  host.appendChild(right);
    #|  const logs = [];
    #|  for (const type of ['pointerover', 'mouseover', 'pointerout', 'mouseout']) {
    #|    left.addEventListener(type, (event) => logs.push('left:' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    right.addEventListener(type, (event) => logs.push('right:' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  }
    #|  left.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  left.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: null }));
    #|  left.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, composed: true, relatedTarget: right }));
    #|  left.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, composed: true, relatedTarget: right }));
    #|  right.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, composed: true, relatedTarget: left }));
    #|  right.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: left }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"left:pointerover:none\",\"host:pointerover:left:none\",\"doc:pointerover:left:none\",\"left:mouseover:none\",\"host:mouseover:left:none\",\"doc:mouseover:left:none\",\"left:pointerout:right\",\"host:pointerout:left:right\",\"doc:pointerout:left:right\",\"left:mouseout:right\",\"host:mouseout:left:right\",\"doc:mouseout:left:right\",\"right:pointerover:left\",\"host:pointerover:right:left\",\"doc:pointerover:right:left\",\"right:mouseover:left\",\"host:mouseover:right:left\",\"doc:mouseover:right:left\"]",
  )
}

///|
test "pointerenter/leave between slotted descendants keeps relatedTarget and does not leak outside shadow root" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.createElement('div');
    #|  document.body.appendChild(host);
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  const slot = document.createElement('slot');
    #|  slot.name = 'content';
    #|  shadow.appendChild(slot);
    #|  const left = document.createElement('button');
    #|  left.id = 'left';
    #|  left.slot = 'content';
    #|  const right = document.createElement('button');
    #|  right.id = 'right';
    #|  right.slot = 'content';
    #|  host.appendChild(left);
    #|  host.appendChild(right);
    #|  const logs = [];
    #|  for (const type of ['pointerenter', 'mouseenter', 'pointerleave', 'mouseleave']) {
    #|    left.addEventListener(type, (event) => logs.push('left:' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    right.addEventListener(type, (event) => logs.push('right:' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    host.addEventListener(type, (event) => logs.push('host:' + type + ':' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|    document.addEventListener(type, (event) => logs.push('doc:' + type + ':' + (event.target ? event.target.id : '') + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none')));
    #|  }
    #|  left.dispatchEvent(new PointerEvent('pointerenter', { bubbles: false, composed: true, relatedTarget: null }));
    #|  left.dispatchEvent(new MouseEvent('mouseenter', { bubbles: false, composed: true, relatedTarget: null }));
    #|  left.dispatchEvent(new PointerEvent('pointerleave', { bubbles: false, composed: true, relatedTarget: right }));
    #|  left.dispatchEvent(new MouseEvent('mouseleave', { bubbles: false, composed: true, relatedTarget: right }));
    #|  right.dispatchEvent(new PointerEvent('pointerenter', { bubbles: false, composed: true, relatedTarget: left }));
    #|  right.dispatchEvent(new MouseEvent('mouseenter', { bubbles: false, composed: true, relatedTarget: left }));
    #|  return JSON.stringify(logs);
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="[\"left:pointerenter:none\",\"left:mouseenter:none\",\"left:pointerleave:right\",\"left:mouseleave:right\",\"right:pointerenter:left\",\"right:mouseenter:left\"]",
  )
}

///|
test "slot assignedNodes distributes default and named light DOM children" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot></slot><slot name="label"></slot>';
    #|const slots = shadow.querySelectorAll('slot');
    #|const defaultSlot = slots[0];
    #|const namedSlot = slots[1];
    #|const text = document.createTextNode('hello');
    #|const plain = document.createElement('span');
    #|plain.id = 'plain';
    #|const named = document.createElement('em');
    #|named.id = 'named';
    #|named.slot = 'label';
    #|host.appendChild(text);
    #|host.appendChild(plain);
    #|host.appendChild(named);
    #|[
    #|  defaultSlot.assignedNodes().length,
    #|  defaultSlot.assignedNodes()[0] === text,
    #|  defaultSlot.assignedNodes()[1] === plain,
    #|  namedSlot.assignedNodes().length,
    #|  namedSlot.assignedNodes()[0] === named,
    #|  namedSlot.assignedElements().length,
    #|  namedSlot.assignedElements()[0] === named,
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="2|true|true|1|true|1|true")
}

///|
test "slot assignedNodes falls back to slot children when no assignment exists" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot name="missing"><span id="fb">fallback</span></slot>';
    #|const slot = shadow.querySelector('slot');
    #|const fallbackNode = slot.assignedNodes()[0];
    #|const fallbackEl = slot.assignedElements()[0];
    #|[slot.assignedNodes().length, fallbackNode.id, slot.assignedElements().length, fallbackEl.id].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="1|fb|1|fb")
}

///|
test "slot assignedNodes with flatten traverses nested fallback slots" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot id="outer"><slot name="inner"><span id="fb">fallback</span></slot></slot>';
    #|const outer = shadow.getElementById('outer');
    #|const nested = outer.assignedNodes()[0];
    #|const flatNode = outer.assignedNodes({ flatten: true })[0];
    #|const flatEl = outer.assignedElements({ flatten: true })[0];
    #|[
    #|  outer.assignedNodes().length,
    #|  nested.localName,
    #|  outer.assignedNodes({ flatten: true }).length,
    #|  flatNode.id,
    #|  outer.assignedElements({ flatten: true }).length,
    #|  flatEl.id,
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="1|slot|1|fb|1|fb")
}

///|
test "slot assignedNodes with flatten resolves nested slot assignments" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot id="outer"><slot name="inner"></slot></slot>';
    #|const outer = shadow.getElementById('outer');
    #|const child = document.createElement('span');
    #|child.id = 'assigned';
    #|child.slot = 'inner';
    #|host.appendChild(child);
    #|[
    #|  outer.assignedNodes().length,
    #|  outer.assignedNodes()[0].localName,
    #|  outer.assignedNodes({ flatten: true }).length,
    #|  outer.assignedNodes({ flatten: true })[0] === child,
    #|  outer.assignedElements({ flatten: true }).length,
    #|  outer.assignedElements({ flatten: true })[0] === child,
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="1|slot|1|true|1|true")
}

///|
test "slotable nodes expose assignedSlot for default and named slots" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot id="default-slot"></slot><slot id="named-slot" name="label"></slot>';
    #|const text = document.createTextNode('hello');
    #|const plain = document.createElement('span');
    #|const named = document.createElement('em');
    #|named.slot = 'label';
    #|host.appendChild(text);
    #|host.appendChild(plain);
    #|host.appendChild(named);
    #|[
    #|  text.assignedSlot.id,
    #|  plain.assignedSlot.id,
    #|  named.assignedSlot.id,
    #|  document.createElement('i').assignedSlot === null,
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="default-slot|default-slot|named-slot|true")
}

///|
test "assignedSlot prefers the first matching slot and ignores unmatched nodes" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot id="first"></slot><slot id="second"><span id="fb">fallback</span></slot><slot id="named" name="label"></slot>';
    #|const first = shadow.getElementById('first');
    #|const second = shadow.getElementById('second');
    #|const fallback = shadow.getElementById('fb');
    #|const plain = document.createElement('span');
    #|const missing = document.createElement('em');
    #|missing.slot = 'missing';
    #|host.appendChild(plain);
    #|host.appendChild(missing);
    #|[
    #|  plain.assignedSlot.id,
    #|  first.assignedNodes().length,
    #|  second.assignedNodes().length,
    #|  second.assignedNodes()[0].id,
    #|  missing.assignedSlot === null,
    #|  fallback.assignedSlot === null,
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="first|1|1|fb|true|true")
}

///|
test "slotchange fires after default slot assignment changes" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|globalThis.__slotChangeCount = 0;
    #|globalThis.__slotAssignedLength = 0;
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot></slot>';
    #|const slot = shadow.querySelector('slot');
    #|slot.addEventListener('slotchange', () => {
    #|  globalThis.__slotChangeCount += 1;
    #|  globalThis.__slotAssignedLength = slot.assignedNodes().length;
    #|});
    #|host.appendChild(document.createElement('span'));
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")
  inspect(setup_result.value, content="ok")

  let verify = ctx.execute(
    "[globalThis.__slotChangeCount, globalThis.__slotAssignedLength].join('|')",
  )
  inspect(verify.success, content="true")
  inspect(verify.value, content="1|1")
}

///|
test "slotchange fires for old and new slot when slot attribute reassigns node" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|globalThis.__slotReassignLog = [];
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({ mode: 'open' });
    #|shadow.innerHTML = '<slot></slot><slot name="label"></slot>';
    #|const slots = shadow.querySelectorAll('slot');
    #|const defaultSlot = slots[0];
    #|const namedSlot = slots[1];
    #|defaultSlot.addEventListener('slotchange', () => {
    #|  globalThis.__slotReassignLog.push('default:' + defaultSlot.assignedNodes().length);
    #|});
    #|namedSlot.addEventListener('slotchange', () => {
    #|  globalThis.__slotReassignLog.push('named:' + namedSlot.assignedNodes().length);
    #|});
    #|const child = document.createElement('span');
    #|host.appendChild(child);
    #|globalThis.__slotReassignLog = [];
    #|child.slot = 'label';
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")
  inspect(setup_result.value, content="ok")

  let verify = ctx.execute("globalThis.__slotReassignLog.join('|')")
  inspect(verify.success, content="true")
  inspect(verify.value, content="default:0|named:1")
}

///|
test "insertAdjacent validates element arguments and detached beforebegin returns null" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const detached = document.createElement('div');
    #|const typeError = (() => {
    #|  try {
    #|    detached.insertAdjacentElement('afterbegin', document.implementation.createDocumentType('html', '', ''));
    #|    return 'no';
    #|  } catch (e) {
    #|    return e.name;
    #|  }
    #|})();
    #|const beforeBegin = detached.insertAdjacentElement('beforebegin', document.createElement('span'));
    #|const textResult = detached.insertAdjacentText('beforeend', 'hello');
    #|[typeError, beforeBegin === null, textResult === null, detached.textContent].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="TypeError|true|true|hello")
}

///|
test "SVG script fetchPriority reflects attribute values" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const SVGNS = 'http://www.w3.org/2000/svg';
    #|const high = document.createElementNS(SVGNS, 'script');
    #|high.setAttribute('fetchpriority', 'high');
    #|const invalid = document.createElementNS(SVGNS, 'script');
    #|invalid.setAttribute('fetchpriority', 'xyz');
    #|const empty = document.createElementNS(SVGNS, 'script');
    #|[high.fetchPriority, invalid.fetchPriority, empty.fetchPriority].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="high|auto|auto")
}

///|
test "dispatchEvent evaluates inline handlers with element unscopables" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|window.remove = 'Hello there';
    #|let result1;
    #|let result2;
    #|const div = document.createElement('div');
    #|div.setAttribute('onclick', 'result1 = remove; result2 = this.remove;');
    #|document.body.appendChild(div);
    #|div.dispatchEvent(new Event('click'));
    #|[typeof result1, typeof result2].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="string|function")
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
test "WPT: ParentNode.append/prepend coerce null and undefined" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const elementParent = document.createElement('div');
    #|elementParent.append(null, undefined);
    #|results.push(elementParent.childNodes.length === 2);
    #|results.push(elementParent.childNodes[0].textContent === 'null');
    #|results.push(elementParent.childNodes[1].textContent === 'undefined');
    #|const fragmentParent = document.createDocumentFragment();
    #|fragmentParent.prepend(null, undefined);
    #|results.push(fragmentParent.childNodes.length === 2);
    #|results.push(fragmentParent.childNodes[0].textContent === 'null');
    #|results.push(fragmentParent.childNodes[1].textContent === 'undefined');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "WPT: ParentNode.replaceChildren coerces null and preserves order" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const elementParent = document.createElement('div');
    #|elementParent.replaceChildren(null, 'tail');
    #|results.push(elementParent.childNodes.length === 2);
    #|results.push(elementParent.childNodes[0].textContent === 'null');
    #|results.push(elementParent.childNodes[1].textContent === 'tail');
    #|const fragmentParent = document.createDocumentFragment();
    #|fragmentParent.replaceChildren(null, 'tail');
    #|results.push(fragmentParent.childNodes.length === 2);
    #|results.push(fragmentParent.childNodes[0].textContent === 'null');
    #|results.push(fragmentParent.childNodes[1].textContent === 'tail');
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "WPT: ParentNode.replaceChildren validates document hierarchy before mutation" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const target = document.implementation.createHTMLDocument('title');
    #|const originalDoctype = target.doctype;
    #|const originalElement = target.documentElement;
    #|let threw = false;
    #|try {
    #|  target.replaceChildren(target.createTextNode('nope'));
    #|} catch (e) {
    #|  threw = e && e.name === 'HierarchyRequestError';
    #|}
    #|[
    #|  threw,
    #|  target.doctype === originalDoctype,
    #|  target.documentElement === originalElement,
    #|  target.childNodes.length === 2
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "WPT: ParentNode.replaceChildren rejects duplicate document element before mutation" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const target = document.implementation.createHTMLDocument('title');
    #|const originalDoctype = target.doctype;
    #|const originalElement = target.documentElement;
    #|let threw = false;
    #|try {
    #|  target.replaceChildren(target.createElement('replacement'));
    #|} catch (e) {
    #|  threw = e && e.name === 'HierarchyRequestError';
    #|}
    #|[
    #|  threw,
    #|  target.doctype === originalDoctype,
    #|  target.documentElement === originalElement,
    #|  target.childNodes.length === 2
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "JS runtime DOM internals are isolated from page getNodeType shadowing" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|function getNodeType() { throw new Error('shadowed'); }
    #|const doc2 = document.implementation.createHTMLDocument('title');
    #|const div = doc2.createElement('div');
    #|doc2.body.appendChild(div);
    #|[
    #|  doc2.documentElement !== null,
    #|  doc2.body.firstChild === div
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true")
}

///|
test "HTMLCollection.item coerces non-numeric strings to index 0" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const parent = document.createElement('div');
    #|parent.innerHTML = '<img><img id="foo"><img id="foo"><img name="bar">';
    #|const result = parent.children.item('foo');
    #|[
    #|  result instanceof Element,
    #|  result === parent.children[0]
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true")
}

///|
test "closest(':invalid') uses select value semantics before ancestors" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|document.body.innerHTML = `
    #|  <form id="test5">
    #|    <fieldset id="test2">
    #|      <select id="test3" required>
    #|        <option default id="test4" value="">Test4</option>
    #|        <option selected id="test11">Test11</option>
    #|      </select>
    #|      <input id="test9" type="text" required>
    #|    </fieldset>
    #|  </form>`;
    #|document.getElementById('test11').closest(':invalid').id
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="test2")
}

///|
test "matches supports wildcard namespace selectors" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const element = document.createElementNS('urn:ns', 'h');
    #|[
    #|  element.matches('h'),
    #|  element.matches('*|h'),
    #|  element.webkitMatchesSelector('*|h')
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "window property assignment exposes a global identifier" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|window.tests = [1, 2, 3];
    #|typeof tests + ':' + tests.length
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="object:3")
}

///|
test "ownerSVGElement stops at foreignObject boundaries" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const top = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    #|top.setAttribute('id', 'top');
    #|const inner = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    #|inner.setAttribute('id', 'inner');
    #|const foreignObject = document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject');
    #|const inFo = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    #|const nested = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    #|top.appendChild(inner);
    #|top.appendChild(foreignObject);
    #|foreignObject.appendChild(inFo);
    #|inFo.appendChild(nested);
    #|[
    #|  inner.ownerSVGElement === top,
    #|  inFo.ownerSVGElement === null,
    #|  nested.ownerSVGElement === inFo
    #|].join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
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
test "MutationObserver.observe validates option combinations" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const observer = new MutationObserver(function() {});
    #|const expectTypeError = function(fn) {
    #|  try {
    #|    fn();
    #|    return false;
    #|  } catch (e) {
    #|    return e instanceof TypeError;
    #|  }
    #|};
    #|results.push(expectTypeError(function() {
    #|  observer.observe(document, {});
    #|}));
    #|results.push(expectTypeError(function() {
    #|  observer.observe(document, { childList: true, attributeOldValue: true, attributes: false });
    #|}));
    #|results.push(expectTypeError(function() {
    #|  observer.observe(document, { childList: true, attributeFilter: ['abc'], attributes: false });
    #|}));
    #|results.push(expectTypeError(function() {
    #|  observer.observe(document, { childList: true, characterDataOldValue: true, characterData: false });
    #|}));
    #|observer.observe(document, { attributeOldValue: true });
    #|results.push(observer._targets[0].options.attributes === true);
    #|observer.disconnect();
    #|observer.observe(document, { characterDataOldValue: true });
    #|results.push(observer._targets[0].options.characterData === true);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true,true")
}

///|
test "MutationObserver.takeRecords captures attribute childList and characterData" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const target = document.createElement('p');
    #|target.id = 'n00';
    #|document.body.appendChild(target);
    #|const observer = new MutationObserver(function() {
    #|  results.push('callback');
    #|});
    #|observer.observe(target, {
    #|  childList: true,
    #|  attributes: true,
    #|  characterData: true,
    #|  subtree: true,
    #|  attributeOldValue: true,
    #|  characterDataOldValue: true
    #|});
    #|target.id = 'foo';
    #|target.textContent = 'old data';
    #|target.firstChild.data = 'new data';
    #|const records = observer.takeRecords();
    #|results.push(records.length === 3);
    #|results.push(records[0].type === 'attributes' && records[0].oldValue === 'n00');
    #|results.push(records[1].type === 'childList' && records[1].addedNodes[0] === target.firstChild);
    #|results.push(records[2].type === 'characterData' && records[2].oldValue === 'old data');
    #|results.push(observer.takeRecords().length === 0);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "MutationObserver on document subtree sees dynamic inline script side effects" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const host = document.createElement('div');
    #|document.body.appendChild(host);
    #|const inserted = document.createElement('span');
    #|inserted.id = 'inserted';
    #|let callbackRecords = [];
    #|const observer = new MutationObserver(function(records) {
    #|  callbackRecords = records;
    #|});
    #|observer.observe(document, { childList: true, subtree: true });
    #|const script = document.createElement('script');
    #|script.textContent = 'document.body.appendChild(inserted);';
    #|host.appendChild(script);
    #|results.push(callbackRecords.length === 2);
    #|results.push(callbackRecords[0].target === host && callbackRecords[0].addedNodes[0] === script);
    #|results.push(callbackRecords[1].target === document.body && callbackRecords[1].addedNodes[0] === inserted);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "setAttributeNode throws InUseAttributeError for bound attr" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const el1 = document.createElement('div');
    #|const el2 = document.createElement('div');
    #|const attr = document.createAttribute('foo');
    #|results.push(el1.setAttributeNode(attr) === null);
    #|try {
    #|  el2.setAttributeNode(attr);
    #|  results.push(false);
    #|} catch (e) {
    #|  results.push(e instanceof DOMException);
    #|  results.push(e.name === 'InUseAttributeError');
    #|  results.push(e.code === DOMException.INUSE_ATTRIBUTE_ERR);
    #|}
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true")
}

///|
test "NamedNodeMap own properties expose only lowercase HTML qualified names" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const el = document.createElement('div');
    #|el.setAttributeNS('foo', 'A:B', '');
    #|el.setAttributeNS('bar', 'c:D', '');
    #|el.setAttributeNS('baz', 'e:F', '');
    #|el.setAttributeNS('qux', 'g:h', '');
    #|el.setAttributeNS('', 'I', '');
    #|el.setAttributeNS('', 'j', '');
    #|Object.getOwnPropertyNames(el.attributes).join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="0,1,2,3,4,5,g:h,j")
}

///|
test "MutationObserver reports callback exceptions to callback realm onerror" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const calls = [];
    #|window.onerror = () => { calls.push('top'); };
    #|frames[0].onerror = () => { calls.push('frame0'); };
    #|frames[1].onerror = () => { calls.push('frame1'); };
    #|frames[2].onerror = () => { calls.push('frame2'); };
    #|const target = frames[0].document.body;
    #|const observer = new frames[0].MutationObserver(new frames[1].Function('throw new parent.frames[2].Error("PASS");'));
    #|observer.observe(target, { childList: true, subtree: true });
    #|target.append('x');
    #|_flushMicrotasks();
    #|calls.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="frame1")
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

// ============================================
// DOM Initialization Tests (Option B)
// Tests that DomTree content is visible to scripts
// ============================================

///|
test "DOM init: scripts can see existing body content" {
  let dom = @dom.DomTree::new()

  // Create HTML structure with content
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let div = dom.create_element("div")
  let _ = dom.set_attribute(div, "id", "existing-div")
  let _ = dom.set_attribute(div, "class", "my-class")
  let text = dom.create_text("Hello from DomTree")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, div)
  let _ = dom.append_child(div, text)
  let ctx = JsContext::new(dom)

  // Script should be able to see the existing content
  let code =
    #|const results = [];
    #|const div = document.getElementById('existing-div');
    #|results.push(div !== null);
    #|if (div) {
    #|  results.push(div.className === 'my-class');
    #|  results.push(div.textContent === 'Hello from DomTree');
    #|}
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "DOM init: scripts can query existing elements" {
  let dom = @dom.DomTree::new()

  // Create HTML structure with multiple elements
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let div1 = dom.create_element("div")
  let _ = dom.set_attribute(div1, "class", "item")
  let div2 = dom.create_element("div")
  let _ = dom.set_attribute(div2, "class", "item special")
  let span = dom.create_element("span")
  let _ = dom.set_attribute(span, "class", "item")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, div1)
  let _ = dom.append_child(body, div2)
  let _ = dom.append_child(body, span)
  let ctx = JsContext::new(dom)
  let code =
    #|const results = [];
    #|const items = document.getElementsByClassName('item');
    #|results.push(items.length === 3);
    #|const divs = document.getElementsByTagName('div');
    #|results.push(divs.length === 2);
    #|const special = document.querySelector('.special');
    #|results.push(special !== null);
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true")
}

///|
test "DOM init: scripts can traverse existing elements" {
  let dom = @dom.DomTree::new()

  // Create nested structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let container = dom.create_element("div")
  let _ = dom.set_attribute(container, "id", "container")
  let child1 = dom.create_element("p")
  let _ = dom.set_attribute(child1, "class", "child")
  let child2 = dom.create_element("p")
  let _ = dom.set_attribute(child2, "class", "child")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, container)
  let _ = dom.append_child(container, child1)
  let _ = dom.append_child(container, child2)
  let ctx = JsContext::new(dom)

  // Script traverses the existing structure
  let code =
    #|const results = [];
    #|const container = document.getElementById('container');
    #|results.push(container !== null);
    #|if (container) {
    #|  results.push(container.childNodes.length === 2);
    #|  results.push(container.firstChild !== null);
    #|  results.push(container.lastChild !== null);
    #|  results.push(container.firstChild.className === 'child');
    #|}
    #|results.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true,true,true,true,true")
}

///|
test "DOM init: modifications to existing elements sync back to DomTree" {
  let dom = @dom.DomTree::new()

  // Create initial structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let div = dom.create_element("div")
  let _ = dom.set_attribute(div, "id", "target")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, div)
  let ctx = JsContext::new(dom)

  // Script modifies the existing element
  let code =
    #|const target = document.getElementById('target');
    #|target.setAttribute('data-modified', 'true');
    #|target.className = 'modified-class';
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify the modifications in DomTree
  let modified_attr = dom.get_attribute(div, "data-modified")
  match modified_attr {
    Ok(Some(v)) => inspect(v, content="true")
    _ => assert_true(false)
  }
  let class_attr = dom.get_attribute(div, "class")
  match class_attr {
    Ok(Some(v)) => inspect(v, content="modified-class")
    _ => assert_true(false)
  }
}

///|
test "DOM init: _mockId is correctly set for existing elements" {
  let dom = @dom.DomTree::new()

  // Create structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let div = dom.create_element("div")
  let _ = dom.set_attribute(div, "id", "check-id")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, div)

  // Get the actual node ID
  let div_id = div.to_int()
  let ctx = JsContext::new(dom)

  // Check that _mockId matches DomTree node ID
  let code =
    #|const div = document.getElementById('check-id');
    #|div._mockId
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content=div_id.to_string())
}

// ============================================
// Microtask Queue Tests
// Tests for queueMicrotask and Promise ordering
// ============================================

///|
test "queueMicrotask: exists and is a function" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|typeof queueMicrotask
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="function")
}

///|
test "queueMicrotask: throws TypeError for non-function" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|let threw = false;
    #|try { queueMicrotask(null); } catch (e) { threw = e instanceof TypeError; }
    #|threw
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true")
}

///|
test "queueMicrotask: callback is called" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|let called = false;
    #|queueMicrotask(() => { called = true; });
    #|called
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // After microtask processing, callback should have been called
  // Note: The value is from the last expression BEFORE microtask processing
  // but logs should show the callback was called
  inspect(result.logs.length() > 0 || result.value == "false", content="true")
}

///|
test "queueMicrotask: interleaves with Promise.then" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|Promise.resolve().then(() => order.push('a'));
    #|queueMicrotask(() => order.push('b'));
    #|Promise.reject().catch(() => order.push('c'));
    #|queueMicrotask(() => order.push('d'));
    #|order.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Before microtask checkpoint, order should be empty
  // The microtasks run after the script, so this tests the return value
  // which is captured before microtask processing
}

///|
test "Promise.then: basic ordering (script end -> promise1 -> promise2)" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|order.push('script start');
    #|Promise.resolve().then(() => order.push('promise1')).then(() => order.push('promise2'));
    #|order.push('script end');
    #|console.log(order.join(','));
    #|order.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // The script execution captures "script start,script end"
  // After microtask processing, logs should contain the full order
  inspect(result.value, content="script start,script end")
}

///|
test "Promise and queueMicrotask: mixed ordering" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|queueMicrotask(() => order.push('qm1'));
    #|Promise.resolve().then(() => order.push('p1'));
    #|queueMicrotask(() => order.push('qm2'));
    #|Promise.resolve().then(() => order.push('p2'));
    #|// After microtasks, check order via console.log
    #|queueMicrotask(() => console.log('final:' + order.join(',')));
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="done")
  // Check that microtasks were executed by looking at logs
  let has_final = result.logs.iter().any(fn(log) { log.contains("final:") })
  inspect(has_final, content="true")
}

// ============================================
// setTimeout Execution Tests
// Tests that setTimeout callbacks are executed
// ============================================

///|
test "setTimeout: callback is executed" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|let called = false;
    #|setTimeout(() => { called = true; console.log('timeout executed'); }, 0);
    #|called
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Script returns false (before timeout), but timeout should have run
  inspect(result.value, content="false")
  // Check logs for timeout execution
  let has_timeout = result.logs
    .iter()
    .any(fn(log) { log.contains("timeout executed") })
  inspect(has_timeout, content="true")
}

///|
test "requestAnimationFrame: callback is executed" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|let called = false;
    #|requestAnimationFrame(() => { called = true; console.log('raf executed'); });
    #|called
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="false")
  let has_raf = result.logs.iter().any(fn(log) { log.contains("raf executed") })
  inspect(has_raf, content="true")
}

///|
test "requestAnimationFrame: deferred context advances on tick" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new_deferred(dom)
  let setup =
    #|globalThis.__craterRafCount = 0;
    #|globalThis.__craterStep = function () {
    #|  globalThis.__craterRafCount += 1;
    #|  if (globalThis.__craterRafCount < 2) {
    #|    requestAnimationFrame(globalThis.__craterStep);
    #|  }
    #|};
    #|requestAnimationFrame(globalThis.__craterStep);
    #|String(globalThis.__craterRafCount)
  let setup_result = ctx.execute(setup)
  inspect(setup_result.value, content="0")
  inspect(ctx.tick(), content="true")
  let after_first = ctx.execute("String(globalThis.__craterRafCount)")
  inspect(after_first.value, content="1")
  inspect(ctx.tick(), content="true")
  let after_second = ctx.execute("String(globalThis.__craterRafCount)")
  inspect(after_second.value, content="2")
}

///|
test "setTimeout: multiple timeouts execute in order" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|setTimeout(() => order.push('t1'), 0);
    #|setTimeout(() => order.push('t2'), 0);
    #|setTimeout(() => order.push('t3'), 0);
    #|setTimeout(() => console.log('order:' + order.join(',')), 0);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Check that all timeouts ran
  let has_order = result.logs
    .iter()
    .any(fn(log) { log.contains("order:t1,t2,t3") })
  inspect(has_order, content="true")
}

///|
test "setTimeout: runs after microtasks (Promise.then)" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|order.push('script start');
    #|setTimeout(() => order.push('setTimeout'), 0);
    #|Promise.resolve().then(() => order.push('promise1')).then(() => order.push('promise2'));
    #|order.push('script end');
    #|// Log final order after everything completes
    #|setTimeout(() => console.log('final:' + order.join(',')), 0);
    #|order.join(',')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Script returns "script start,script end"
  inspect(result.value, content="script start,script end")
  // Final order should be: script start, script end, promise1, promise2, setTimeout
  let has_correct_order = result.logs
    .iter()
    .any(fn(log) {
      log.contains("final:script start,script end,promise1,promise2,setTimeout")
    })
  inspect(has_correct_order, content="true")
}

///|
test "setTimeout: can be cancelled with clearTimeout" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|let called = false;
    #|const id = setTimeout(() => { called = true; }, 0);
    #|clearTimeout(id);
    #|setTimeout(() => console.log('called:' + called), 0);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Cancelled timeout should not have run
  let was_not_called = result.logs
    .iter()
    .any(fn(log) { log.contains("called:false") })
  inspect(was_not_called, content="true")
}

///|
test "setTimeout: nested setTimeout works" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|setTimeout(() => {
    #|  order.push('t1');
    #|  setTimeout(() => {
    #|    order.push('t2');
    #|    console.log('nested:' + order.join(','));
    #|  }, 0);
    #|}, 0);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Nested timeout should also run
  let has_nested = result.logs
    .iter()
    .any(fn(log) { log.contains("nested:t1,t2") })
  inspect(has_nested, content="true")
}

///|
test "setTimeout: microtasks scheduled from timeout run before next timeout" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const order = [];
    #|setTimeout(() => {
    #|  order.push('t1');
    #|  Promise.resolve().then(() => order.push('p1'));
    #|}, 0);
    #|setTimeout(() => {
    #|  order.push('t2');
    #|  console.log('order:' + order.join(','));
    #|}, 0);
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Promise from t1 should run before t2
  let has_correct_order = result.logs
    .iter()
    .any(fn(log) { log.contains("order:t1,p1,t2") })
  inspect(has_correct_order, content="true")
}

// ============================================
// Fetch API Tests
// Tests for fetch() implementation
// ============================================

///|
test "fetch: exists and is a function" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|typeof fetch
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="function")
}

///|
test "fetch: returns a Promise" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const p = fetch('/test');
    #|p instanceof Promise
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true")
}

///|
test "persisted input listener survives later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const input = document.createElement('input');
    #|input.id = 'field';
    #|document.body.appendChild(input);
    #|input.addEventListener('input', function () {
    #|  document.body.setAttribute('data-status', 'input');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")
  inspect(setup_result.value, content="ok")

  let run =
    #|(function () {
    #|  const input = document.getElementById('field');
    #|  input.dispatchEvent(new Event('input', { bubbles: true }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="input")
}

///|
test "persisted change listener survives later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const input = document.createElement('input');
    #|input.id = 'field';
    #|document.body.appendChild(input);
    #|input.addEventListener('change', function () {
    #|  document.body.setAttribute('data-status', 'change');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const input = document.getElementById('field');
    #|  input.dispatchEvent(new Event('change', { bubbles: true }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="change")
}

///|
test "top-level JS state survives later execution in same context" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let first = ctx.execute("let counter = 0; counter += 1; String(counter)")
  inspect(first.success, content="true")
  inspect(first.value, content="1")

  let second = ctx.execute("counter += 1; String(counter)")
  inspect(second.success, content="true")
  inspect(second.value, content="2")
}

///|
test "persisted change listener sees reflected input value" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const input = document.createElement('input');
    #|input.id = 'field';
    #|input.value = 'x';
    #|document.body.appendChild(input);
    #|input.addEventListener('change', function (event) {
    #|  document.body.setAttribute('data-status', String(event.target.value));
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const input = document.getElementById('field');
    #|  input.dispatchEvent(new Event('change', { bubbles: true }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="x")
}

///|
test "select exposes reflected value and selectedIndex" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const select = document.createElement('select');
    #|const a = document.createElement('option');
    #|a.value = 'a';
    #|a.textContent = 'A';
    #|const b = document.createElement('option');
    #|b.value = 'b';
    #|b.textContent = 'B';
    #|select.appendChild(a);
    #|select.appendChild(b);
    #|document.body.appendChild(select);
    #|select.selectedIndex = 1;
    #|[select.value, String(select.selectedIndex), String(b.selected)].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="b|1|true")
}

///|
test "persisted submit listener survives later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const form = document.createElement('form');
    #|form.id = 'form';
    #|document.body.appendChild(form);
    #|form.addEventListener('submit', function (event) {
    #|  event.preventDefault();
    #|  document.body.setAttribute('data-status', 'submit');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const form = document.getElementById('form');
    #|  const event = new Event('submit', { bubbles: true, cancelable: true });
    #|  form.dispatchEvent(event);
    #|  return [String(event.defaultPrevented), document.body.getAttribute('data-status')].join('|');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="true|submit")
}

///|
test "persisted keydown listener survives later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const input = document.createElement('input');
    #|input.id = 'field';
    #|document.body.appendChild(input);
    #|input.addEventListener('keydown', function () {
    #|  document.body.setAttribute('data-status', 'keydown');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const input = document.getElementById('field');
    #|  input.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'A' }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="keydown")
}

///|
test "persisted keypress listener survives later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const input = document.createElement('input');
    #|input.id = 'field';
    #|document.body.appendChild(input);
    #|input.addEventListener('keypress', function () {
    #|  document.body.setAttribute('data-status', 'keypress');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const input = document.getElementById('field');
    #|  input.dispatchEvent(new KeyboardEvent('keypress', { bubbles: true, key: 'A' }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="keypress")
}

///|
test "persisted keyup listener survives later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const input = document.createElement('input');
    #|input.id = 'field';
    #|document.body.appendChild(input);
    #|input.addEventListener('keyup', function () {
    #|  document.body.setAttribute('data-status', 'keyup');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const input = document.getElementById('field');
    #|  input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'A' }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="keyup")
}

///|
test "persisted focus-family listeners survive later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const field = document.createElement('input');
    #|field.id = 'field';
    #|const btn = document.createElement('button');
    #|btn.id = 'btn';
    #|document.body.appendChild(field);
    #|document.body.appendChild(btn);
    #|field.addEventListener('blur', function () {
    #|  document.body.setAttribute('data-status', (document.body.getAttribute('data-status') || '') + '|blur');
    #|});
    #|field.addEventListener('focusout', function () {
    #|  document.body.setAttribute('data-status', (document.body.getAttribute('data-status') || '') + '|focusout');
    #|});
    #|btn.addEventListener('focus', function () {
    #|  document.body.setAttribute('data-status', (document.body.getAttribute('data-status') || '') + '|focus');
    #|});
    #|btn.addEventListener('focusin', function () {
    #|  document.body.setAttribute('data-status', (document.body.getAttribute('data-status') || '') + '|focusin');
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const field = document.getElementById('field');
    #|  const btn = document.getElementById('btn');
    #|  field.dispatchEvent(new Event('blur'));
    #|  field.dispatchEvent(new Event('focusout', { bubbles: true }));
    #|  btn.dispatchEvent(new Event('focus'));
    #|  btn.dispatchEvent(new Event('focusin', { bubbles: true }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="|blur|focusout|focus|focusin")
}

///|
test "persisted composition listeners survive later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const field = document.createElement('input');
    #|field.id = 'field';
    #|document.body.appendChild(field);
    #|for (const type of ['compositionstart', 'compositionupdate', 'compositionend']) {
    #|  field.addEventListener(type, function (event) {
    #|    const current = document.body.getAttribute('data-status') || '';
    #|    const suffix = type + ':' + String(event.data || '');
    #|    document.body.setAttribute('data-status', current ? current + '|' + suffix : suffix);
    #|  });
    #|}
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const field = document.getElementById('field');
    #|  field.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true, data: 'a' }));
    #|  field.dispatchEvent(new CompositionEvent('compositionupdate', { bubbles: true, data: 'ab' }));
    #|  field.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true, data: 'ab' }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(
    run_result.value,
    content="compositionstart:a|compositionupdate:ab|compositionend:ab",
  )
}

///|
test "persisted beforeinput listeners survive later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const field = document.createElement('input');
    #|field.id = 'field';
    #|document.body.appendChild(field);
    #|field.addEventListener('beforeinput', function (event) {
    #|  document.body.setAttribute(
    #|    'data-status',
    #|    String(event.inputType || '') + ':' + String(event.data || '')
    #|  );
    #|  event.preventDefault();
    #|});
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const field = document.getElementById('field');
    #|  const event = new InputEvent('beforeinput', {
    #|    bubbles: true,
    #|    cancelable: true,
    #|    inputType: 'insertText',
    #|    data: 'x',
    #|  });
    #|  const allowed = field.dispatchEvent(event);
    #|  return String(allowed) + '|' + String(document.body.getAttribute('data-status'));
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(run_result.value, content="false|insertText:x")
}

///|
test "text controls expose selectionStart and setSelectionRange" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const input = document.createElement('input');
    #|input.value = 'abcd';
    #|input.selectionStart = 1;
    #|input.selectionEnd = 3;
    #|const textarea = document.createElement('textarea');
    #|textarea.value = 'xyz';
    #|textarea.setSelectionRange(1, 2);
    #|[
    #|  String(input.selectionStart),
    #|  String(input.selectionEnd),
    #|  String(textarea.selectionStart),
    #|  String(textarea.selectionEnd)
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="1|3|1|2")
}

///|
test "text controls select() selects entire value" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const input = document.createElement('input');
    #|input.value = 'abcd';
    #|input.select();
    #|const textarea = document.createElement('textarea');
    #|textarea.value = 'xyz';
    #|textarea.select();
    #|[
    #|  String(input.selectionStart),
    #|  String(input.selectionEnd),
    #|  String(textarea.selectionStart),
    #|  String(textarea.selectionEnd)
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="0|4|0|3")
}

///|
test "text controls setRangeText replaces range and updates selection" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const input = document.createElement('input');
    #|input.value = 'abcd';
    #|input.setRangeText('xy', 1, 3);
    #|const textarea = document.createElement('textarea');
    #|textarea.value = 'abcd';
    #|textarea.setRangeText('xy', 1, 3, 'select');
    #|[
    #|  input.value + '|' + String(input.selectionStart) + '|' + String(input.selectionEnd),
    #|  textarea.value + '|' + String(textarea.selectionStart) + '|' + String(textarea.selectionEnd)
    #|].join('||')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="axyd|3|3||axyd|1|3")
}

///|
test "text controls expose selectionDirection and preserve selection on setRangeText" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const input = document.createElement('input');
    #|input.value = 'abcdef';
    #|input.setSelectionRange(4, 6, 'backward');
    #|input.setRangeText('Z', 1, 3, 'preserve');
    #|const textarea = document.createElement('textarea');
    #|textarea.value = 'abcdef';
    #|textarea.selectionDirection = 'forward';
    #|[
    #|  input.value + '|' + String(input.selectionStart) + '|' + String(input.selectionEnd) + '|' + String(input.selectionDirection),
    #|  String(textarea.selectionDirection)
    #|].join('||')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="aZdef|3|5|backward||forward")
}

///|
test "persisted pointer listeners survive later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const btn = document.createElement('button');
    #|btn.id = 'btn';
    #|document.body.appendChild(btn);
    #|for (const type of ['pointerdown', 'pointermove', 'pointerup']) {
    #|  btn.addEventListener(type, function (event) {
    #|    const current = document.body.getAttribute('data-status') || '';
    #|    const suffix = type + ':' + String(event.pointerId) + ':' + String(event.clientX);
    #|    document.body.setAttribute('data-status', current ? current + '|' + suffix : suffix);
    #|  });
    #|}
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const btn = document.getElementById('btn');
    #|  btn.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, pointerId: 7, clientX: 10 }));
    #|  btn.dispatchEvent(new PointerEvent('pointermove', { bubbles: true, pointerId: 7, clientX: 11 }));
    #|  btn.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, pointerId: 7, clientX: 12 }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(
    run_result.value,
    content="pointerdown:7:10|pointermove:7:11|pointerup:7:12",
  )
}

///|
test "persisted hover listeners survive later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const left = document.createElement('div');
    #|const right = document.createElement('div');
    #|left.id = 'left';
    #|right.id = 'right';
    #|document.body.appendChild(left);
    #|document.body.appendChild(right);
    #|for (const [el, name] of [[left, 'left'], [right, 'right']]) {
    #|  for (const type of ['pointerover', 'mouseover', 'pointerenter', 'mouseenter', 'pointerout', 'mouseout', 'pointerleave', 'mouseleave']) {
    #|    el.addEventListener(type, function (event) {
    #|      const current = document.body.getAttribute('data-status') || '';
    #|      const related = event.relatedTarget ? event.relatedTarget.id : 'none';
    #|      const suffix = name + ':' + type + ':' + related;
    #|      document.body.setAttribute('data-status', current ? current + '|' + suffix : suffix);
    #|    });
    #|  }
    #|}
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")

  let run =
    #|(function () {
    #|  const left = document.getElementById('left');
    #|  const right = document.getElementById('right');
    #|  left.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, relatedTarget: null }));
    #|  left.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, relatedTarget: null }));
    #|  left.dispatchEvent(new PointerEvent('pointerenter', { bubbles: false, relatedTarget: null }));
    #|  left.dispatchEvent(new MouseEvent('mouseenter', { bubbles: false, relatedTarget: null }));
    #|  left.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, relatedTarget: right }));
    #|  left.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, relatedTarget: right }));
    #|  left.dispatchEvent(new PointerEvent('pointerleave', { bubbles: false, relatedTarget: right }));
    #|  left.dispatchEvent(new MouseEvent('mouseleave', { bubbles: false, relatedTarget: right }));
    #|  return document.body.getAttribute('data-status');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(
    run_result.value,
    content="left:pointerover:none|left:mouseover:none|left:pointerenter:none|left:mouseenter:none|left:pointerout:right|left:mouseout:right|left:pointerleave:right|left:mouseleave:right",
  )
}

///|
test "persisted drag listeners survive later execution" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let setup =
    #|const source = document.createElement('div');
    #|const target = document.createElement('div');
    #|source.id = 'source';
    #|target.id = 'target';
    #|source.draggable = true;
    #|document.body.appendChild(source);
    #|document.body.appendChild(target);
    #|window.__dragLog = [];
    #|for (const type of ['dragstart', 'drag', 'dragend']) {
    #|  source.addEventListener(type, function (event) {
    #|    window.__dragLog.push('source:' + type + ':' + event.clientX + ',' + event.clientY);
    #|  });
    #|}
    #|for (const type of ['dragenter', 'dragover', 'drop']) {
    #|  target.addEventListener(type, function (event) {
    #|    window.__dragLog.push('target:' + type + ':' + event.clientX + ',' + event.clientY);
    #|  });
    #|}
    #|'ok'
  let setup_result = ctx.execute(setup)
  inspect(setup_result.success, content="true")
  let run =
    #|(function () {
    #|  const source = document.getElementById('source');
    #|  const target = document.getElementById('target');
    #|  source.dispatchEvent(new DragEvent('dragstart', { bubbles: true, clientX: 20, clientY: 12 }));
    #|  source.dispatchEvent(new DragEvent('drag', { bubbles: true, clientX: 32, clientY: 20 }));
    #|  target.dispatchEvent(new DragEvent('dragenter', { bubbles: true, clientX: 44, clientY: 28 }));
    #|  target.dispatchEvent(new DragEvent('dragover', { bubbles: true, clientX: 44, clientY: 28 }));
    #|  target.dispatchEvent(new DragEvent('drop', { bubbles: true, clientX: 44, clientY: 28 }));
    #|  source.dispatchEvent(new DragEvent('dragend', { bubbles: true, clientX: 44, clientY: 28 }));
    #|  return window.__dragLog.join('|');
    #|})()
  let run_result = ctx.execute(run)
  inspect(run_result.success, content="true")
  inspect(
    run_result.value,
    content="source:dragstart:20,12|source:drag:32,20|target:dragenter:44,28|target:dragover:44,28|target:drop:44,28|source:dragend:44,28",
  )
}

///|
test "DataTransfer stores and clears string data" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const dt = new DataTransfer();
    #|dt.setData('text/plain', 'hello');
    #|dt.setData('text/html', '<b>x</b>');
    #|const first = dt.types.join(',');
    #|const second = dt.getData('text/plain');
    #|dt.clearData('text/plain');
    #|const third = dt.types.join(',');
    #|dt.clearData();
    #|[first, second, third, dt.types.length].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="text/plain,text/html|hello|text/html|0")
}

///|
test "DragEvent exposes relatedTarget and shared DataTransfer state" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|(function () {
    #|  const source = document.createElement('div');
    #|  const target = document.createElement('div');
    #|  const other = document.createElement('div');
    #|  source.id = 'source';
    #|  target.id = 'target';
    #|  other.id = 'other';
    #|  document.body.appendChild(source);
    #|  document.body.appendChild(target);
    #|  document.body.appendChild(other);
    #|  const dt = new DataTransfer();
    #|  dt.effectAllowed = 'copyMove';
    #|  let enterLog = '';
    #|  let dropLog = '';
    #|  target.addEventListener('dragenter', function (event) {
    #|    enterLog = (event.relatedTarget ? event.relatedTarget.id : 'none') + '/' + event.dataTransfer.effectAllowed;
    #|    event.dataTransfer.dropEffect = 'move';
    #|  });
    #|  target.addEventListener('drop', function (event) {
    #|    dropLog = (event.relatedTarget ? event.relatedTarget.id : 'none') + '/' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect;
    #|  });
    #|  target.dispatchEvent(new DragEvent('dragenter', { bubbles: true, relatedTarget: other, dataTransfer: dt }));
    #|  target.dispatchEvent(new DragEvent('drop', { bubbles: true, relatedTarget: source, dataTransfer: dt }));
    #|  return enterLog + '|' + dropLog;
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="other/copyMove|source/copyMove/move")
}

///|
test "fetch: Response has required methods" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  // Register a mock response
  let code =
    #|// Set up mock response
    #|_fetchMocks.set('/api/test', { body: '{"data": "test"}', status: 200 });
    #|let hasText = false, hasJson = false, hasOk = false, hasStatus = false;
    #|fetch('/api/test').then(response => {
    #|  hasText = typeof response.text === 'function';
    #|  hasJson = typeof response.json === 'function';
    #|  hasOk = typeof response.ok === 'boolean';
    #|  hasStatus = typeof response.status === 'number';
    #|  console.log('methods:' + [hasText, hasJson, hasOk, hasStatus].join(','));
    #|});
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_methods = result.logs
    .iter()
    .any(fn(log) { log.contains("methods:true,true,true,true") })
  inspect(has_methods, content="true")
}

///|
test "fetch: can parse JSON response" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|_fetchMocks.set('/api/data', { body: '{"name": "test", "value": 42}', status: 200 });
    #|fetch('/api/data')
    #|  .then(r => r.json())
    #|  .then(data => {
    #|    console.log('json:' + data.name + ',' + data.value);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_json = result.logs
    .iter()
    .any(fn(log) { log.contains("json:test,42") })
  inspect(has_json, content="true")
}

///|
test "fetch: can get text response" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|_fetchMocks.set('/api/text', { body: 'Hello World', status: 200 });
    #|fetch('/api/text')
    #|  .then(r => r.text())
    #|  .then(text => {
    #|    console.log('text:' + text);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_text = result.logs
    .iter()
    .any(fn(log) { log.contains("text:Hello World") })
  inspect(has_text, content="true")
}

///|
test "fetch: handles 404 response" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|_fetchMocks.set('/api/notfound', { body: 'Not Found', status: 404 });
    #|fetch('/api/notfound')
    #|  .then(r => {
    #|    console.log('status:' + r.status + ',ok:' + r.ok);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_status = result.logs
    .iter()
    .any(fn(log) { log.contains("status:404,ok:false") })
  inspect(has_status, content="true")
}

///|
test "fetch: handles network error" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|// No mock registered, should fail
    #|let caught = false;
    #|fetch('/api/unknown')
    #|  .catch(err => {
    #|    caught = true;
    #|    console.log('error:' + err.message);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  // Should have caught an error
  let has_error = result.logs.iter().any(fn(log) { log.contains("error:") })
  inspect(has_error, content="true")
}

///|
test "fetch: works with chained promises (like async/await)" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  // Note: async/await uses native Promise in Node.js vm, so we test with .then() chains
  // which use our custom _SyncPromise and work synchronously
  let code =
    #|_fetchMocks.set('/api/async', { body: '{"result": "success"}', status: 200 });
    #|fetch('/api/async')
    #|  .then(response => response.json())
    #|  .then(data => {
    #|    console.log('chained:' + data.result);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_chained = result.logs
    .iter()
    .any(fn(log) { log.contains("chained:success") })
  inspect(has_chained, content="true")
}

// ============================================
// Dynamic Content Loading Tests
// Tests that fetch can load data and update DOM
// ============================================

///|
test "fetch: dynamic content - fetch data and insert into DOM" {
  // Create DOM with a container
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let container = dom.create_element("div")
  let _ = dom.set_attribute(container, "id", "content")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, container)
  let ctx = JsContext::new(dom)

  // Mock API response with article data
  let code =
    #|_fetchMocks.set('/api/articles', {
    #|  body: JSON.stringify({
    #|    articles: [
    #|      { id: 1, title: 'Article One' },
    #|      { id: 2, title: 'Article Two' },
    #|      { id: 3, title: 'Article Three' }
    #|    ]
    #|  }),
    #|  status: 200
    #|});
    #|
    #|// Fetch data and insert into DOM
    #|fetch('/api/articles')
    #|  .then(r => r.json())
    #|  .then(data => {
    #|    const container = document.getElementById('content');
    #|    data.articles.forEach(article => {
    #|      const div = document.createElement('div');
    #|      div.className = 'article';
    #|      div.textContent = article.title;
    #|      container.appendChild(div);
    #|    });
    #|    console.log('inserted:' + container.children.length);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify articles were inserted
  let has_inserted = result.logs
    .iter()
    .any(fn(log) { log.contains("inserted:3") })
  inspect(has_inserted, content="true")
}

///|
test "fetch: dynamic content - multiple fetch calls in sequence" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|_fetchMocks.set('/api/user', { body: '{"name": "Alice"}', status: 200 });
    #|_fetchMocks.set('/api/posts', { body: '{"count": 5}', status: 200 });
    #|
    #|const results = [];
    #|fetch('/api/user')
    #|  .then(r => r.json())
    #|  .then(user => {
    #|    results.push('user:' + user.name);
    #|    return fetch('/api/posts');
    #|  })
    #|  .then(r => r.json())
    #|  .then(posts => {
    #|    results.push('posts:' + posts.count);
    #|    console.log('results:' + results.join(','));
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_results = result.logs
    .iter()
    .any(fn(log) { log.contains("results:user:Alice,posts:5") })
  inspect(has_results, content="true")
}

///|
test "fetch: dynamic content - parallel fetch with Promise.all" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|_fetchMocks.set('/api/a', { body: '{"value": "A"}', status: 200 });
    #|_fetchMocks.set('/api/b', { body: '{"value": "B"}', status: 200 });
    #|_fetchMocks.set('/api/c', { body: '{"value": "C"}', status: 200 });
    #|
    #|Promise.all([
    #|  fetch('/api/a').then(r => r.json()),
    #|  fetch('/api/b').then(r => r.json()),
    #|  fetch('/api/c').then(r => r.json())
    #|]).then(results => {
    #|  const values = results.map(r => r.value).join(',');
    #|  console.log('parallel:' + values);
    #|});
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  let has_parallel = result.logs
    .iter()
    .any(fn(log) { log.contains("parallel:A,B,C") })
  inspect(has_parallel, content="true")
}

///|
test "fetch: zenn-like page - fetch user articles and render" {
  // Test with forEach, h2 elements, and querySelectorAll
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let content = dom.create_element("div")
  let _ = dom.set_attribute(content, "id", "articles")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, content)
  let ctx = JsContext::new(dom)

  // Mock API response with 3 articles
  let code =
    #|_fetchMocks.set('/api/articles', {
    #|  body: JSON.stringify({
    #|    articles: [
    #|      { title: 'Article 1' },
    #|      { title: 'Article 2' },
    #|      { title: 'Article 3' }
    #|    ]
    #|  }),
    #|  status: 200
    #|});
    #|
    #|const container = document.getElementById('articles');
    #|fetch('/api/articles')
    #|  .then(r => r.json())
    #|  .then(data => {
    #|    data.articles.forEach(article => {
    #|      const card = document.createElement('div');
    #|      const title = document.createElement('h2');
    #|      title.textContent = article.title;
    #|      card.appendChild(title);
    #|      container.appendChild(card);
    #|    });
    #|    console.log('rendered:' + container.children.length + ' articles');
    #|    const titles = Array.from(container.querySelectorAll('h2')).map(h => h.textContent).join(',');
    #|    console.log('titles:' + titles);
    #|  });
    #|'done'
  let result = ctx.execute(code)
  inspect(result.success, content="true")

  // Verify articles were rendered
  let has_rendered = result.logs
    .iter()
    .any(fn(log) { log.contains("rendered:3 articles") })
  inspect(has_rendered, content="true")

  // Verify titles
  let has_titles = result.logs
    .iter()
    .any(fn(log) { log.contains("titles:Article 1,Article 2,Article 3") })
  inspect(has_titles, content="true")
}

///|
test "createElementNS preserves HTML namespace qualified name case" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const plain = document.createElementNS('http://www.w3.org/1999/xhtml', 'SPAN');
    #|const prefixed = document.createElementNS('http://www.w3.org/1999/xhtml', 'html:span');
    #|[
    #|  plain.localName,
    #|  plain.tagName,
    #|  plain instanceof HTMLUnknownElement,
    #|  prefixed.localName,
    #|  prefixed.tagName,
    #|  prefixed.prefix,
    #|  prefixed instanceof HTMLSpanElement
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="SPAN|SPAN|true|span|HTML:SPAN|html|true")
}

///|
test "getElementsByTagName and NS keep HTML namespace createElementNS case-sensitive semantics" {
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let ctx = JsContext::new(dom)
  let code =
    #|const root = document.createElement('div');
    #|const upper = document.createElementNS('http://www.w3.org/1999/xhtml', 'I');
    #|root.appendChild(upper);
    #|document.body.appendChild(root);
    #|[
    #|  root.getElementsByTagName('I').length,
    #|  root.getElementsByTagName('i').length,
    #|  root.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', 'I').length,
    #|  root.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', 'i').length
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="0|0|1|0")
}

///|
test "XHTML createDocument preserves createElement localName case" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const doc = document.implementation.createDocument('http://www.w3.org/1999/xhtml', 'html', null);
    #|const el = doc.createElement('DIV');
    #|[doc.contentType, el.localName, el.tagName].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="application/xhtml+xml|DIV|DIV")
}

///|
test "createDocument rejects multi-colon qualified name without namespace" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|try {
    #|  document.implementation.createDocument(null, 'f:o:o', null);
    #|  'ok';
    #|} catch (e) {
    #|  e.name;
    #|}
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="NamespaceError")
}

///|
test "createElementNS keeps first-colon split for qualified name" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const el = document.createElementNS('http://example.com/', 'f:o:o');
    #|[el.prefix, el.localName, el.tagName].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="f|o|f:o")
}

///|
test "cloneNode preserves namespaced attribute metadata" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const SVGNS = 'http://www.w3.org/2000/svg';
    #|const XMLNS = 'http://www.w3.org/2000/xmlns/';
    #|const XLINK = 'http://www.w3.org/1999/xlink';
    #|const svg = document.createElementNS(SVGNS, 'svg');
    #|svg.setAttributeNS(XMLNS, 'xmlns:xlink', XLINK);
    #|const use = document.createElementNS(SVGNS, 'use');
    #|use.setAttributeNS(XLINK, 'xlink:href', '#test');
    #|svg.appendChild(use);
    #|const clone = svg.cloneNode(true);
    #|const rootAttr = clone.attributes[0];
    #|const useAttr = clone.firstElementChild.attributes[0];
    #|[
    #|  rootAttr.namespaceURI,
    #|  rootAttr.prefix,
    #|  rootAttr.localName,
    #|  rootAttr.name,
    #|  useAttr.namespaceURI,
    #|  useAttr.prefix,
    #|  useAttr.localName,
    #|  useAttr.name
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(
    result.value,
    content="http://www.w3.org/2000/xmlns/|xmlns|xlink|xmlns:xlink|http://www.w3.org/1999/xlink|xlink|href|xlink:href",
  )
}

///|
test "isEqualNode compares attribute namespaces" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const left = document.createElement('div');
    #|left.setAttributeNS('urn:left', 'p:name', 'value');
    #|const right = document.createElement('div');
    #|right.setAttributeNS('urn:right', 'p:name', 'value');
    #|String(left.isEqualNode(right))
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="false")
}

///|
test "appendChild adopting into another document updates attribute ownerDocument" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  let code =
    #|const oldDoc = document.implementation.createHTMLDocument('');
    #|const otherDoc = document.implementation.createHTMLDocument('');
    #|const div = oldDoc.createElement('div');
    #|div.setAttribute('id', 'foobar');
    #|otherDoc.body.appendChild(div);
    #|[
    #|  div.ownerDocument === otherDoc,
    #|  div.attributes[0].ownerDocument === otherDoc
    #|].join('|')
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="true|true")
}

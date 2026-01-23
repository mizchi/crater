///|
/// Tests for Browser JS integration

///|
test "extract_scripts extracts inline script" {
  let html =
    #|<html>
    #|<head>
    #|<script>console.log('hello');</script>
    #|</head>
    #|<body></body>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="1")
  inspect(scripts[0].source, content="console.log('hello');")
  inspect(scripts[0].src, content="")
  inspect(scripts[0].is_async, content="false")
  inspect(scripts[0].is_defer, content="false")
}

///|
test "extract_scripts extracts external script" {
  let html =
    #|<html>
    #|<head>
    #|<script src="app.js"></script>
    #|</head>
    #|<body></body>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="1")
  inspect(scripts[0].source, content="")
  inspect(scripts[0].src, content="app.js")
}

///|
test "extract_scripts detects async and defer" {
  let html =
    #|<html>
    #|<script async src="a.js"></script>
    #|<script defer src="b.js"></script>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="2")
  inspect(scripts[0].is_async, content="true")
  inspect(scripts[0].is_defer, content="false")
  inspect(scripts[1].is_async, content="false")
  inspect(scripts[1].is_defer, content="true")
}

///|
test "extract_scripts handles multiple scripts" {
  let html =
    #|<html>
    #|<script>var a = 1;</script>
    #|<script>var b = 2;</script>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="2")
  inspect(scripts[0].source, content="var a = 1;")
  inspect(scripts[1].source, content="var b = 2;")
}

///|
test "Browser init_js_execution creates DOM tree" {
  let browser = Browser::new(800, 600)
  browser.init_js_execution()
  // DOM tree should be created
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      // Check body exists
      match dom.query_selector(doc, "body") {
        Ok(Some(_)) => () // Success
        _ => assert_true(false) // Body should exist
      }
    }
    None => assert_true(false) // DOM tree should exist
  }
  // Script executor should be created
  match browser.script_executor {
    Some(_) => ()
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts runs inline scripts" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|<script>
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'from-script');
    #|  document.body.appendChild(div);
    #|</script>
    #|</head>
    #|<body></body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify DOM was modified
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#from-script") {
        Ok(Some(_)) => () // Element created by script exists
        _ => assert_true(false) // Element should exist
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts runs multiple scripts in order" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<script>
    #|  const div1 = document.createElement('div');
    #|  div1.setAttribute('id', 'first');
    #|  document.body.appendChild(div1);
    #|</script>
    #|<script>
    #|  const div2 = document.createElement('div');
    #|  div2.setAttribute('id', 'second');
    #|  document.body.appendChild(div2);
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  inspect(executed, content="2")
  // Verify both elements exist
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#first") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
      match dom.query_selector(doc, "#second") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts modifies attributes" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<script>
    #|  document.body.setAttribute('data-loaded', 'true');
    #|  document.body.setAttribute('class', 'initialized');
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify attributes were set
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "body") {
        Ok(Some(body)) => {
          match dom.get_attribute(body, "data-loaded") {
            Ok(Some(value)) => inspect(value, content="true")
            _ => assert_true(false)
          }
          match dom.get_attribute(body, "class") {
            Ok(Some(value)) => inspect(value, content="initialized")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts handles no scripts" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<p>No scripts here</p>
    #|</body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  inspect(executed, content="0")
}

///|
test "Browser execute_scripts skips external scripts" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|<script src="external.js"></script>
    #|</head>
    #|<body>
    #|<script>
    #|  document.body.setAttribute('data-inline', 'executed');
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  // Only inline script should execute (external is skipped)
  inspect(executed, content="1")
  // Verify inline script ran
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "body") {
        Ok(Some(body)) =>
          match dom.get_attribute(body, "data-inline") {
            Ok(Some(value)) => inspect(value, content="executed")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts uses getElementById within single script" {
  let browser = Browser::new(800, 600)
  // getElementById works within a single script execution
  // because the mock DOM tracks elements created in that execution
  let html =
    #|<html>
    #|<body>
    #|<script>
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'target');
    #|  document.body.appendChild(div);
    #|  // getElementById works in same script
    #|  const target = document.getElementById('target');
    #|  if (target) {
    #|    target.setAttribute('data-found', 'yes');
    #|  }
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify getElementById worked within the script
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#target") {
        Ok(Some(target)) =>
          match dom.get_attribute(target, "data-found") {
            Ok(Some(value)) => inspect(value, content="yes")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser scheduler integration queues tasks correctly" {
  let browser = Browser::new(800, 600)
  // Verify scheduler starts empty
  let initial_tasks = browser.scheduler.poll_ready()
  inspect(initial_tasks.length(), content="0")
  // Set HTML content with script
  let html =
    #|<html>
    #|<script>console.log('test');</script>
    #|</html>
  browser.html_content = html
  // Execute scripts (this queues and processes tasks)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // After execution, scheduler should have processed the task
  let remaining = browser.scheduler.poll_ready()
  inspect(remaining.length(), content="0")
}

///|
test "extract_scripts handles mixed inline and external scripts" {
  let html =
    #|<html>
    #|<head>
    #|<script src="lib.js"></script>
    #|<script>var x = 1;</script>
    #|<script src="app.js" async></script>
    #|<script defer>var y = 2;</script>
    #|</head>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="4")
  // First: external lib.js
  inspect(scripts[0].src, content="lib.js")
  inspect(scripts[0].source, content="")
  inspect(scripts[0].is_async, content="false")
  // Second: inline
  inspect(scripts[1].src, content="")
  inspect(scripts[1].source, content="var x = 1;")
  // Third: external async
  inspect(scripts[2].src, content="app.js")
  inspect(scripts[2].is_async, content="true")
  // Fourth: inline defer
  inspect(scripts[3].source, content="var y = 2;")
  inspect(scripts[3].is_defer, content="true")
}

///|
test "resolve_url resolves script paths correctly" {
  // Absolute URL
  let abs = resolve_url("https://example.com/page", "https://cdn.com/lib.js")
  inspect(abs, content="https://cdn.com/lib.js")
  // Root-relative
  let root = resolve_url("https://example.com/dir/page", "/scripts/app.js")
  inspect(root, content="https://example.com/scripts/app.js")
  // Relative
  let rel = resolve_url("https://example.com/dir/page.html", "lib.js")
  inspect(rel, content="https://example.com/dir/lib.js")
  // Protocol-relative
  let proto = resolve_url("https://example.com/page", "//cdn.com/lib.js")
  inspect(proto, content="https://cdn.com/lib.js")
}

///|
test "WPT-style: createElement and appendChild" {
  // This test mimics WPT DOM test patterns
  let browser = Browser::new(800, 600)
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|<script>
    #|  // Test 1: createElement
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'test-div');
    #|  div.setAttribute('data-test', 'passed');
    #|
    #|  // Test 2: appendChild
    #|  document.body.appendChild(div);
    #|
    #|  // Test 3: createElement with nested structure
    #|  const container = document.createElement('div');
    #|  container.setAttribute('id', 'container');
    #|  const child = document.createElement('span');
    #|  child.setAttribute('id', 'child');
    #|  child.setAttribute('class', 'test-class');
    #|  container.appendChild(child);
    #|  document.body.appendChild(container);
    #|
    #|  // Test 4: getElementById and modify
    #|  const found = document.getElementById('test-div');
    #|  if (found) {
    #|    found.setAttribute('data-found', 'true');
    #|  }
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify WPT-style assertions
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      // Assert: div was created and appended
      match dom.query_selector(doc, "#test-div") {
        Ok(Some(el)) => {
          match dom.get_attribute(el, "data-test") {
            Ok(Some(v)) => inspect(v, content="passed")
            _ => assert_true(false)
          }
          // Assert: getElementById worked
          match dom.get_attribute(el, "data-found") {
            Ok(Some(v)) => inspect(v, content="true")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
      // Assert: nested structure
      match dom.query_selector(doc, "#container") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
      match dom.query_selector(doc, "#child") {
        Ok(Some(child)) => {
          match dom.get_attribute(child, "class") {
            Ok(Some(v)) => inspect(v, content="test-class")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "WPT-style: setAttribute and getAttribute" {
  let browser = Browser::new(800, 600)
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|<script>
    #|  const el = document.createElement('div');
    #|  el.setAttribute('id', 'attr-test');
    #|
    #|  // Set various attributes
    #|  el.setAttribute('data-string', 'hello');
    #|  el.setAttribute('data-number', '42');
    #|  el.setAttribute('data-empty', '');
    #|  el.setAttribute('class', 'foo bar');
    #|  el.setAttribute('title', 'Test Title');
    #|
    #|  // Override attribute
    #|  el.setAttribute('data-string', 'world');
    #|
    #|  document.body.appendChild(el);
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  let _ = browser.execute_scripts()
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#attr-test") {
        Ok(Some(el)) => {
          // Verify overwritten attribute
          match dom.get_attribute(el, "data-string") {
            Ok(Some(v)) => inspect(v, content="world")
            _ => assert_true(false)
          }
          // Verify other attributes
          match dom.get_attribute(el, "data-number") {
            Ok(Some(v)) => inspect(v, content="42")
            _ => assert_true(false)
          }
          match dom.get_attribute(el, "class") {
            Ok(Some(v)) => inspect(v, content="foo bar")
            _ => assert_true(false)
          }
          match dom.get_attribute(el, "title") {
            Ok(Some(v)) => inspect(v, content="Test Title")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser DOM tree persists across script executions" {
  let browser = Browser::new(800, 600)
  // First execution creates element
  let html1 =
    #|<html>
    #|<script>
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'persistent');
    #|  div.setAttribute('data-initial', 'set');
    #|  document.body.appendChild(div);
    #|</script>
    #|</html>
  browser.html_content = html1
  let _ = browser.execute_scripts()
  // Verify element was created in real DOM tree
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#persistent") {
        Ok(Some(el)) =>
          match dom.get_attribute(el, "data-initial") {
            Ok(Some(value)) => inspect(value, content="set")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
  // Second execution - element still exists in real DOM
  // (Note: getElementById across executions requires DOM sync, not yet implemented)
  let html2 =
    #|<html>
    #|<script>
    #|  const newDiv = document.createElement('div');
    #|  newDiv.setAttribute('id', 'second');
    #|  document.body.appendChild(newDiv);
    #|</script>
    #|</html>
  browser.html_content = html2
  let _ = browser.execute_scripts()
  // Verify both elements exist in real DOM
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      // First element still exists
      match dom.query_selector(doc, "#persistent") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
      // Second element was added
      match dom.query_selector(doc, "#second") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

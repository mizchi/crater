///|
/// Browser JS form submission, navigation, external fetch, and focused text-input regression tests.

///|
extern "js" fn js_install_fetch_mock(
  expected_url : String,
  response_body : String,
) -> Unit =
  #| (expectedUrl, responseBody) => {
  #|   const state = globalThis.__craterTestFetchMock || {
  #|     originalFetch: globalThis.fetch,
  #|     calls: [],
  #|     responses: Object.create(null),
  #|     installed: false,
  #|   };
  #|   globalThis.__craterTestFetchMock = state;
  #|   if (!state.installed) {
  #|     globalThis.fetch = async (url, init = {}) => {
  #|       const method = String(init.method || 'GET').toUpperCase();
  #|       const headers = Object.fromEntries(new Headers(init.headers || {}).entries());
  #|       const body =
  #|         typeof init.body === 'string'
  #|           ? init.body
  #|           : init.body == null
  #|             ? ''
  #|             : String(init.body);
  #|       const stringUrl = String(url);
  #|       state.calls.push({
  #|         url: stringUrl,
  #|         method,
  #|         headers,
  #|         body,
  #|       });
  #|       if (Object.prototype.hasOwnProperty.call(state.responses, stringUrl)) {
  #|         return new Response(state.responses[stringUrl], {
  #|           status: 200,
  #|           headers: { 'content-type': 'text/html' },
  #|         });
  #|       }
  #|       return state.originalFetch(url, init);
  #|     };
  #|     state.installed = true;
  #|   }
  #|   state.responses[String(expectedUrl)] = responseBody;
  #| }

///|
extern "js" fn js_take_last_fetch_mock_call_for_url(
  expected_url : String,
) -> String =
  #| (expectedUrl) => {
  #|   const state = globalThis.__craterTestFetchMock;
  #|   if (!state || !state.calls || state.calls.length === 0) {
  #|     return "null";
  #|   }
  #|   for (let i = state.calls.length - 1; i >= 0; i--) {
  #|     if (String(state.calls[i].url) === expectedUrl) {
  #|       return JSON.stringify(state.calls[i]);
  #|     }
  #|   }
  #|   return "null";
  #| }

///|
extern "js" fn js_restore_fetch_mock() -> Unit =
  #| () => {
  #|   return undefined;
  #| }

///|
fn extract_fetch_mock_header(
  call_json : String,
  header_name : String,
) -> String? {
  let parsed = @json.parse(call_json) catch { _ => return None }
  match parsed {
    Object(map) =>
      match map.get("headers") {
        Some(Object(headers)) =>
          match headers.get(header_name) {
            Some(String(value)) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
async test "Browser activate_at submits GET form and navigates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at submit preventDefault repaints without navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%3Enavigated%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('form').addEventListener('submit', function (event) {
    #|      event.preventDefault();
    #|      document.getElementById('status').textContent = 'after';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))

  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at submit listener sees SubmitEvent.submitter" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%3Enavigated%3C/p%3E" method="get">
    #|    <button id="btn" name="go" value="Go" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    globalThis.__submitterSeen = 'none';
    #|    document.getElementById('form').addEventListener('submit', function (event) {
    #|      event.preventDefault();
    #|      globalThis.__submitterSeen = event.submitter ? event.submitter.id : 'null';
    #|      document.getElementById('status').textContent = globalThis.__submitterSeen;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")

  let submitter_seen = browser.execute_inline_js("globalThis.__submitterSeen")
  debug_inspect(submitter_seen, content="Some(\"btn\")")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("btn"))
}

///|
async test "Browser activate_at submitter formaction overrides form action" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22wrong%22%3Ewrong%3C/p%3E" method="get">
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formaction="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E?go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("right"))
  assert_true(!rendered.contains("wrong"))
}

///|
async test "Browser activate_at submitter formmethod post navigates with form body" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(
        req.content_type,
        content="application/x-www-form-urlencoded;charset=UTF-8",
      )
      inspect(req.body, content="token=1&go=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at submitter formenctype text/plain serializes post body" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <textarea name="note">hello world</textarea>
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formenctype="text/plain"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\nnote=hello world\r\ngo=Go")
    }
    None => panic()
  }
}

///|
async test "Browser activate_at submitter formenctype multipart serializes post body" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <textarea name="note">hello world</textarea>
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formenctype="multipart/form-data"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(
        req.content_type,
        content="multipart/form-data; boundary=----CraterFormBoundary",
      )
      assert_true(req.body.contains("--" + "----CraterFormBoundary" + "\r\n"))
      assert_true(
        req.body.contains(
          "Content-Disposition: form-data; name=\"token\"\r\n\r\n1\r\n",
        ),
      )
      assert_true(
        req.body.contains(
          "Content-Disposition: form-data; name=\"note\"\r\n\r\nhello world\r\n",
        ),
      )
      assert_true(
        req.body.contains(
          "Content-Disposition: form-data; name=\"go\"\r\n\r\nGo\r\n",
        ),
      )
      assert_true(req.body.contains("--" + "----CraterFormBoundary" + "--\r\n"))
    }
    None => panic()
  }
}

///|
async test "Browser activate_at submitter formtarget _blank avoids current navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button
    #|      id="btn"
    #|      type="submit"
    #|      formtarget="_blank"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|    <p id="status">before</p>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("before"))
  assert_true(!rendered.contains("done"))
}

///|
async test "Browser activate_at submitter formtarget _top navigates current page" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formtarget="_top"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at invalid required form stays on page" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" name="name" required />
    #|    <button
    #|      id="btn"
    #|      type="submit"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|    <p id="status">before</p>
    #|    <script>
    #|      document.getElementById('field').addEventListener('invalid', () => {
    #|        document.getElementById('status').textContent = 'invalid';
    #|      });
    #|    </script>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("invalid"))
  assert_true(!rendered.contains("done"))
}

///|
async test "Browser activate_at submitter formnovalidate bypasses required validation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" name="name" required />
    #|    <button
    #|      id="btn"
    #|      type="submit"
    #|      formnovalidate
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?name=",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at image submit appends coordinate pairs" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <input
    #|      id="img"
    #|      type="image"
    #|      name="pic"
    #|      value="ignored"
    #|      style="display:block;width:96px;height:32px"
    #|    />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "img")
  let client_x = region.col * 8 + 4
  let client_y = region.row * 16 + 8

  let activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1&pic.x=" +
      client_x.to_string() +
      "&pic.y=" +
      client_y.to_string(),
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser execute_inline_js form.submit bypasses submit listener and navigates data url" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('form').addEventListener('submit', function () {
    #|      document.getElementById('status').textContent = 'submitted';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  )
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
  assert_true(!rendered.contains("submitted"))
}

///|
test "Browser execute_inline_js form.requestSubmit uses submitter overrides for data url" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22wrong%22%3Ewrong%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formaction="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  )
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E?token=1&go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("right"))
  assert_true(!rendered.contains("wrong"))
}

///|
test "Browser execute_inline_js form.requestSubmit preserves post body metadata" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  )
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser execute_inline_js keeps unsupported sync submit navigation pending" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://example.com/after" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let result = browser.execute_inline_js(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  )
  debug_inspect(result, content="Some(\"ok\")")
  inspect(browser.get_current_url(), content="")
  debug_inspect(
    browser.execute_inline_js(
      "String((globalThis.__craterPendingFormSubmissions || []).length)",
    ),
    content="Some(\"1\")",
  )
}

///|
test "Browser execute_inline_js requestSubmit queues one submitter-aware external request" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/submit" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  )
  debug_inspect(result, content="Some(\"ok\")")
  inspect(browser.get_current_url(), content="")
  debug_inspect(
    browser.execute_inline_js(
      "String((globalThis.__craterPendingFormSubmissions || []).length)",
    ),
    content="Some(\"1\")",
  )
  let pending = browser.execute_inline_js(
    "(function(){ const queue = globalThis.__craterPendingFormSubmissions || []; return queue.length > 0 ? String(queue[0]) : ''; })()",
  )
  match pending {
    Some(request) => {
      assert_true(request.contains("\"url\":\"https://api.test/submit\""))
      assert_true(request.contains("\"http_method\":\"POST\""))
      assert_true(request.contains("token=1"))
      assert_true(request.contains("go=Go"))
    }
    None => panic()
  }
}

///|
async test "Browser execute_inline_js_async form.submit bypasses submit listener and navigates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('form').addEventListener('submit', function () {
    #|      document.getElementById('status').textContent = 'submitted';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  ) catch {
    _ => None
  }
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
  assert_true(!rendered.contains("submitted"))
}

///|
async test "Browser execute_inline_js_async form.requestSubmit uses submitter overrides" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22wrong%22%3Ewrong%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formaction="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  match
    browser.execute_inline_js(
      "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); return globalThis.__craterBuildFormNavigationRequest(form, button, 0, 0); })()",
    ) {
    Some(request) => assert_true(request.contains("go=Go"))
    None => panic()
  }
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    _ => None
  }
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E?token=1&go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("right"))
  assert_true(!rendered.contains("wrong"))
}

///|
async test "Browser execute_inline_js_async form.requestSubmit preserves post body metadata" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    _ => None
  }
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser execute_inline_js_async requestSubmit posts body to external fetch" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/request-submit-text", "<html><body><p id=\"posted\">posted</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/request-submit-text" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.current_url = "https://example.test/form"
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="https://api.test/request-submit-text",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.url, content="https://api.test/request-submit-text")
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/request-submit-text",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) => {
      match map.get("url") {
        Some(String(url)) =>
          inspect(url, content="https://api.test/request-submit-text")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("method") {
        Some(String(http_method)) => inspect(http_method, content="POST")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("body") {
        Some(String(body)) => inspect(body, content="token=1\r\ngo=Go")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      debug_inspect(
        extract_fetch_mock_header(call_json, "content-type"),
        content="Some(\"text/plain;charset=UTF-8\")",
      )
      debug_inspect(
        extract_fetch_mock_header(call_json, "origin"),
        content="Some(\"https://example.test\")",
      )
    }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("posted"))
  js_restore_fetch_mock()
}

///|
async test "Browser load_url_request preserves external post body with CRLF" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/direct-post-text", "<html><body><p id=\"posted\">posted</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  browser.current_url = "https://example.test/form"
  let _ = browser.load_url_request({
    url: "https://api.test/direct-post-text",
    http_method: "POST",
    content_type: "text/plain;charset=UTF-8",
    body: "token=1\r\ngo=Go",
  }) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/direct-post-text",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) =>
      match map.get("body") {
        Some(String(body)) => inspect(body, content="token=1\r\ngo=Go")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  js_restore_fetch_mock()
}

///|
async test "Browser execute_inline_js_async requestSubmit posts multipart body to external fetch" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/request-submit-multipart", "<html><body><p id=\"uploaded\">uploaded</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/request-submit-multipart" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <textarea name="note">hello world</textarea>
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formenctype="multipart/form-data"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.current_url = "https://example.test/form"
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="https://api.test/request-submit-multipart",
  )
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/request-submit-multipart",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) => {
      match map.get("url") {
        Some(String(url)) =>
          inspect(url, content="https://api.test/request-submit-multipart")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("method") {
        Some(String(http_method)) => inspect(http_method, content="POST")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("body") {
        Some(String(body)) => {
          assert_true(body.contains("--" + "----CraterFormBoundary" + "\r\n"))
          assert_true(
            body.contains(
              "Content-Disposition: form-data; name=\"token\"\r\n\r\n1\r\n",
            ),
          )
          assert_true(
            body.contains(
              "Content-Disposition: form-data; name=\"note\"\r\n\r\nhello world\r\n",
            ),
          )
          assert_true(
            body.contains(
              "Content-Disposition: form-data; name=\"go\"\r\n\r\nGo\r\n",
            ),
          )
          assert_true(body.contains("--" + "----CraterFormBoundary" + "--\r\n"))
        }
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      debug_inspect(
        extract_fetch_mock_header(call_json, "content-type"),
        content="Some(\"multipart/form-data; boundary=----CraterFormBoundary\")",
      )
      debug_inspect(
        extract_fetch_mock_header(call_json, "origin"),
        content="Some(\"https://example.test\")",
      )
    }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("uploaded"))
  js_restore_fetch_mock()
}

///|
async test "Browser execute_inline_js_async form.submit omits submitter field in external post body" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/form-submit-post", "<html><body><p id=\"posted\">posted</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/form-submit-post" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button id="btn" name="go" value="Go" type="submit">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.current_url = "https://example.test/form"
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  ) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  debug_inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="https://api.test/form-submit-post",
  )
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/form-submit-post",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) => {
      match map.get("url") {
        Some(String(url)) =>
          inspect(url, content="https://api.test/form-submit-post")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("method") {
        Some(String(http_method)) => inspect(http_method, content="POST")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("body") {
        Some(String(body)) => {
          inspect(body, content="token=1")
          assert_true(!body.contains("go=Go"))
        }
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      debug_inspect(
        extract_fetch_mock_header(call_json, "content-type"),
        content="Some(\"application/x-www-form-urlencoded;charset=UTF-8\")",
      )
      debug_inspect(
        extract_fetch_mock_header(call_json, "origin"),
        content="Some(\"https://example.test\")",
      )
    }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("posted"))
  js_restore_fetch_mock()
}

///|
async test "Browser execute_scripts_async drains script-triggered form submission navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <script>
    #|    document.getElementById('form').submit();
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let executed = browser.execute_scripts_async() catch { _ => 0 }
  inspect(executed, content="1")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser execute_scripts drains script-triggered data-url form submission navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <script>
    #|    document.getElementById('form').submit();
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser tick_js drains queued data-url form submission navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  browser.init_js_execution()
  let _ = @js.enqueue_script(
    browser.scheduler,
    "document.getElementById('form').submit();",
    true,
  )

  inspect(browser.tick_js(), content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser tick_js drains queued post form submission metadata" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  browser.init_js_execution()
  let _ = @js.enqueue_script(
    browser.scheduler,
    "const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button);",
    true,
  )

  inspect(browser.tick_js(), content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_focused_link submits focused button form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  browser.next_link()

  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_focused_link image submit appends centered coordinates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input
    #|      id="img"
    #|      type="image"
    #|      name="pic"
    #|      style="display:block;width:96px;height:32px"
    #|    />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  browser.focus_source_id("img")
  let (client_x, client_y) = match
    browser.get_client_coords_for_source_id("img") {
    Some(coords) => coords
    None => panic()
  }

  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?pic.x=" +
      client_x.to_string() +
      "&pic.y=" +
      client_y.to_string(),
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_focused_link submits focused text input form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" type="text" value="hello" style="display:block;width:120px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  browser.next_link()

  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser handle_focused_key dispatches input event for focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent = event.target.value;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("x"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser handle_focused_key dispatches beforeinput for focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    const field = document.getElementById('field');
    #|    field.addEventListener('beforeinput', function (event) {
    #|      document.getElementById('status').textContent = String(event.inputType || '') + ':' + String(event.data || '');
    #|      event.preventDefault();
    #|    });
    #|    field.addEventListener('input', function () {
    #|      const status = document.getElementById('status');
    #|      status.textContent = status.textContent + '|input';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('field').value; })()",
    ),
    content="Some(\"\")",
  )
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"insertText:x\")",
  )
}

///|
async test "Browser handle_focused_key inserts text at caret in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="ab" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=1; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"axb|2|2\")",
  )
}

///|
async test "Browser handle_focused_key deletes text before caret in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abc" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=2; field.selectionEnd=2; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("Backspace") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"ac|1|1\")",
  )
}

///|
async test "Browser handle_focused_key replaces selected text in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=3; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"axd|2|2\")",
  )
}

///|
async test "Browser handle_focused_key deletes text after caret in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abc" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=1; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("Delete") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"ac|1|1\")",
  )
}

///|
async test "Browser handle_focused_key moves caret with Home and End" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=2; field.selectionEnd=2; return 'ok'; })()",
  )

  let moved_home = browser.handle_focused_key("Home") catch { _ => false }
  inspect(moved_home, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"0|0\")",
  )
  let moved_end = browser.handle_focused_key("End") catch { _ => false }
  inspect(moved_end, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"4|4\")",
  )
}

///|
async test "Browser handle_focused_key replaces all text after select()" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.select(); return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"x|1|1\")",
  )
}

///|
async test "Browser execute_inline_js setRangeText updates focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()

  let result = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const status=document.getElementById('status'); field.setRangeText('xy',1,3,'select'); status.textContent = field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); return status.textContent; })()",
  )
  debug_inspect(result, content="Some(\"axyd|1|3\")")
  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axyd|1|3"))
}

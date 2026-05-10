///|
/// Browser JS shadow DOM rendering, link, and accessibility regression tests.

///|
async test "Browser sync_render_state_from_dom_tree renders shadow root composed content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host"><span>light</span></div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<p>shadow-text</p>';
    #|  return host.shadowRoot.firstChild.textContent;
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"shadow-text\")")

  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-text"))
  assert_false(rendered.contains("light"))
}

///|
async test "Browser sync_render_state_from_dom_tree keeps serializable shadow snapshot separate from render html" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host"><span id="light">light</span></div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.dom_snapshot_html = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({
    #|    mode: 'closed',
    #|    delegatesFocus: true,
    #|    clonable: true,
    #|    serializable: true
    #|  });
    #|  shadow.innerHTML = '<button id="shadow-btn">shadow-action</button>';
    #|  return host.shadowRoot === null ? 'closed' : 'open';
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"closed\")")

  let _ = browser.sync_render_state_from_dom_tree()
  assert_true(browser.html_content.contains("shadow-action"))
  assert_false(browser.html_content.contains("shadowrootmode"))
  assert_false(browser.html_content.contains("id=\"light\""))
  assert_true(
    browser.dom_snapshot_html.contains(
      "<template shadowrootmode=\"closed\" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable><button id=\"shadow-btn\">shadow-action</button></template><span id=\"light\">light</span>",
    ),
  )
}

///|
test "Browser render_output normalizes declarative shadow DOM from initial HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="closed" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable>
    #|      <p id="shadow-text">shadow-text</p>
    #|    </template>
    #|    <span id="light-text">light-text</span>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-text"))
  assert_false(rendered.contains("light-text"))
  assert_true(browser.html_content.contains("shadow-text"))
  assert_false(browser.html_content.contains("light-text"))
  assert_false(browser.html_content.contains("shadowrootmode"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootmode=\"closed\""))
  assert_true(browser.dom_snapshot_html.contains("shadowrootdelegatesfocus"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootclonable"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootserializable"))
  assert_true(browser.dom_snapshot_html.contains("id=\"shadow-text\""))
  assert_true(browser.dom_snapshot_html.contains("id=\"light-text\""))
}

///|
test "Browser set_html_content eagerly normalizes declarative shadow DOM source" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="closed" shadowrootserializable>
    #|      <p id="shadow-text">shadow-text</p>
    #|    </template>
    #|    <span id="light-text">light-text</span>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  assert_true(browser.html_content.contains("shadow-text"))
  assert_false(browser.html_content.contains("light-text"))
  assert_false(browser.html_content.contains("shadowrootmode"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootmode=\"closed\""))
  assert_true(browser.dom_snapshot_html.contains("id=\"light-text\""))
  inspect(browser.parsed_doc is Some(_), content="true")
}

///|
test "Browser caches prepared render document for repeated graphics renders" {
  let browser = Browser::new(160, 120, terminal_cols=20)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; background: #fff; }
    #|    .card { width: 80px; height: 40px; background: #1463ff; }
    #|  </style>
    #|</head>
    #|<body><div class="card">cached</div></body>
    #|</html>
  browser.set_html_content(html)
  inspect(browser.prepared_render_document is None, content="true")
  let first = browser.render_output(Sixel)
  assert_true(first.length() > 0)
  inspect(browser.prepared_render_document is Some(_), content="true")
  let second = browser.render_output(Sixel)
  assert_eq(second, first)
  inspect(browser.prepared_render_document is Some(_), content="true")
  browser.set_html_content("<html><body><p>next</p></body></html>")
  inspect(browser.prepared_render_document is None, content="true")
}

///|
test "Browser caches graphics node and layout for repeated graphics renders" {
  let browser = Browser::new(160, 120, terminal_cols=20)
  let html =
    #|<html>
    #|<head><style>body { margin: 0; } .card { width: 80px; height: 40px; background: #1463ff; }</style></head>
    #|<body><div class="card">cached</div></body>
    #|</html>
  browser.set_html_content(html)
  inspect(browser.graphics_render_node is None, content="true")
  inspect(browser.graphics_layout is None, content="true")
  ignore(browser.render_output(Sixel))
  inspect(browser.graphics_render_node is Some(_), content="true")
  inspect(browser.graphics_layout is Some(_), content="true")
  ignore(browser.render_output(Kitty))
  inspect(browser.graphics_render_node is Some(_), content="true")
  inspect(browser.graphics_layout is Some(_), content="true")
  browser.set_html_content("<html><body><p>next</p></body></html>")
  inspect(browser.graphics_render_node is None, content="true")
  inspect(browser.graphics_layout is None, content="true")
}

///|
test "Browser set_html_content rebuilds link cache from normalized shadow content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a href="/shadow">shadow link</a>
    #|    </template>
    #|    <a href="/light">light link</a>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  inspect(browser.get_link_count(), content="1")
  inspect(browser.get_focused_link_index(), content="0")
  inspect(browser.get_focused_link_url(), content="Some(\"/shadow\")")
}

///|
test "Browser render_output exposes only shadow link regions and hints from initial HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a href="data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E">shadow link</a>
    #|    </template>
    #|    <a href="data:text/html,%3Cp%20id%3D%22after%22%3Elight-done%3C/p%3E">light link</a>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow link"))
  assert_false(rendered.contains("light link"))
  inspect(browser.link_regions.length(), content="1")
  inspect(browser.link_regions[0].text, content="shadow link")
  inspect(
    browser.get_link_at(
      browser.link_regions[0].col,
      browser.link_regions[0].row,
    ),
    content="Some(\"data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E\")",
  )

  browser.enter_hint_mode()
  inspect(browser.is_hint_mode(), content="true")
  inspect(browser.hints.length(), content="1")
  inspect(browser.hints[0].text, content="shadow link")
  inspect(
    browser.process_hint_char(browser.hints[0].label),
    content="Some(\"data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E\")",
  )
  inspect(browser.is_hint_mode(), content="false")
}

///|
test "Browser build_accessibility_tree normalizes declarative shadow DOM from initial HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <button id="shadow-btn">shadow action</button>
    #|    </template>
    #|    <button id="light-btn">light action</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)
  browser.build_accessibility_tree()

  match browser.a11y_tree {
    Some(tree) => {
      match tree.find_by_source_id("shadow-btn") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match tree.find_by_source_id("light-btn") {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
    }
    None => panic()
  }
}

///|
test "Browser init_js_execution preserves declarative shadow DOM from source HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <button id="shadow-btn">shadow action</button>
    #|    </template>
    #|    <button id="light-btn">light action</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)
  browser.set_enable_js(true)
  browser.init_js_execution()

  let host_has_open_shadow = browser.execute_inline_js(
    "(() => { const host = document.getElementById('host'); return host && host.shadowRoot ? 'yes' : 'no'; })()",
  )
  let shadow_visible = browser.execute_inline_js(
    "(() => { const host = document.getElementById('host'); return host && host.shadowRoot && host.shadowRoot.querySelector('#shadow-btn') ? 'yes' : 'no'; })()",
  )
  let light_visible = browser.execute_inline_js(
    "document.querySelector('#light-btn') !== null ? 'yes' : 'no'",
  )

  inspect(host_has_open_shadow, content="Some(\"yes\")")
  inspect(shadow_visible, content="Some(\"yes\")")
  inspect(light_visible, content="Some(\"yes\")")
}

///|
async test "Browser activate_at navigates shadow link from initial HTML" {
  let browser = Browser::new(800, 600)
  let target_url = "data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E"
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a href="data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E" style="display:block;width:120px;height:24px">shadow link</a>
    #|    </template>
    #|    <a href="data:text/html,%3Cp%20id%3D%22after%22%3Elight-done%3C/p%3E">light link</a>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let _ = browser.render_output(Text)
  inspect(browser.link_regions.length(), content="1")
  let region = browser.link_regions[0]
  let activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content=target_url)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-done"))
}

///|
test "Browser shadow link hints resolve duplicate visible link text by source id" {
  let browser = Browser::new(800, 600)
  browser.current_url = "https://example.com/base/page.html"
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <a id="outer-link" href="/outer">shared link</a>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a id="shadow-link" href="/shadow">shared link</a>
    #|    </template>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let _ = browser.render_output(Text)
  inspect(browser.link_regions.length(), content="2")
  let shadow_region = link_region_of_source_id(browser, "shadow-link")
  inspect(
    browser.get_link_at(shadow_region.col, shadow_region.row),
    content="Some(\"/shadow\")",
  )

  browser.enter_hint_mode()
  inspect(browser.hints.length(), content="2")
  let mut shadow_hint_href = ""
  for hint in browser.hints {
    if hint.col == shadow_region.col && hint.row == shadow_region.row {
      shadow_hint_href = hint.href
    }
  }
  inspect(shadow_hint_href, content="https://example.com/shadow")
}

///|
test "Browser render_output in no_color mode preserves duplicate link URLs" {
  let browser = Browser::new(800, 600)
  browser.current_url = "https://example.com/base/page.html"
  browser.set_no_color(true)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <a id="outer-link" href="/outer">shared link</a>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a id="shadow-link" href="/shadow">shared link</a>
    #|    </template>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  inspect(rendered.contains("https://example.com/outer"), content="true")
  inspect(rendered.contains("https://example.com/shadow"), content="true")
}

///|
async test "Browser activate_focused_link keeps shadow href for duplicate visible link text" {
  let browser = Browser::new(800, 600)
  let outer_url = "data:text/html,%3Cp%20id%3D%22after%22%3Eouter-done%3C/p%3E"
  let shadow_url = "data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E"
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <a id="outer-link" href="data:text/html,%3Cp%20id%3D%22after%22%3Eouter-done%3C/p%3E">shared link</a>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a id="shadow-link" href="data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E">shared link</a>
    #|    </template>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()

  inspect(
    browser.get_focused_link_url(),
    content="Some(\"data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E\")",
  )
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content=shadow_url)
  inspect(browser.get_current_url() == outer_url, content="false")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-done"))
}

///|
async test "Browser sync_render_state_from_dom_tree renders distributed slot content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <span id="plain">plain-text</span>
    #|    <em id="named" slot="label">named-text</em>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<section><slot></slot><slot name="label"></slot><span>fallback</span></section>';
    #|  return shadow.textContent.replace(/\s+/g, ' ').trim();
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"fallback\")")

  let _ = browser.sync_render_state_from_dom_tree()
  assert_true(browser.html_content.contains("plain-text"))
  assert_true(browser.html_content.contains("named-text"))
  assert_true(browser.html_content.contains("fallback"))
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("plain-text"))
  assert_true(rendered.contains("named-text"))
}

///|
async test "Browser sync_render_state_from_dom_tree updates slot reassignment" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <span id="item">slot-source</span>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<section><slot name="label"></slot><slot></slot></section>';
    #|  const slots = shadow.querySelectorAll('slot');
    #|  document.getElementById('item').slot = 'label';
    #|  return [
    #|    slots[0].assignedNodes().length,
    #|    slots[1].assignedNodes().length
    #|  ].join('|');
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"1|0\")")

  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("slot-source"))
}

///|
async test "Browser sync_render_state_from_dom_tree builds accessibility tree from shadow root composed content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <button id="light-btn">light</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<button id="shadow-btn">shadow action</button>';
    #|  return shadow.firstChild.id;
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"shadow-btn\")")

  let _ = browser.sync_render_state_from_dom_tree()
  match browser.a11y_tree {
    Some(tree) => {
      match tree.find_by_source_id("shadow-btn") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match tree.find_by_source_id("light-btn") {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
    }
    None => panic()
  }
}

///|
async test "Browser sync_render_state_from_dom_tree builds accessibility tree from distributed slot content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <button id="slotted-btn" slot="cta">slotted action</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<section><slot name="cta"><button id="fallback-btn">fallback action</button></slot></section>';
    #|  return shadow.textContent.replace(/\s+/g, ' ').trim();
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"fallback action\")")

  let _ = browser.sync_render_state_from_dom_tree()
  match browser.a11y_tree {
    Some(tree) => {
      match tree.find_by_source_id("slotted-btn") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match tree.find_by_source_id("fallback-btn") {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
    }
    None => panic()
  }
}

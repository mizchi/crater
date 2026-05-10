///|
/// Browser JS activation, hit-testing, pointer, mouse, and drag regression tests.

///|
async test "Browser activate_focused_link dispatches onclick and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <p id="status">before</p>
    #|  <a href="/next" onclick="document.getElementById('status').textContent='after'; event.preventDefault();">Go</a>
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

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches button onclick and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    button { display: block; width: 96px; height: 32px; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <button id="btn" onclick="document.getElementById('status').textContent='after';">Go</button>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("btn") {
        Some(node) =>
          match node.bounds {
            Some(bounds) =>
              (
                @tui.px_to_col(bounds.x + bounds.width / 2.0),
                @tui.px_to_row(bounds.y + bounds.height / 2.0) + 1,
              )
            None => panic()
          }
        None => panic()
      }
    None => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches generic onclick element and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    div#target { display: block; width: 120px; height: 40px; background: #ddd; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="target" onclick="document.getElementById('status').textContent='after';">Tap</div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("target") {
        Some(node) =>
          match node.bounds {
            Some(bounds) =>
              (
                @tui.px_to_col(bounds.x + bounds.width / 2.0),
                @tui.px_to_row(bounds.y + bounds.height / 2.0) + 1,
              )
            None => panic()
          }
        None => panic()
      }
    None => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at flushes requestAnimationFrame mutation and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    button { display: block; width: 96px; height: 32px; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <button id="btn" onclick="requestAnimationFrame(() => { document.getElementById('status').textContent='after'; });">Go</button>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("btn") {
        Some(node) =>
          match node.bounds {
            Some(bounds) =>
              (
                @tui.px_to_col(bounds.x + bounds.width / 2.0),
                @tui.px_to_row(bounds.y + bounds.height / 2.0) + 1,
              )
            None => panic()
          }
        None => panic()
      }
    None => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("before"))
  inspect(browser.tick_js(), content="true")
  let after_tick = browser.render_output(Text)
  assert_true(after_tick.contains("after"))
  assert_true(!after_tick.contains("before"))
}

///|
async test "Browser activate_at prefers topmost overlapping painted element" {
  let browser = Browser::new(800, 600)
  browser.set_no_color(true)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 80px; background: #ccc; }
    #|    #top { position: absolute; left: 20px; top: 10px; width: 160px; height: 80px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <p id="status" style="margin-top: 100px">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => first_shared_hit_cell(top, bottom)
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("top"))
  assert_true(!rendered.contains("bottom"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at ignores clipped overflow area" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    #clip { position: relative; width: 80px; height: 32px; overflow: hidden; background: #ddd; }
    #|    #target { position: absolute; left: 48px; top: 0; width: 96px; height: 32px; background: #999; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="clip">
    #|    <div id="target" onclick="document.getElementById('status').textContent='after';"></div>
    #|  </div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  let mut target_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "target" {
      target_region = Some(region)
    }
  }
  let region = match target_region {
    Some(region) => region
    None => panic()
  }
  let hidden_col = region.col + region.width + 1
  let hidden_row = region.row

  let hidden_activated = browser.activate_at(hidden_col, hidden_row) catch {
    _ => false
  }
  inspect(hidden_activated, content="false")

  let after_hidden = browser.render_output(Text)
  assert_true(after_hidden.contains("before"))
  assert_true(!after_hidden.contains("after"))

  let visible_activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(visible_activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at prefers underlying element outside clipped overlap" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 32px; background: #ccc; }
    #|    #clip { position: absolute; left: 0; top: 0; width: 80px; height: 32px; overflow: hidden; }
    #|    #top { position: absolute; left: 48px; top: 0; width: 96px; height: 32px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="clip">
    #|    <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  </div>
    #|  <div style="height: 48px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => {
      let hidden_left = top.col + top.width
      let hidden_right = bottom.col + bottom.width
      assert_true(hidden_right > hidden_left)
      (hidden_left, bottom.row.max(top.row))
    }
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  inspect(activated, content="true")

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at skips pointer_events_none overlay" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; pointer-events: none; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(browser.get_source_id_at(1, 1), content="Some(\"bottom\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at respects inherited pointer_events_none" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #wrapper { pointer-events: none; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #child { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="wrapper">
    #|    <div id="child" onclick="document.getElementById('status').textContent='child';"></div>
    #|  </div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(browser.get_source_id_at(1, 1), content="Some(\"bottom\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at allows child pointer_events_auto under inherited none" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #wrapper { pointer-events: none; position: absolute; left: 0; top: 0; }
    #|    #child { pointer-events: auto; position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="wrapper">
    #|    <div id="child" onclick="document.getElementById('status').textContent='child';"></div>
    #|  </div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(browser.get_source_id_at(1, 1), content="Some(\"child\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"child\")")
}

///|
async test "Browser activate_at prefers transformed topmost element at visual position" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; z-index: 1; transform: translate(48px, 0); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => first_shared_hit_cell(top, bottom)
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at uses scaled transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 32px; background: #999; z-index: 1; transform: scaleX(2); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 10
  let row = bottom.row + 1
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at uses quarter-turn rotate visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 64px; top: 0; width: 32px; height: 64px; background: #999; z-index: 1; transform: rotate(90deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 6
  let row = bottom.row + 1
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at uses arbitrary-angle rotate visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: rotate(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let col = 3
  let row = 2
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes arbitrary-angle rotate bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: rotate(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 2
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses skew transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: skewX(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 2
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes skew transform bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: skewX(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses matrix transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix(1, 0, -1, 1, 64, 0); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 18
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes matrix transform bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix(1, 0, -1, 1, 64, 0); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 8
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses matrix3d transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 18
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes matrix3d transform bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 8
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses cell center for sub-cell hit testing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 1px; height: 48px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
  }
  let (col, row) = match top_region {
    Some(region) => (region.col, region.row)
    None => panic()
  }

  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses sub-pixel coverage for anti-aliased hit testing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 6px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
  }
  let (col, row) = match top_region {
    Some(region) => (region.col, region.row)
    None => panic()
  }

  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at samples non-rect clip-path cell coverage" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: polygon(0 0, 4px 0, 4px 64px, 0 64px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let top = hit_region_of_source_id(browser, "top")
  let outside_col = top.col + 1
  inspect(
    browser.get_source_id_at(outside_col, top.row),
    content="Some(\"bottom\")",
  )
  let outside_activated = browser.activate_at(outside_col, top.row) catch {
    _ => false
  }
  inspect(outside_activated, content="true")
  let outside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(outside_status, content="Some(\"bottom\")")

  inspect(browser.get_source_id_at(top.col, top.row), content="Some(\"top\")")
  let edge_activated = browser.activate_at(top.col, top.row) catch {
    _ => false
  }
  inspect(edge_activated, content="true")
  let edge_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(edge_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects border-radius hit shape" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; border-radius: 24px; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let top = hit_region_of_source_id(browser, "top")
  inspect(
    browser.get_source_id_at(top.col, top.row),
    content="Some(\"bottom\")",
  )
  let corner_activated = browser.activate_at(top.col, top.row) catch {
    _ => false
  }
  inspect(corner_activated, content="true")
  let corner_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(corner_status, content="Some(\"bottom\")")

  let inside_col = top.col + 4
  inspect(
    browser.get_source_id_at(inside_col, top.row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, top.row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path inset hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #999; clip-path: inset(16px 0 0 16px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 3
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path rect hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #999; clip-path: rect(16px 128px 64px 16px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 3
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path xywh hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #999; clip-path: xywh(16px 16px 112px 48px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 3
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path circle hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: circle(24px at 32px 32px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 2
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path ellipse hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: ellipse(24px 16px at 32px 32px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 2
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path polygon hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: polygon(32px 0, 64px 64px, 0 64px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 32 0 L 64 64 L 0 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects quadratic clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 0 64 Q 32 0 64 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let outside_col = bottom.col + 4
  let outside_row = bottom.row
  inspect(
    browser.get_source_id_at(outside_col, outside_row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects smooth clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 0 64 Q 16 0 32 64 T 64 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let outside_col = bottom.col + 4
  let outside_row = bottom.row
  inspect(
    browser.get_source_id_at(outside_col, outside_row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 2
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects arc clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 0 64 A 32 32 0 0 1 64 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let outside_col = bottom.col + 4
  let outside_row = bottom.row
  inspect(
    browser.get_source_id_at(outside_col, outside_row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at dispatches persisted addEventListener click handler" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="btn">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('btn').addEventListener('click', function () {
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

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches persisted generic addEventListener click handler" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="target" style="width:160px;height:48px;background:#999">Go</div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('target').addEventListener('click', function () {
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

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
test "Browser reinit restores clipboard addEventListener handlers" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <div id="target">Clipboard target</div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const target = document.getElementById('target');
    #|    target.addEventListener('copy', function (event) {
    #|      const data = event.clipboardData ? event.clipboardData.getData('text/plain') : 'none';
    #|      if (event.clipboardData) event.clipboardData.setData('text/plain', 'copied');
    #|      document.getElementById('status').textContent += 'copy:' + data + '|';
    #|    });
    #|    target.addEventListener('cut', function (event) {
    #|      const data = event.clipboardData ? event.clipboardData.getData('text/plain') : 'none';
    #|      document.getElementById('status').textContent += 'cut:' + data + '|';
    #|    });
    #|    target.addEventListener('paste', function (event) {
    #|      const data = event.clipboardData ? event.clipboardData.getData('text/plain') : 'none';
    #|      document.getElementById('status').textContent += 'paste:' + data;
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
  browser.dom_tree = None
  browser.script_executor = None

  let dispatch_clipboard_events =
    #|(function () {
    #|  const target = document.getElementById('target');
    #|  const status = document.getElementById('status');
    #|  status.textContent = '';
    #|  const clipboardData = new DataTransfer();
    #|  clipboardData.setData('text/plain', 'seed');
    #|  for (const type of ['copy', 'cut', 'paste']) {
    #|    target.dispatchEvent(new ClipboardEvent(type, {
    #|      bubbles: true,
    #|      cancelable: true,
    #|      clipboardData
    #|    }));
    #|  }
    #|  return status.textContent + ':' + clipboardData.getData('text/plain');
    #|})()
  let status = browser.execute_inline_js(dispatch_clipboard_events)
  inspect(status, content="Some(\"copy:seed|cut:copied|paste:copied:copied\")")
}

///|
async test "Browser activate_at dispatches pointer and mouse events before click" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <button id="btn" style="position:absolute;left:80px;top:48px;display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const btn = document.getElementById('btn');
    #|    const status = document.getElementById('status');
    #|    const order = [];
    #|    for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) {
    #|      btn.addEventListener(type, function (event) {
    #|        order.push(type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = order.join('|');
    #|      });
    #|    }
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
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("btn") {
        Some(node) =>
          match node.bounds {
            Some(bounds) =>
              (
                @tui.px_to_col(bounds.x + bounds.width / 2.0),
                @tui.px_to_row(bounds.y + bounds.height / 2.0) + 1,
              )
            None => panic()
          }
        None => panic()
      }
    None => panic()
  }
  let expected = "@" +
    (col * 8 + 4).to_string() +
    "," +
    (row * 16 + 8).to_string()
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(
    status,
    content="Some(\"pointerdown" +
      expected +
      "|mousedown" +
      expected +
      "|pointerup" +
      expected +
      "|mouseup" +
      expected +
      "|click" +
      expected +
      "\")",
  )
  let rendered = browser.render_output(Text)
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser hover_at dispatches pointer and mouse hover sequence" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="left" style="position:absolute;left:16px;top:16px;width:64px;height:32px;background:#ccc"></div>
    #|  <div id="right" style="position:absolute;left:112px;top:16px;width:64px;height:32px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    function bind(id) {
    #|      const el = document.getElementById(id);
    #|      for (const type of ['pointerover', 'mouseover', 'pointerenter', 'mouseenter', 'pointermove', 'mousemove', 'pointerout', 'mouseout', 'pointerleave', 'mouseleave']) {
    #|        el.addEventListener(type, function (event) {
    #|          events.push(id + ':' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'));
    #|          status.textContent = events.join('|');
    #|        });
    #|      }
    #|    }
    #|    bind('left');
    #|    bind('right');
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
  let mut left_region : @tui.HitRegion? = None
  let mut right_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "left" {
      left_region = Some(region)
    }
    if region.source_id == "right" {
      right_region = Some(region)
    }
  }
  let (left_col, left_row, right_col, right_row) = match
    (left_region, right_region) {
    (Some(left), Some(right)) =>
      (
        left.col + left.width / 2,
        left.row + left.height / 2,
        right.col + right.width / 2,
        right.row + right.height / 2,
      )
    _ => panic()
  }
  inspect(browser.hover_at(left_col, left_row), content="true")
  inspect(browser.hover_at(right_col, right_row), content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"left:pointerover:none|left:mouseover:none|left:pointerenter:none|left:mouseenter:none|left:pointermove:none|left:mousemove:none|left:pointerout:right|left:mouseout:right|left:pointerleave:right|left:mouseleave:right|right:pointerover:left|right:mouseover:left|right:pointerenter:left|right:mouseenter:left|right:pointermove:left|right:mousemove:left\")",
  )
}

///|
async test "Browser pointer drag dispatches drag sequence between source and target" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    for (const type of ['dragstart', 'drag', 'dragend']) {
    #|      document.getElementById('source').addEventListener(type, function (event) {
    #|        events.push('source:' + type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function (event) {
    #|        if (type === 'dragover') {
    #|          event.preventDefault();
    #|          event.dataTransfer.dropEffect = 'move';
    #|        }
    #|        events.push('target:' + type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  let target_point = "@" +
    (target_col * 8 + 4).to_string() +
    "," +
    (target_row * 16 + 8).to_string()
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart" +
      target_point +
      "|source:drag" +
      target_point +
      "|target:dragenter" +
      target_point +
      "|target:dragover" +
      target_point +
      "|target:drop" +
      target_point +
      "|source:dragend" +
      target_point +
      "\")",
  )
}

///|
async test "Browser pointer drag preserves dataTransfer and switches drag targets" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="mid" style="position:absolute;left:120px;top:16px;width:72px;height:40px;background:#bbb"></div>
    #|  <div id="target" style="position:absolute;left:224px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.setData('text/plain', 'payload');
    #|      event.dataTransfer.effectAllowed = 'copyMove';
    #|      events.push('source:dragstart:' + event.dataTransfer.getData('text/plain'));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function (event) {
    #|      events.push('source:drag:' + event.dataTransfer.getData('text/plain'));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function (event) {
    #|      events.push('source:dragend:' + event.dataTransfer.getData('text/plain'));
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const [id, types] of [['mid', ['dragenter', 'dragover', 'dragleave']], ['target', ['dragenter', 'dragover', 'drop']]]) {
    #|      const el = document.getElementById(id);
    #|      for (const type of types) {
    #|        el.addEventListener(type, function (event) {
    #|          if (id === 'target' && type === 'dragover') {
    #|            event.preventDefault();
    #|            event.dataTransfer.dropEffect = 'move';
    #|          }
    #|          const rel = event.relatedTarget ? event.relatedTarget.id : 'none';
    #|          if (type === 'drop') {
    #|            events.push(id + ':' + type + ':' + rel + ':' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect + ':' + event.dataTransfer.getData('text/plain'));
    #|          } else {
    #|            events.push(id + ':' + type + ':' + rel + ':' + event.dataTransfer.getData('text/plain'));
    #|          }
    #|          status.textContent = events.join('|');
    #|        });
    #|      }
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (mid_col, mid_row) = center_of_hit_source_id(browser, "mid")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(mid_col, mid_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart:payload|source:drag:payload|mid:dragenter:none:payload|mid:dragover:source:payload|source:drag:payload|mid:dragleave:target:payload|target:dragenter:mid:payload|target:dragover:source:payload|target:drop:source:copyMove/move:payload|source:dragend:payload\")",
  )
}

///|
async test "Browser pointer drag shares DataTransfer mutations through drop" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.setData('text/plain', 'payload');
    #|      event.dataTransfer.setData('text/html', '<b>x</b>');
    #|      events.push('source:' + event.dataTransfer.types.join(','));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('target').addEventListener('dragover', function (event) {
    #|      event.preventDefault();
    #|      event.dataTransfer.clearData('text/plain');
    #|      event.dataTransfer.dropEffect = 'copy';
    #|      events.push('target:dragover:' + event.dataTransfer.types.join(','));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('target').addEventListener('drop', function (event) {
    #|      events.push(
    #|        'target:drop:' +
    #|        event.dataTransfer.types.join(',') +
    #|        ':' +
    #|        event.dataTransfer.getData('text/plain') +
    #|        ':' +
    #|        event.dataTransfer.getData('text/html')
    #|      );
    #|      status.textContent = events.join('|');
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:text/plain,text/html|target:dragover:text/html|target:drop:text/html::<b>x</b>\")",
  )
}

///|
async test "Browser pointer drag leaving targets dispatches dragleave without drop" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <div id="outside" style="position:absolute;left:320px;top:16px;width:96px;height:48px;background:#666"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.setData('text/plain', 'payload');
    #|      events.push('source:dragstart');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function () {
    #|      events.push('source:drag');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function () {
    #|      events.push('source:dragend');
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const type of ['dragenter', 'dragover', 'dragleave', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function () {
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  let (outside_col, outside_row) = center_of_hit_source_id(browser, "outside")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  inspect(browser.pointer_move_at(outside_col, outside_row), content="true")
  let released = browser.pointer_up_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:drag|target:dragleave|source:dragend\")",
  )
}

///|
async test "Browser pointer drag does not drop without dragover preventDefault" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    for (const type of ['dragstart', 'drag', 'dragend']) {
    #|      document.getElementById('source').addEventListener(type, function () {
    #|        events.push('source:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function () {
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:dragend\")",
  )
}

///|
async test "Browser pointer drag does not drop when effectAllowed is none" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.effectAllowed = 'none';
    #|      events.push('source:dragstart');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function () {
    #|      events.push('source:drag');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function (event) {
    #|      events.push('source:dragend:' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect);
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function (event) {
    #|        if (type === 'dragover') {
    #|          event.preventDefault();
    #|          event.dataTransfer.dropEffect = 'move';
    #|        }
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:dragend:none/move\")",
  )
}

///|
async test "Browser pointer drag does not drop when dropEffect is incompatible with effectAllowed" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.effectAllowed = 'copy';
    #|      events.push('source:dragstart');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function () {
    #|      events.push('source:drag');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function (event) {
    #|      events.push('source:dragend:' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect);
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function (event) {
    #|        if (type === 'dragover') {
    #|          event.preventDefault();
    #|          event.dataTransfer.dropEffect = 'move';
    #|        }
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:dragend:copy/move\")",
  )
}

///|
async test "Browser activate_at prefers topmost persisted addEventListener element" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 24px; top: 8px; width: 160px; height: 64px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top"></div>
    #|  <p id="status" style="margin-top: 96px">before</p>
    #|  <script>
    #|    document.getElementById('top').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'top';
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
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => first_shared_hit_cell(top, bottom)
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

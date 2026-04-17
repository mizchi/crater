///|
test "fixed article fixture renders heading and navigation in text mode" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("HTML"))
  assert_true(rendered.contains("Web APIs"))
  assert_true(rendered.contains("WebAssembly テキスト形式の理解"))
  assert_true(rendered.contains("セクション 0"))
}

///|
test "fixed article fixture full text output includes below-the-fold sections" {
  let viewport_browser = Browser::new(1440, 240)
  load_fixture(viewport_browser, docs_article_fixture())
  let viewport = viewport_browser.render_output(Text)
  assert_true(viewport.contains("セクション 0"))
  assert_true(!viewport.contains("セクション 9"))

  let full_browser = Browser::new(1440, 240)
  load_fixture(full_browser, docs_article_fixture())
  let full = full_browser.render_text_full_page()
  assert_true(full.contains("セクション 0"))
  assert_true(full.contains("セクション 9"))
  assert_true(full.contains("セクション 13"))
}

///|
test "fixed article fixture exposes links and article role in aom output" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  browser.links = extract_links(browser.html_content)
  browser.build_accessibility_tree()
  let aom = browser.render_output(Aom)
  inspect(browser.get_link_count(), content="22")
  assert_true(
    aom.contains(
      "- heading \"WebAssembly テキスト形式の理解\" [level=1]",
    ),
  )
  assert_true(aom.contains("WebAssembly テキスト形式の理解"))
}

///|
test "builtin github snapshot fixture loads and renders non-empty text output" {
  let browser = Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  assert_true(html.contains("GitHub"))
  assert_true(!html.contains("<script"))
  load_fixture(browser, html)
  let rendered = browser.render_output(Text)
  assert_true(rendered.length() > 0)
}

///|
test "builtin github snapshot fixture renders kitty graphics output" {
  let browser = Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  load_fixture(browser, html)
  let rendered = browser.render_output(Kitty)
  assert_true(rendered.has_prefix("\u001b_Ga=T,f=24,q=2,s="))
  assert_true(rendered.length() > 64)
}

///|
test "fixed article fixture renders kitty graphics output" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  let rendered = browser.render_output(Kitty)
  assert_true(rendered.has_prefix("\u001b_Ga=T,f=24,q=2,s="))
  assert_true(rendered.length() > 64)
}

///|
async test "dashboard fixture reflects DOM mutation and click repaint" {
  let browser = Browser::new(1280, 800)
  load_fixture(browser, @benchmarks.dashboard(15, 12))
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(!initial.contains("Refresh"))
  assert_true(!initial.contains("ready"))

  let insert_code =
    #|(
    #|  function() {
    #|    const root = document.body && document.body.firstElementChild;
    #|    const main = root && root.children ? root.children[1] : null;
    #|    const grid = main && main.lastElementChild ? main.lastElementChild : null;
    #|    if (!grid) {
    #|      return "missing-grid";
    #|    }
    #|    const card = grid.firstElementChild || document.createElement("div");
    #|    card.id = "dash-card";
    #|    if (!card.parentNode) {
    #|      card.style.background = "#fff";
    #|      card.style.borderRadius = "8px";
    #|      card.style.padding = "16px";
    #|      grid.appendChild(card);
    #|    }
    #|    card.textContent = "";
    #|    const button = document.createElement("button");
    #|    button.id = "dash-action";
    #|    button.textContent = "Refresh";
    #|    button.style.display = "block";
    #|    button.style.width = "120px";
    #|    button.style.height = "32px";
    #|    const status = document.createElement("p");
    #|    status.id = "dash-status";
    #|    status.textContent = "ready";
    #|    button.addEventListener("click", function() {
    #|      status.textContent = "clicked";
    #|    });
    #|    card.appendChild(button);
    #|    card.appendChild(status);
    #|    return status.textContent;
    #|  }
    #|)()
  let inserted = browser.execute_inline_js(insert_code)
  inspect(inserted, content="Some(\"ready\")")
  let _ = browser.sync_render_state_from_dom_tree()

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("Refresh"))
  assert_true(rendered.contains("ready"))
  let persisted = browser.execute_inline_js(
    "(function(){ const button=document.getElementById('dash-action'); return button ? String(!!button.getAttribute('data-crater-listeners-click')) : 'missing'; })()",
  )
  inspect(persisted, content="Some(\"true\")")

  let (button_col, button_row) = center_of_source_id(browser, "dash-action")
  let clicked = browser.activate_at(button_col, button_row) catch { _ => false }
  inspect(clicked, content="true")

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('dash-status').textContent; })()",
  )
  inspect(status, content="Some(\"clicked\")")
  inspect(browser.html_content.contains("clicked"), content="true")
  let after_click = browser.render_text_full_page()
  assert_true(after_click.contains("clicked"))
}

///|
async test "builtin github snapshot fixture applies DOM mutation and click repaint" {
  let browser = Browser::new(1440, 960)
  let runtime =
    #|<section id="gh-runtime-box" style="position:fixed;top:16px;left:16px;z-index:2147483647;background:#ffffff;color:#111111;padding:12px;border:1px solid #d0d7de">
    #|  <button id="gh-runtime-toggle" style="display:block;width:120px;height:36px">Refresh</button>
    #|  <p id="gh-runtime-status">before</p>
    #|</section>
    #|<script>
    #|  document.getElementById('gh-runtime-toggle').addEventListener('click', function () {
    #|    document.getElementById('gh-runtime-status').textContent = 'clicked';
    #|  });
    #|</script>
  let html = inject_after_marker(builtin_github_snapshot_fixture(), "</body>", runtime)
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_text_full_page()
  assert_true(initial.contains("GitHub"))
  assert_true(initial.contains("before"))

  let _ = @js.enqueue_script(
    browser.scheduler,
    "const status=document.getElementById('gh-runtime-status'); if (status) status.textContent='timer';",
    true,
  )
  inspect(browser.tick_js(), content="true")
  let after_timer = browser.render_text_full_page()
  assert_true(after_timer.contains("timer"))

  let (col, row) = center_of_source_id(browser, "gh-runtime-toggle")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let after_click = browser.render_text_full_page()
  assert_true(after_click.contains("clicked"))
}

///|
let tiny_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2NgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg=="

///|
let tiny_jpeg_base64 = "/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A/n/ooooA/9k="

///|
let tiny_gif_base64 = "R0lGODdhAQABAJEAAAAAAP///wAAAAAAACH5BAkAAAIALAAAAAABAAEAAAICRAEAOw=="

///|
fn tiny_image_region(
  src : String,
  row? : Int = 0,
  source_id? : String = "img-1",
) -> @tui.ImageRegion {
  {
    col: 0,
    row,
    width: 1,
    height: 1,
    pixel_width: 1.0,
    pixel_height: 1.0,
    src,
    source_id,
  }
}

///|
fn extract_single_chunk_kitty_payload(output : String) -> String {
  let marker = ",m=0;"
  match output.find(marker) {
    Some(idx) => {
      let start = idx + marker.length()
      let tail = output.unsafe_substring(start~, end=output.length())
      match tail.find("\u001b\\") {
        Some(end_idx) => tail.unsafe_substring(start=0, end=end_idx)
        None => tail
      }
    }
    None => ""
  }
}

///|
fn extract_kitty_param(output : String, key : String) -> String {
  let marker = key + "="
  match output.find(marker) {
    Some(idx) => {
      let start = idx + marker.length()
      let tail = output.unsafe_substring(start~, end=output.length())
      let end_idx = match tail.find(",") {
        Some(i) => i
        None =>
          match tail.find(";") {
            Some(i) => i
            None => tail.length()
          }
      }
      tail.unsafe_substring(start=0, end=end_idx)
    }
    None => ""
  }
}

///|
test "kitty image overlay keeps png payload as direct image data" {
  let browser = Browser::new(320, 240)
  browser.image_cache["/tiny.png"] = prepare_raster_image_for_kitty_cache(
    tiny_png_base64,
  )
  browser.image_regions = [tiny_image_region("/tiny.png", source_id="tiny-png")]
  let overlay = browser.build_kitty_image_overlay()
  assert_true(overlay.contains("\u001b[1;1H"))
  assert_true(overlay.contains("\u001b_Ga=T,f=100,q=2,c=1,r=1,"))
  assert_true(overlay.contains(",p="))
  assert_true(overlay.contains(",m=0;"))
  assert_eq(extract_single_chunk_kitty_payload(overlay), tiny_png_base64)
}

///|
test "kitty image overlay uses rgba pixel path for jpeg payload" {
  let browser = Browser::new(320, 240)
  browser.image_cache["/tiny.jpg"] = prepare_raster_image_for_kitty_cache(
    tiny_jpeg_base64,
  )
  browser.image_regions = [
    tiny_image_region("/tiny.jpg", source_id="tiny-jpeg"),
  ]
  let overlay = browser.build_kitty_image_overlay()
  let cached = browser.image_cache["/tiny.jpg"]
  let payload = extract_single_chunk_kitty_payload(overlay)
  assert_true(overlay.contains(",p="))
  if cached.has_prefix("img_rgba:") {
    assert_true(overlay.contains("\u001b_Ga=T,f=32,q=2,c=1,r=1,"))
    assert_true(overlay.contains(",s=1,v=1,m=0;"))
    assert_eq(payload.length(), 8)
    assert_true(!payload.has_prefix("/9j/"))
    assert_true(!payload.has_prefix("iVBORw0KGgo"))
  } else {
    assert_true(overlay.contains("\u001b_Ga=T,f=100,q=2,c=1,r=1,"))
    assert_true(overlay.contains(",m=0;"))
    if cached.has_prefix("img_png:") {
      assert_true(payload.has_prefix("iVBORw0KGgo"))
      assert_true(!payload.has_prefix("/9j/"))
    } else {
      assert_true(cached.has_prefix("img:"))
      assert_eq(payload, tiny_jpeg_base64)
    }
  }
}

///|
test "kitty image overlay uses rgba pixel path for gif payload" {
  let browser = Browser::new(320, 240)
  browser.image_cache["/tiny.gif"] = prepare_raster_image_for_kitty_cache(
    tiny_gif_base64,
  )
  browser.image_regions = [tiny_image_region("/tiny.gif", source_id="tiny-gif")]
  let overlay = browser.build_kitty_image_overlay()
  let cached = browser.image_cache["/tiny.gif"]
  let payload = extract_single_chunk_kitty_payload(overlay)
  assert_true(overlay.contains(",p="))
  if cached.has_prefix("img_rgba:") {
    assert_true(overlay.contains("\u001b_Ga=T,f=32,q=2,c=1,r=1,"))
    assert_true(overlay.contains(",s=1,v=1,m=0;"))
    assert_eq(payload.length(), 8)
    assert_true(!payload.has_prefix("R0lG"))
    assert_true(!payload.has_prefix("iVBORw0KGgo"))
  } else {
    assert_true(overlay.contains("\u001b_Ga=T,f=100,q=2,c=1,r=1,"))
    assert_true(overlay.contains(",m=0;"))
    if cached.has_prefix("img_png:") {
      assert_true(payload.has_prefix("iVBORw0KGgo"))
      assert_true(!payload.has_prefix("R0lG"))
    } else {
      assert_true(cached.has_prefix("img:"))
      assert_eq(payload, tiny_gif_base64)
    }
  }
}

///|
test "kitty image overlay reuses placement when image scrolls and deletes when hidden" {
  let browser = Browser::new(320, 240)
  browser.image_cache["/tiny.png"] = prepare_raster_image_for_kitty_cache(
    tiny_png_base64,
  )
  browser.image_regions = [
    tiny_image_region("/tiny.png", row=0, source_id="hero"),
  ]
  let first = browser.build_kitty_image_overlay()
  let image_id = extract_kitty_param(first, "i")
  let placement_id = extract_kitty_param(first, "p")
  assert_true(first.contains(tiny_png_base64))
  browser.image_regions = [
    tiny_image_region("/tiny.png", row=2, source_id="hero"),
  ]
  let second = browser.build_kitty_image_overlay()
  assert_true(second.contains("\u001b[3;1H"))
  assert_true(
    second.contains(
      "\u001b_Ga=p,q=2,i=" +
      image_id +
      ",p=" +
      placement_id +
      ",c=1,r=1;\u001b\\",
    ),
  )
  assert_true(!second.contains("a=T"))
  assert_true(!second.contains(tiny_png_base64))
  browser.image_regions = []
  let third = browser.build_kitty_image_overlay()
  assert_true(
    third.contains(
      "\u001b_Ga=d,q=2,d=i,i=" + image_id + ",p=" + placement_id + ";\u001b\\",
    ),
  )
}

///|
test "image cache evicts oldest entries when byte budget is exceeded" {
  let browser = Browser::new(320, 240)
  browser.set_image_cache_max_bytes(14)
  browser.cache_image_data("/a.png", "img:123456")
  browser.cache_image_data("/b.png", "img:abcdef")
  inspect(browser.image_cache.contains("/a.png"), content="false")
  inspect(browser.image_cache.contains("/b.png"), content="true")
  inspect(browser.image_cache_total_bytes, content="10")
}

///|
test "image cache refreshes insertion order when replacing the same src" {
  let browser = Browser::new(320, 240)
  browser.set_image_cache_max_bytes(22)
  browser.cache_image_data("/a.png", "img:111111")
  browser.cache_image_data("/b.png", "img:222222")
  browser.cache_image_data("/a.png", "img:333333")
  browser.cache_image_data("/c.png", "img:444444")
  inspect(browser.image_cache.contains("/a.png"), content="true")
  inspect(browser.image_cache.contains("/b.png"), content="false")
  inspect(browser.image_cache.contains("/c.png"), content="true")
  inspect(browser.image_cache_order.join(","), content="/a.png,/c.png")
}

///|
async test "builtin github snapshot fixture can stream kitty output to writer" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, builtin_github_snapshot_fixture())
  let expected = browser.render_output(Kitty)
  let (reader, writer) = @pipe.pipe()
  defer reader.close()
  browser.write_output(Kitty, writer)
  writer.close()
  let streamed = reader.read_all().text()
  assert_eq(streamed, expected)
}

///|
fn inject_after_marker(
  html : String,
  marker : String,
  extra : String,
) -> String {
  match html.find(marker) {
    Some(idx) => {
      let end_idx = idx + marker.length()
      html.unsafe_substring(start=0, end=end_idx) +
      extra +
      html.unsafe_substring(start=end_idx, end=html.length())
    }
    None => html + extra
  }
}

///|
fn center_of_source_id(browser : Browser, source_id : String) -> (Int, Int) {
  for region in browser.hit_regions {
    if region.source_id == source_id {
      return (region.col + region.width / 2, region.row + region.height / 2)
    }
  }
  browser.build_accessibility_tree()
  match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id(source_id) {
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
}

///|
fn center_of_hit_source_id(browser : Browser, source_id : String) -> (Int, Int) {
  for region in browser.hit_regions {
    if region.source_id == source_id {
      return (region.col + region.width / 2, region.row + region.height / 2)
    }
  }
  panic()
}

///|
async test "fixture form submit navigates on focused button activation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
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
async test "fixture submit preventDefault repaints without navigation" {
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
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  browser.next_link()
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "fixture focused text input Enter submits form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "fixture focused text input beforeinput can prevent typing repaint" {
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
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("insertText:x"))
  assert_true(!rendered.contains("|input"))
}

///|
async test "fixture focused text input inserts text at caret" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="ab" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=1; return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axb|2|2"))
}

///|
async test "fixture focused text input deletes text before caret" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abc" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=2; field.selectionEnd=2; return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("Backspace") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("ac|1|1"))
}

///|
async test "fixture focused text input replaces selected text" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=3; return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axd|2|2"))
}

///|
async test "fixture focused text input deletes text after caret" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abc" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=1; return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("Delete") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("ac|1|1"))
}

///|
async test "fixture focused text input moves caret with Home and End" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    function render() {
    #|      const field = document.getElementById('field');
    #|      document.getElementById('status').textContent =
    #|        String(field.selectionStart) + '|' + String(field.selectionEnd);
    #|    }
    #|    document.getElementById('field').addEventListener('keydown', render);
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=2; field.selectionEnd=2; return 'ok'; })()",
  )
  let moved_home = browser.handle_focused_key("Home") catch { _ => false }
  inspect(moved_home, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"0|0\")",
  )
  let moved_end = browser.handle_focused_key("End") catch { _ => false }
  inspect(moved_end, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"4|4\")",
  )
}

///|
async test "fixture focused text input select() replaces all text" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.select(); return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("x|1|1"))
}

///|
async test "fixture execute_inline_js setRangeText updates render" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let result = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const status=document.getElementById('status'); field.setRangeText('xy',1,3,'select'); status.textContent = field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); return status.textContent; })()",
  )
  inspect(result, content="Some(\"axyd|1|3\")")
  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axyd|1|3"))
}

///|
async test "fixture activate_at moves caret in focused text input before typing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "field")

  let activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(activated, content="true")
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("xabcd|1|1"))
}

///|
async test "fixture pointer drag selects text in focused input before typing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "field")

  inspect(browser.pointer_down_at(region.col + 1, region.row), content="true")
  inspect(browser.pointer_move_at(region.col + 3, region.row), content="true")
  let _ = browser.pointer_up_at(region.col + 3, region.row) catch { _ => false }
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axd|2|2"))
}

///|
async test "fixture activate_at moves caret in focused textarea before typing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <textarea id="field" style="display:block;width:160px;height:64px">ab
    #|cd</textarea>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        JSON.stringify(event.target.value) + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "field")

  let activated = browser.activate_at(region.col + 1, region.row + 1) catch {
    _ => false
  }
  inspect(activated, content="true")
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("\"ab\\ncxd\"|5|5"))
}

///|
async test "fixture focused textarea Enter inserts newline without submit" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <textarea id="field" style="display:block;width:160px;height:64px"></textarea>
    #|    <p id="status">before</p>
    #|  </form>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent = JSON.stringify(event.target.value);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("\"\\n\""))
  assert_true(!rendered.contains("done"))
}

///|
async test "fixture focused textarea replaces selected text" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <textarea id="field" style="display:block;width:160px;height:64px">abcd</textarea>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=3; return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axd|2|2"))
}

///|
async test "fixture focused textarea deletes text after caret" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <textarea id="field" style="display:block;width:160px;height:64px">abc</textarea>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent =
    #|        event.target.value + '|' + String(event.target.selectionStart) + '|' + String(event.target.selectionEnd);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=1; return 'ok'; })()",
  )
  let handled = browser.handle_focused_key("Delete") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("ac|1|1"))
}

///|
async test "fixture focused checkbox Space toggles and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="check" type="checkbox" style="display:block;width:24px;height:24px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('check').addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = event.target.checked ? 'checked' : 'unchecked';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("checked"))
}

///|
test "fixture inline-flex label keeps trailing text after clipped absolute input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;font:16px/1.2 sans-serif">
    #|  <label id="root" style="display:inline-flex;align-items:center;gap:8px">
    #|    <input
    #|      id="check"
    #|      type="checkbox"
    #|      style="position:absolute;clip:rect(1px,1px,1px,1px);width:1px;height:1px;overflow:hidden"
    #|    />
    #|    <span id="control" style="display:inline-flex;width:20px;height:20px;background:#999"></span>
    #|    <span id="label">Accept terms</span>
    #|  </label>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("Accept terms"))
}

///|
async test "fixture Tab blur/focus dispatches change blur and focus repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function (event) {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'change:' + event.target.value : current + '|change:' + event.target.value;
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'blur' : current + '|blur';
    #|    });
    #|    document.getElementById('field').addEventListener('focusout', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focusout' : current + '|focusout';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focus' : current + '|focus';
    #|    });
    #|    document.getElementById('btn').addEventListener('focusin', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focusin' : current + '|focusin';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let persisted = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const btn=document.getElementById('btn'); return [String(!!(field&&field.getAttribute('data-crater-listeners-blur'))), String(!!(field&&field.getAttribute('data-crater-listeners-focusout'))), String(!!(btn&&btn.getAttribute('data-crater-listeners-focus'))), String(!!(btn&&btn.getAttribute('data-crater-listeners-focusin')))].join('|'); })()",
  )
  inspect(persisted, content="Some(\"true|true|true|true\")")
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.next_link()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("change:x|blur|focusout|focus|focusin"))
}

///|
async test "fixture Tab blur/focus does not dispatch change for untouched text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="seed" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'change' : current + '|change';
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'blur' : current + '|blur';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focus' : current + '|focus';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("blur|focus"))
  assert_true(!rendered.contains("change"))
}

///|
async test "fixture click blur/focus dispatches change blur and focus repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function (event) {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'change:' + event.target.value : current + '|change:' + event.target.value;
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'blur' : current + '|blur';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focus' : current + '|focus';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
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
  assert_true(rendered.contains("change:x|blur|focus"))
}

///|
async test "fixture focused radio Space updates exclusive selection" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="a" name="group" type="radio" checked style="display:block;width:24px;height:24px" />
    #|  <input id="b" name="group" type="radio" style="display:block;width:24px;height:24px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('b').addEventListener('change', function () {
    #|      document.getElementById('status').textContent = String(document.getElementById('a').checked) + '|' + String(document.getElementById('b').checked);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("false|true"))
}

///|
async test "fixture reset button restores initial control values" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form>
    #|    <input id="field" type="text" value="seed" style="display:block;width:120px;height:32px" />
    #|    <input id="check" type="checkbox" checked style="display:block;width:24px;height:24px" />
    #|    <button id="reset" type="reset" style="display:block;width:96px;height:32px">Reset</button>
    #|    <p id="status">before</p>
    #|  </form>
    #|  <script>
    #|    function render() {
    #|      const field = document.getElementById('field');
    #|      const check = document.getElementById('check');
    #|      document.getElementById('status').textContent = field.value + '|' + String(check.checked);
    #|    }
    #|    document.getElementById('field').addEventListener('input', render);
    #|    document.getElementById('check').addEventListener('change', render);
    #|    document.querySelector('form').addEventListener('reset', function () {
    #|      setTimeout(render, 0);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.next_link()
  let _ = browser.handle_focused_key(" ") catch { _ => false }
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("reset") {
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
  for i = 0; i < 4; i = i + 1 {
    let _ = browser.tick_js()
  }
  let state = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const check=document.getElementById('check'); return field.value + '|' + String(check.checked); })()",
  )
  inspect(state, content="Some(\"seed|true\")")
}

///|
async test "fixture focused select ArrowDown changes selection and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <select id="sel" style="display:block;width:120px;height:32px">
    #|    <option value="a">A</option>
    #|    <option value="b">B</option>
    #|  </select>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('sel').addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = event.target.value;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key("ArrowDown") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("b"))
  assert_true(!rendered.contains("before"))
}

///|
async test "fixture focused reset input Space restores initial values" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form>
    #|    <input id="field" type="text" value="seed" style="display:block;width:120px;height:32px" />
    #|    <input id="reset" type="reset" value="Reset" style="display:block;width:96px;height:32px" />
    #|    <p id="status">before</p>
    #|  </form>
    #|  <script>
    #|    function render() {
    #|      document.getElementById('status').textContent = document.getElementById('field').value;
    #|    }
    #|    document.getElementById('field').addEventListener('input', render);
    #|    document.querySelector('form').addEventListener('reset', function () {
    #|      setTimeout(render, 0);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  for _ in 0..<4 {
    let _ = browser.tick_js()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("seed"))
}

///|
async test "fixture focused submit input Space submits form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%3Esubmitted-input%3C/p%3E" method="get">
    #|    <input id="submit" type="submit" value="Go" style="display:block;width:96px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  assert_true(browser.html_content.contains("submitted-input"))
}

///|
async test "fixture focused input button Space dispatches click repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="btn" type="button" value="Go" style="display:block;width:96px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('btn').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'after';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
}

///|
async test "fixture click dispatches pointer and mouse sequence before click repaint" {
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
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (col, row) = center_of_source_id(browser, "btn")
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
async test "fixture hover dispatches pointer and mouse hover sequence" {
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
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let (left_col, left_row) = center_of_hit_source_id(browser, "left")
  let (right_col, right_row) = center_of_hit_source_id(browser, "right")
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
async test "fixture hover repaint reflects pointermove coordinates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="hover" style="position:absolute;left:40px;top:24px;width:96px;height:48px;background:#ccc"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const hover = document.getElementById('hover');
    #|    const status = document.getElementById('status');
    #|    hover.addEventListener('pointermove', function (event) {
    #|      status.textContent = 'pointer:' + event.clientX + ',' + event.clientY;
    #|    });
    #|    hover.addEventListener('mousemove', function (event) {
    #|      status.textContent += '|mouse:' + event.clientX + ',' + event.clientY;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  let (col, row) = center_of_hit_source_id(browser, "hover")
  inspect(browser.hover_at(col, row), content="true")
  let point = (col * 8 + 4).to_string() + "," + (row * 16 + 8).to_string()
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"pointer:" + point + "|mouse:" + point + "\")",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("pointer:" + point + "|mouse:" + point))
  assert_true(!rendered.contains("before"))
}

///|
async test "fixture pointer drag dispatches drag sequence between source and target" {
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
    #|        if (type === 'dragover') event.preventDefault();
    #|        events.push('target:' + type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
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
async test "fixture pointer drag preserves dataTransfer and switches drag targets" {
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
  load_fixture(browser, html)
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
async test "fixture pointer drag shares DataTransfer mutations through drop" {
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
  load_fixture(browser, html)
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
async test "fixture pointer drag leaving targets dispatches dragleave without drop" {
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
  load_fixture(browser, html)
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
async test "fixture pointer drag does not drop without dragover preventDefault" {
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
  load_fixture(browser, html)
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
async test "fixture pointer drag does not drop when effectAllowed is none" {
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
  load_fixture(browser, html)
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
async test "fixture pointer drag does not drop when dropEffect is incompatible with effectAllowed" {
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
  load_fixture(browser, html)
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
async test "docs article fixture applies timer mutation and click repaint" {
  let browser = Browser::new(1440, 960)
  let runtime =
    #|<section style="padding:24px 0">
    #|  <button id="demo-toggle" style="display:block;width:120px;height:36px">更新</button>
    #|  <p id="runtime-status">before</p>
    #|</section>
    #|<script>
    #|  document.getElementById('demo-toggle').addEventListener('click', function () {
    #|    document.getElementById('runtime-status').textContent = 'clicked';
    #|  });
    #|</script>
  let html = inject_after_marker(docs_article_fixture(), "</h1>", runtime)
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("WebAssembly テキスト形式の理解"))
  let initial_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('runtime-status').textContent; })()",
  )
  inspect(initial_status, content="Some(\"before\")")

  let _ = @js.enqueue_script(
    browser.scheduler,
    "const heading=document.querySelector('h1'); const status=document.getElementById('runtime-status'); if (heading) heading.textContent='WebAssembly テキスト形式の理解 (updated)'; if (status) status.textContent='timer';",
    true,
  )
  inspect(browser.tick_js(), content="true")
  let after_timer = browser.render_output(Text)
  assert_true(
    after_timer.contains("WebAssembly テキスト形式の理解 (updated)"),
  )
  assert_true(after_timer.contains("timer"))

  let (col, row) = center_of_source_id(browser, "demo-toggle")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let after_click = browser.render_output(Text)
  assert_true(after_click.contains("clicked"))
  assert_true(
    after_click.contains("WebAssembly テキスト形式の理解 (updated)"),
  )
}

///|
async test "fixture select blur does not duplicate change repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <select id="sel" style="display:block;width:120px;height:32px">
    #|    <option value="a">A</option>
    #|    <option value="b">B</option>
    #|  </select>
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('sel').addEventListener('change', function (event) {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      const next = 'change:' + event.target.value;
    #|      status.textContent = current === 'before' ? next : current + '|' + next;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("ArrowDown") catch { _ => false }
  browser.next_link()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("change:b"))
  assert_true(!rendered.contains("change:b|change:b"))
}

///|
async test "fixture focused summary Enter toggles details and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <details id="det">
    #|    <summary id="sum" style="display:block;width:120px;height:32px">More</summary>
    #|    <p>Body</p>
    #|  </details>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let before = browser.render_output(Text)
  assert_true(!before.contains("Body"))
  browser.next_link()
  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("Body"))
}

///|
async test "fixture listener and closure state survive re-execution" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="closure" style="display:block;width:96px;height:32px">Closure</button>
    #|  <p id="closure-status">0</p>
    #|  <button id="dom" style="display:block;width:96px;height:32px">DOM</button>
    #|  <p id="dom-status">0</p>
    #|  <script>
    #|    let closureCount = 0;
    #|    document.getElementById('closure').addEventListener('click', function () {
    #|      closureCount += 1;
    #|      document.getElementById('closure-status').textContent = String(closureCount);
    #|    });
    #|    document.getElementById('dom').addEventListener('click', function () {
    #|      const status = document.getElementById('dom-status');
    #|      const current = Number(status.textContent || '0');
    #|      status.textContent = String(current + 1);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let (closure_col, closure_row) = center_of_source_id(browser, "closure")
  let (dom_col, dom_row) = center_of_source_id(browser, "dom")

  let _ = browser.activate_at(closure_col, closure_row) catch { _ => false }
  let _ = browser.activate_at(closure_col, closure_row) catch { _ => false }
  let _ = browser.activate_at(dom_col, dom_row) catch { _ => false }
  let _ = browser.activate_at(dom_col, dom_row) catch { _ => false }

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('closure-status').textContent + '|' + document.getElementById('dom-status').textContent; })()",
  )
  inspect(status, content="Some(\"2|2\")")
}

///|
async test "fixture dynamic clickable element becomes target after DOM sync" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="spawn" style="display:block;width:96px;height:32px">Spawn</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    let dynamicCount = 0;
    #|    document.getElementById('spawn').addEventListener('click', function () {
    #|      let late = document.getElementById('late');
    #|      if (!late) {
    #|        late = document.createElement('button');
    #|        late.id = 'late';
    #|        late.textContent = 'Late';
    #|        late.style.display = 'block';
    #|        late.style.width = '96px';
    #|        late.style.height = '32px';
    #|        late.addEventListener('click', function () {
    #|          dynamicCount += 1;
    #|          document.getElementById('status').textContent = 'late:' + String(dynamicCount);
    #|        });
    #|        document.body.appendChild(late);
    #|      }
    #|      document.getElementById('status').textContent = 'spawned';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))

  let (spawn_col, spawn_row) = center_of_source_id(browser, "spawn")
  let spawned = browser.activate_at(spawn_col, spawn_row) catch { _ => false }
  inspect(spawned, content="true")

  let after_spawn = browser.render_output(Text)
  assert_true(after_spawn.contains("spawned"))
  assert_true(after_spawn.contains("Late"))

  let (late_col, late_row) = center_of_source_id(browser, "late")
  let _ = browser.activate_at(late_col, late_row) catch { _ => false }
  let _ = browser.activate_at(late_col, late_row) catch { _ => false }

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"late:2\")")
}

///|
async test "fixture removed clickable element disappears from hit test after DOM sync" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="remove" style="display:block;width:96px;height:32px">Remove</button>
    #|  <button id="late" style="display:block;width:96px;height:32px">Late</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    let lateCount = 0;
    #|    document.getElementById('late').addEventListener('click', function () {
    #|      lateCount += 1;
    #|      document.getElementById('status').textContent = 'late:' + String(lateCount);
    #|    });
    #|    document.getElementById('remove').addEventListener('click', function () {
    #|      const late = document.getElementById('late');
    #|      if (late) {
    #|        late.remove();
    #|      }
    #|      document.getElementById('status').textContent = 'removed';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let (remove_col, remove_row) = center_of_source_id(browser, "remove")
  let (late_col, late_row) = center_of_source_id(browser, "late")

  let _ = browser.activate_at(late_col, late_row) catch { _ => false }
  let before_remove = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(before_remove, content="Some(\"late:1\")")

  let removed = browser.activate_at(remove_col, remove_row) catch { _ => false }
  inspect(removed, content="true")
  let after_remove = browser.render_output(Text)
  assert_true(after_remove.contains("removed"))
  assert_true(!after_remove.contains("Late"))
  browser.build_accessibility_tree()
  match browser.a11y_tree {
    Some(tree) => assert_true(tree.find_by_source_id("late") is None)
    None => panic()
  }
  let mut has_late_hit_region = false
  for region in browser.hit_regions {
    if region.source_id == "late" {
      has_late_hit_region = true
    }
  }
  assert_true(!has_late_hit_region)

  let stale_hit = browser.activate_at(late_col, late_row) catch { _ => false }
  let _ = stale_hit
  let final_status = browser.execute_inline_js(
    "(function(){ return (document.getElementById('late') ? 'present' : 'missing') + '|' + document.getElementById('status').textContent; })()",
  )
  inspect(final_status, content="Some(\"missing|removed\")")
}

///|
async test "fixture replaced focused element keeps focus on replacement with same source id" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="swap" style="display:block;width:96px;height:32px">Before</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    let replaceCount = 0;
    #|    function bindSwap() {
    #|      const button = document.getElementById('swap');
    #|      if (!button) return;
    #|      button.addEventListener('click', function () {
    #|        replaceCount += 1;
    #|        if (replaceCount === 1) {
    #|          const next = document.createElement('button');
    #|          next.id = 'swap';
    #|          next.textContent = 'After';
    #|          next.style.display = 'block';
    #|          next.style.width = '96px';
    #|          next.style.height = '32px';
    #|          button.replaceWith(next);
    #|          bindSwap();
    #|          document.getElementById('status').textContent = 'replaced';
    #|          return;
    #|        }
    #|        document.getElementById('status').textContent = 'after:' + String(replaceCount - 1);
    #|      });
    #|    }
    #|    bindSwap();
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  inspect(browser.get_focused_source_id(), content="Some(\"swap\")")

  let first = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(first, content="true")
  let after_replace = browser.render_output(Text)
  assert_true(after_replace.contains("After"))
  assert_true(after_replace.contains("replaced"))
  inspect(browser.get_focused_source_id(), content="Some(\"swap\")")

  let second = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(second, content="true")
  let final_render = browser.render_output(Text)
  assert_true(final_render.contains("after:1"))
}

///|
async test "fixture removed focused element falls forward to next focusable on next tab" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="gone" style="display:block;width:96px;height:32px">Gone</button>
    #|  <button id="next" style="display:block;width:96px;height:32px">Next</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('gone').addEventListener('click', function () {
    #|      const target = document.getElementById('gone');
    #|      if (target) target.remove();
    #|      document.getElementById('status').textContent = 'removed';
    #|    });
    #|    document.getElementById('next').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'next';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  browser.next_link()
  inspect(browser.get_focused_source_id(), content="Some(\"gone\")")

  let removed = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(removed, content="true")
  let after_remove = browser.render_output(Text)
  assert_true(after_remove.contains("removed"))
  assert_true(!after_remove.contains("Gone"))

  browser.next_link()
  inspect(browser.get_focused_source_id(), content="Some(\"next\")")

  let activated = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(activated, content="true")
  let final_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(final_status, content="Some(\"next\")")
}

///|
async test "fixture removed focused element falls backward to previous focusable on shift-tab" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="prev" style="display:block;width:96px;height:32px">Prev</button>
    #|  <button id="gone" style="display:block;width:96px;height:32px">Gone</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('prev').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'prev';
    #|    });
    #|    document.getElementById('gone').addEventListener('click', function () {
    #|      const target = document.getElementById('gone');
    #|      if (target) target.remove();
    #|      document.getElementById('status').textContent = 'removed';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  browser.next_link()
  browser.next_link()
  inspect(browser.get_focused_source_id(), content="Some(\"gone\")")

  let removed = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(removed, content="true")
  let after_remove = browser.render_output(Text)
  assert_true(after_remove.contains("removed"))
  assert_true(!after_remove.contains("Gone"))

  browser.prev_link()
  inspect(browser.get_focused_source_id(), content="Some(\"prev\")")

  let activated = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(activated, content="true")
  let final_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(final_status, content="Some(\"prev\")")
}

///|
async test "fixture mouse click falls through after focused element removal" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="gone" style="display:block;width:96px;height:32px">Gone</button>
    #|  <button id="next" style="display:block;width:96px;height:32px">Next</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('gone').addEventListener('click', function () {
    #|      const target = document.getElementById('gone');
    #|      if (target) target.remove();
    #|      document.getElementById('status').textContent = 'removed';
    #|    });
    #|    document.getElementById('next').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'next';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  browser.next_link()
  inspect(browser.get_focused_source_id(), content="Some(\"gone\")")
  let (gone_col, gone_row) = center_of_source_id(browser, "gone")
  let removed = browser.activate_at(gone_col, gone_row) catch { _ => false }
  inspect(removed, content="true")

  let after_remove = browser.render_output(Text)
  assert_true(after_remove.contains("removed"))
  assert_true(!after_remove.contains("Gone"))

  let (next_col, next_row) = center_of_source_id(browser, "next")
  let clicked = browser.activate_at(next_col, next_row) catch { _ => false }
  inspect(clicked, content="true")
  inspect(browser.get_focused_source_id(), content="Some(\"next\")")
  let final_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(final_status, content="Some(\"next\")")
}

///|
async test "fixture requestAnimationFrame advances across browser ticks" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="start" style="display:block;width:96px;height:32px">Start</button>
    #|  <p id="status">0</p>
    #|  <script>
    #|    let count = 0;
    #|    function step() {
    #|      count += 1;
    #|      document.getElementById('status').textContent = String(count);
    #|      if (count < 2) {
    #|        requestAnimationFrame(step);
    #|      }
    #|    }
    #|    document.getElementById('start').addEventListener('click', function () {
    #|      requestAnimationFrame(step);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("0"))

  browser.next_link()
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  let after_activate = browser.render_output(Text)
  assert_true(after_activate.contains("0"))

  inspect(browser.tick_js(), content="true")
  let after_first_tick = browser.render_output(Text)
  assert_true(after_first_tick.contains("1"))

  inspect(browser.tick_js(), content="true")
  let after_second_tick = browser.render_output(Text)
  assert_true(after_second_tick.contains("2"))
}

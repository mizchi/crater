///|
/// Browser JS render output, terminal image overlay, and asset discovery regression tests.

///|
test "Browser getter API returns initial state" {
  let browser = Browser::new(800, 600)
  inspect(browser.get_current_url(), content="")
  inspect(browser.get_last_navigation_url(), content="None")
  inspect(browser.get_viewport_height(), content="600")
  inspect(browser.get_link_count(), content="0")
  inspect(browser.get_focused_link_index(), content="0")
  inspect(browser.is_hint_mode(), content="false")
}

///|
test "Browser render_output returns defaults when content is empty" {
  let browser = Browser::new(800, 600)
  inspect(browser.render_output(Text), content="")
  inspect(browser.render_output(Sixel), content="")
  inspect(browser.render_output(Kitty), content="")
  inspect(browser.render_output(Json), content="{}")
  inspect(browser.render_output(Aom), content="")
  inspect(
    browser.render_output(Arc90),
    content="No accessibility tree available.",
  )
  inspect(
    browser.render_output(ExtractMain),
    content="No accessibility tree available.",
  )
  inspect(
    browser.render_output(Grounding),
    content="No accessibility tree available.",
  )
}

///|
test "kitty render overlays cached image data for img src regions" {
  let browser = Browser::new(160, 80, terminal_cols=20)
  let html =
    #|<!doctype html>
    #|<img id="logo" src="logo.png" alt="Logo Alt" width="32" height="32">
  browser.set_html_content(html)
  browser.cache_image_data("logo.png", "img_png:iVBORw0KGgo=")
  let output = browser.render_output(Kitty)
  inspect(browser.image_regions.length(), content="1")
  inspect(output.contains("\u001b_Ga=T,f=100"), content="true")
}

///|
test "extract_img_srcs accepts html attribute whitespace and case variants" {
  let html =
    #|<main>
    #|  <IMG
    #|    alt="Hero"
    #|    SRC = "hero.png">
    #|  <img data-src="lazy.png" srcset="ignored.png 1x" src='icon.svg'>
    #|  <image src="not-img.svg"></image>
    #|</main>
  let srcs = extract_img_srcs(html)
  inspect(srcs.length(), content="2")
  inspect(srcs[0], content="hero.png")
  inspect(srcs[1], content="icon.svg")
}

///|
test "cache_data_image_src stores png data uri for kitty overlay" {
  let browser = Browser::new(160, 80, terminal_cols=20)
  let src = "data:image/png;base64,iVBORw0KGgo="
  inspect(browser.cache_data_image_src(src), content="true")
  match browser.image_cache.get(src) {
    Some(cached) => inspect(cached, content="img_png:iVBORw0KGgo=")
    None => fail("expected data image to be cached")
  }
}

///|
async test "prefetch_images caches data uri image sources" {
  let browser = Browser::new(160, 80, terminal_cols=20)
  let src = "data:image/png;base64,iVBORw0KGgo="
  browser.set_html_content(
    "<img id=\"logo\" src=\"" +
    src +
    "\" alt=\"Logo Alt\" width=\"32\" height=\"32\">",
  )
  browser.prefetch_images()
  match browser.image_cache.get(src) {
    Some(cached) => inspect(cached, content="img_png:iVBORw0KGgo=")
    None => fail("expected data image to be prefetched")
  }
}

///|
test "kitty render overlays data uri image from img src" {
  let browser = Browser::new(160, 80, terminal_cols=20)
  let src = "data:image/png;base64,iVBORw0KGgo="
  browser.set_html_content(
    "<img id=\"logo\" src=\"" +
    src +
    "\" alt=\"Logo Alt\" width=\"32\" height=\"32\">",
  )
  let _ = browser.cache_data_image_src(src)
  let output = browser.render_output(Kitty)
  inspect(browser.image_regions.length(), content="1")
  inspect(output.contains("\u001b_Ga=T,f=100"), content="true")
}

///|
test "sixel render composites cached raster image for img src" {
  let browser = Browser::new(32, 32, terminal_cols=4)
  browser.set_html_content(
    "<img id=\"logo\" src=\"logo.png\" alt=\"Logo Alt\" width=\"16\" height=\"16\">",
  )
  browser.cache_image_data("logo.png", "img_rgba:1:1:/wAA/w==")
  let output = browser.render_output(Sixel)
  inspect(output.has_prefix("\u001bPq"), content="true")
  inspect(output.contains(";2;100;0;0"), content="true")
}

///|
test "sixel render composites cached data png image for img src" {
  let browser = Browser::new(32, 32, terminal_cols=4)
  let src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4AWP4z8DwHwAFAAH/e+m+7wAAAABJRU5ErkJggg=="
  browser.set_html_content(
    "<img id=\"logo\" src=\"" +
    src +
    "\" alt=\"Logo Alt\" width=\"16\" height=\"16\">",
  )
  let _ = browser.cache_data_image_src(src)
  let output = browser.render_output(Sixel)
  inspect(output.has_prefix("\u001bPq"), content="true")
  inspect(output.contains(";2;100;0;0"), content="true")
}

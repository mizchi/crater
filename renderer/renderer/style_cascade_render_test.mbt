///|
test "color_scheme_dark_resolves_light_dark_background" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.panel { color-scheme: dark; background-color: light-dark(#f7f7f8, #212426); }
    #|</style>
    #|<div class="panel">Panel</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let panel = root.children[0]
  inspect(panel.style.background_color.to_hex(), content="#212426")
}

///|
test "color_scheme_dark_inherits_to_light_dark_child_background" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.theme { color-scheme: dark; }
    #|.child { background-color: light-dark(#ffffff, #18191b); }
    #|</style>
    #|<section class="theme"><div class="child">Child</div></section>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let child = root.children[0].children[0]
  inspect(child.style.background_color.to_hex(), content="#18191b")
}

///|
test "css_variable_dark_toggle_inherits_from_root" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|:root {
    #|  --color-gray-10: #212426;
    #|  --color-gray-90: #f7f7f8;
    #|  --csstools-color-scheme--light: initial;
    #|  --toggle: var(--csstools-color-scheme--light) var(--color-gray-10);
    #|  --color-background-primary: var(--toggle, var(--color-gray-90));
    #|}
    #|.homepage--dark {
    #|  --csstools-color-scheme--light: ;
    #|  background-color: var(--color-background-primary);
    #|  color-scheme: dark;
    #|}
    #|</style>
    #|<main class="homepage--dark">Home</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let home = root.children[0]
  inspect(home.style.background_color.to_hex(), content="#212426")
}

///|
test "double_hyphen_class_selector_matches" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.homepage--dark { background-color: #212426; color: #ffffff; }
    #|</style>
    #|<main class="homepage homepage--dark">Home</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let home = root.children[0]
  inspect(home.style.background_color.to_hex(), content="#212426")
  inspect(home.style.color.to_hex(), content="#ffffff")
}

///|
test "mdn_color_scheme_fallback_rules_resolve_dark_background" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html { --csstools-color-scheme--light: initial; color-scheme: light dark; }
    #|:root {
    #|  --csstools-light-dark-toggle-5e0f49fc-1: var(--csstools-color-scheme--light) var(--color-gray-10);
    #|  --color-background-primary: var(--csstools-light-dark-toggle-5e0f49fc-1,var(--color-gray-90));
    #|}
    #|@supports (color:light-dark(red,red)) {
    #|  :root { --color-background-primary: light-dark(var(--color-gray-90),var(--color-gray-10)); }
    #|}
    #|:root {
    #|  --color-gray-90: #f7f7f8;
    #|  --color-gray-10: #212426;
    #|}
    #|.homepage--dark {
    #|  --csstools-color-scheme--light: ;
    #|  background-color: var(--color-background-primary);
    #|  color-scheme: dark;
    #|}
    #|</style>
    #|<main class="homepage homepage--dark">Home</main>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let home = root.children[0]
  inspect(home.style.background_color.to_hex(), content="#212426")
}

///|
test "mdn_a11y_menu_calc_offset_resolves_offscreen" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|.a11y-menu {
    #|  --offset: 20em;
    #|  left: 2px;
    #|  position: absolute;
    #|  top: calc(var(--offset)*-1);
    #|}
    #|</style>
    #|<ul class="a11y-menu"><li><a href="#main">Skip</a></li></ul>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let menu = root.children[0]
  inspect(menu.style.inset.top, content="Length(-320)")
}

///|
test "apple_system_normal_line_height_matches_browser_component_metrics" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body {
    #|  margin: 0;
    #|  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    #|  font-size: 14px;
    #|}
    #|.alert { padding: 12px 16px; }
    #|.title { font-size: 1rem; margin-bottom: 4px; }
    #|.desc { font-size: 0.875rem; }
    #|</style>
    #|<div class="alert"><div class="title">Error</div><div class="desc">Something went wrong.</div></div>
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(node.style.font_family, content="-apple-system")
  inspect(node.style.line_height, content="17")
  let node_alert = node.children[0]
  inspect(node_alert.style.font_family, content="-apple-system")
  inspect(node_alert.style.line_height, content="17")
  inspect(node_alert.children[0].style.line_height, content="18")
  inspect(node_alert.children[1].style.line_height, content="17")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let alert = layout.children[0]
  inspect(alert.height, content="63")
  inspect(alert.children[0].height, content="18")
  inspect(alert.children[1].height, content="17")
}

///|
test "ua_default_h1_uses_larger_heading_metrics" {
  let html_str =
    #|<!doctype html>
    #|<style>html, body { margin: 0; padding: 0; }</style>
    #|<h1>Visibility collapse</h1>
    #|<a href="#">Spec</a>
  let ctx = @renderer.RenderContext::default()
  let layout_root = @renderer.render(html_str, ctx)
  let h1 = layout_root.children[0]
  let link = layout_root.children[1]
  guard h1.height > 30.0 else {
    fail("h1 should use larger UA heading metrics")
  }
  guard link.y > 50.0 else {
    fail("following inline content should be pushed by heading bottom margin")
  }
}

///|
test "ua_block_defaults_apply_margins_on_the_correct_axis" {
  let html_str =
    #|<!doctype html>
    #|<style>html, body { margin: 0; padding: 0; } div { width: 400px; }</style>
    #|<div>
    #|  <p>Paragraph</p>
    #|  <pre>Preformatted</pre>
    #|  <blockquote>Quoted</blockquote>
    #|</div>
  let layout_root = @renderer.render(
    html_str,
    @renderer.RenderContext::default(),
  )
  let wrapper = layout_root.children[0]
  let p = wrapper.children[0]
  let pre = wrapper.children[1]
  let quote = wrapper.children[2]

  inspect(p.x, content="0")
  inspect(pre.x, content="0")
  inspect(quote.x, content="40")
}

///|
fn node_id_matches_tag(node_id : String, tag : String) -> Bool {
  node_id == tag ||
  node_id.has_prefix(tag + "#") ||
  node_id.has_prefix(tag + ".")
}

///|
fn find_node_by_tag_id(node : @node.Node, tag : String) -> @node.Node? {
  if node_id_matches_tag(node.id, tag) {
    return Some(node)
  }
  for child in node.children {
    match find_node_by_tag_id(child, tag) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn find_text_node_by_content(node : @node.Node, text : String) -> @node.Node? {
  match node.text {
    Some(content) if content == text => return Some(node)
    _ => ()
  }
  for child in node.children {
    match find_text_node_by_content(child, text) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn node_text_contains(node : @node.Node, needle : String) -> Bool {
  match node.text {
    Some(content) if content.contains(needle) => return true
    _ => ()
  }
  for child in node.children {
    if node_text_contains(child, needle) {
      return true
    }
  }
  false
}

///|
test "render_to_node skips body style text in inline collection" {
  let html_str =
    #|<!DOCTYPE html>
    #|<div id="wrap"><style>[data-mask]{visibility:hidden!important}</style><span>ok</span></div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(node_text_contains(root, "[data-mask]"), content="false")
  inspect(node_text_contains(root, "ok"), content="true")
}

///|
test "render_to_node does not fallback-match descendant pseudo selector on body substring" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>.markdown-body [data-footnote-ref]::before { content: "["; }</style>
    #|<div>ok</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  inspect(node_text_contains(root, "["), content="false")
  inspect(node_text_contains(root, "ok"), content="true")
}

///|
test "ua_text_decoration_applies_to_semantic_inline_tags" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<body>
    #|  <a href="#">link</a>
    #|  <u>underline</u>
    #|  <s>strike</s>
    #|</body>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  match find_node_by_tag_id(node, "a") {
    Some(a) => inspect(a.style.text_decoration_underline, content="true")
    None => inspect(false, content="a not found")
  }
  match find_text_node_by_content(node, "underline") {
    Some(u_text) =>
      inspect(u_text.style.text_decoration_underline, content="true")
    None => inspect(false, content="u text not found")
  }
  match find_text_node_by_content(node, "strike") {
    Some(s_text) =>
      inspect(s_text.style.text_decoration_line_through, content="true")
    None => inspect(false, content="s text not found")
  }
}

///|
test "text_decoration_none_overrides_ua_underline" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|a { text-decoration: none; }
    #|</style>
    #|<a href="#">no underline</a>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  match find_node_by_tag_id(node, "a") {
    Some(a) => inspect(a.style.text_decoration_underline, content="false")
    None => inspect(false, content="a not found")
  }
}

///|
test "link_color_overridden_by_css" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|a:link { color: #000000; }
    #|</style>
    #|<a href="#">black link</a>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  fn find_a(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("a") {
      return Some(n)
    }
    for child in n.children {
      match find_a(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
  match find_a(node) {
    Some(a) => {
      // CSS a:link { color: #000 } should override UA blue (#0000ee)
      inspect(a.style.color.r, content="0")
      inspect(a.style.color.g, content="0")
      inspect(a.style.color.b, content="0")
    }
    None => inspect(false, content="a not found")
  }
}

///|
test "link default color is blue" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<a href="https://example.com">Link text</a>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  fn find_link_node(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("a") {
      return Some(n)
    }
    for child in n.children {
      match find_link_node(child) {
        Some(a) => return Some(a)
        None => continue
      }
    }
    None
  }

  match find_link_node(node) {
    Some(link) => {
      inspect(link.style.color.r, content="0")
      inspect(link.style.color.g, content="0")
      inspect(link.style.color.b, content="238")
      if link.children.length() > 0 {
        let text = link.children[0]
        inspect(text.id, content="#text")
        inspect(text.style.color.r, content="0")
        inspect(text.style.color.g, content="0")
        inspect(text.style.color.b, content="238")
      }
    }
    None => fail("No link node found!")
  }
}

///|
test "ua_list_defaults_use_block_margin_and_inline_start_padding" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<ol><li></li></ol>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let ol = node.children[0]
  let li = ol.children[0]
  inspect(ol.id, content="ol")
  inspect(ol.style.margin.top, content="Length(16)")
  inspect(ol.style.margin.bottom, content="Length(16)")
  inspect(ol.style.margin.left, content="Length(0)")
  inspect(ol.style.padding.left, content="Length(40)")
  inspect(ol.style.padding.bottom, content="Length(0)")
  inspect(li.id, content="li")
  inspect(li.style.min_height, content="Length(19.2)")
}

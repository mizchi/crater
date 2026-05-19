///|
test "body_explicit_height_is_not_forced_to_viewport" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; height: 200px; }
    #|</style>
    #|<div style="height: 20px;"></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.id, content="body")
  inspect(layout.height, content="200")
}

///|
test "body_overflow_scroll_is_not_forced_to_viewport" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; overflow: scroll; }
    #|</style>
    #|body text
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.id, content="body")
  inspect(layout.height < ctx.viewport_height, content="true")
  inspect(
    layout.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "body_auto_height_follows_content_not_viewport" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="height: 20px;"></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.id, content="body")
  inspect(layout.height, content="20")
}

///|
test "empty_body_root_with_html_viewport_styles_keeps_viewport_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html {
    #|  scrollbar-gutter: stable both-edges;
    #|  background-image: linear-gradient(to right, green, blue);
    #|}
    #|</style>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.height, content="600")
}

///|
test "frameset_root_without_content_keeps_viewport_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<frameset style="overflow:scroll"></frameset>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)

  inspect(layout.height, content="600")
  let frameset = layout.children[0]
  inspect(frameset.id, content="frameset")
  inspect(frameset.height, content="600")
}

///|
test "body_collapsed_top_margin_does_not_expand_body_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { margin-top: 10px; height: 50px; }
    #|</style>
    #|<div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let child = layout.children[0]

  inspect(layout.id, content="body")
  inspect(layout.height, content="50")
  inspect(child.y, content="0")
}

///|
test "body child percent height stays auto when body height is indefinite" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  body { margin: 0; min-height: 100vh; }
    #|  #page {
    #|    display: flex;
    #|    flex-direction: column;
    #|    height: 100%;
    #|    min-height: 100vh;
    #|    overflow: clip;
    #|  }
    #|  #content { height: 1200px; }
    #|</style>
    #|<div id="page"><div id="content"></div></div>
  let ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @renderer.render(html_str, ctx)
  let page = layout.children[0]
  let content = page.children[0]
  inspect(page.id, content="div#page")
  inspect(content.height, content="1200")
  guard page.height > 1100.0 else {
    fail(
      "height:100% child under indefinite body height should use content height",
    )
  }
}

///|
test "body definite height gives google-like column flex viewport basis" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  html, body {
    #|    height: 100%;
    #|    margin: 0;
    #|  }
    #|  #page {
    #|    display: flex;
    #|    flex-direction: column;
    #|    height: 100%;
    #|  }
    #|  #nav, #logo, #search, #footer {
    #|    flex-shrink: 0;
    #|  }
    #|  #nav { height: 60px; }
    #|  #slot {
    #|    min-height: 150px;
    #|    height: calc(100% - 560px);
    #|    max-height: 290px;
    #|    flex-shrink: 0;
    #|  }
    #|  #logo { height: 92px; }
    #|  #search { height: 100px; }
    #|  #grow {
    #|    flex-grow: 1;
    #|    flex-shrink: 0;
    #|  }
    #|  #footer { height: 104px; }
    #|</style>
    #|<div id="page">
    #|  <div id="nav"></div>
    #|  <div id="slot"></div>
    #|  <div id="logo"></div>
    #|  <div id="search"></div>
    #|  <div id="grow"></div>
    #|  <div id="footer"></div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @renderer.render(html_str, ctx)
  let page = layout.children[0]
  let grow = page.children[4]
  let footer = page.children[5]
  inspect(page.id, content="div#page")
  inspect(page.height, content="600")
  inspect(grow.height, content="94")
  inspect(footer.y, content="496")
  inspect(footer.height, content="104")
}

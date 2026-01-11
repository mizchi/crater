///|
test "hamburger_style_rendering" {
  // Simulate the hamburger element style
  let html =
    #|<div style="display: flex; width: 375px; height: 56px; flex-direction: row; justify-content: space-between; align-items: flex-start;">
    #|  <div style="width: 216px; height: 26px;">nav</div>
    #|  <div style="width: 159px; height: 56px;">search</div>
    #|  <div style="width: 20px; height: 20px; padding: 18px 23px 12px; margin: 3px; box-sizing: content-box; position: relative; display: block;">hamburger</div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let flex_container = layout.children[0]

  // Check hamburger size
  // width: 20 + 23 + 23 = 66 (content + padding-left + padding-right)
  // height: 20 + 18 + 12 = 50 (content + padding-top + padding-bottom)
  let hamburger = flex_container.children[2]
  inspect(hamburger.width, content="66")
  inspect(hamburger.height, content="50")
}

///|
test "preact_page_structure" {
  // Simplified structure: wrapper with absolute child followed by normal content
  let html =
    #|<div style="display: flex; flex-direction: column; width: 375px;">
    #|  <div class="wrapper" style="position: relative; width: 100%;">
    #|    <a class="edit" style="position: absolute; right: 0; top: 10px;">Edit this Page</a>
    #|  </div>
    #|  <div class="blogMeta" style="margin-top: 20px;">9/24/2022, written by Joachim</div>
    #|  <h1>Signal Boosting</h1>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  let flex_container = layout.children[0]
  inspect(flex_container.children.length(), content="3")

  // wrapper should have height 0 (only absolute child)
  let wrapper = flex_container.children[0]
  inspect(wrapper.y, content="0")
  inspect(wrapper.height, content="0")

  // edit link inside wrapper
  if wrapper.children.length() > 0 {
    let edit_link = wrapper.children[0]
    inspect(edit_link.x, content="263")
    inspect(edit_link.y, content="10")
    inspect(edit_link.width, content="112")
    inspect(edit_link.height, content="16")
  }

  // blog_meta should be positioned AFTER wrapper (even though wrapper has 0 height)
  let blog_meta = flex_container.children[1]
  inspect(blog_meta.y, content="20")
  inspect(blog_meta.height, content="48")

  // h1
  let h1 = flex_container.children[2]
  inspect(h1.y, content="78.7")
}

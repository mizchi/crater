///|
/// HTML/CSS Renderer CLI
/// Renders HTML with inline styles to Sixel graphics

fn main {
  // Example HTML with inline styles
  let html =
    #|<div style="width: 400px; height: 300px; padding: 10px">
    #|  <header style="height: 40px; margin-bottom: 10px">
    #|    Header
    #|  </header>
    #|  <div style="display: flex">
    #|    <aside style="width: 80px; height: 200px">
    #|      Sidebar
    #|    </aside>
    #|    <main style="flex-grow: 1; height: 200px; padding: 5px">
    #|      <div style="width: 100px; height: 60px">Box 1</div>
    #|      <div style="width: 100px; height: 60px">Box 2</div>
    #|    </main>
    #|  </div>
    #|</div>

  println("=== HTML Input ===")
  println(html)
  println("")

  // Render to layout
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  println("=== Layout Tree ===")
  @renderer.print_layout_tree(layout, 0)
  println("")

  println("=== Sixel Output ===")
  let sixel = @sixel.render_layout(layout, 400, 300)
  println(sixel)
}

///|
/// HTML/CSS Renderer CLI
/// Renders HTML with inline styles to Sixel graphics
///
/// Usage:
///   moon run cmd/main -- <file.html>
///   moon run cmd/main              (use example)

fn main {
  let args = @env.args()

  let html = if args.length() > 1 {
    let arg = args[1]
    if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else {
      // Read from file
      try {
        @fs.read_file_to_string(arg)
      } catch {
        e => {
          println("Error: Cannot read file: " + arg)
          println("  " + e.to_string())
          return
        }
      }
    }
  } else {
    // Default example
    get_example_html()
  }

  // Render
  render_html(html)
}

///|
fn print_usage() -> Unit {
  println("crater - HTML/CSS Layout Renderer")
  println("")
  println("Usage:")
  println("  moon run cmd/main -- <file.html>")
  println("  moon run cmd/main       (example)")
  println("")
  println("Options:")
  println("  -h, --help    Show this help message")
}

///|
fn get_example_html() -> String {
  (
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
  )
}

///|
fn render_html(html : String) -> Unit {
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

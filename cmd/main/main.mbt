///|
/// HTML/CSS Renderer CLI
/// Renders HTML with inline styles to Sixel graphics
///
/// Usage:
///   moon run cmd/main -- <file.html>
///   moon run cmd/main -- --json <file.html>
///   moon run cmd/main              (use example)

///|
fn main {
  let args = @env.args()

  // Parse arguments
  let mut input : String? = None
  let mut json_output = false

  for i = 1; i < args.length(); i = i + 1 {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else if arg == "--json" {
      json_output = true
    } else if input is None {
      input = Some(arg)
    }
  }

  let html = match input {
    Some(path) => {
      // Read from file
      try {
        @fs.read_file_to_string(path)
      } catch {
        e => {
          println("Error: Cannot read file: " + path)
          println("  " + e.to_string())
          return
        }
      }
    }
    None => get_example_html()
  }

  // Render
  if json_output {
    render_json(html)
  } else {
    render_html(html)
  }
}

///|
fn print_usage() -> Unit {
  println("crater - HTML/CSS Layout Renderer")
  println("")
  println("Usage:")
  println("  moon run cmd/main -- <file.html>")
  println("  moon run cmd/main -- --json <file.html>")
  println("  moon run cmd/main       (example)")
  println("")
  println("Options:")
  println("  --json        Output layout as JSON")
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
  // Truncate long HTML for display
  let display_html = if html.length() > 500 {
    let buf = StringBuilder::new()
    for i = 0; i < 500; i = i + 1 {
      buf.write_char(html[i].to_int().unsafe_to_char())
    }
    buf.write_string("\n... (truncated)")
    buf.to_string()
  } else {
    html
  }
  println(display_html)
  println("")

  // Render to layout
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  println("=== Layout Tree ===")
  @renderer.print_layout_tree(layout, 0)
  println("")

  println("=== Sixel Output ===")
  let sixel = @sixel.render_layout(layout, ctx.viewport_width.to_int(), ctx.viewport_height.to_int())
  println(sixel)
}

///|
fn render_json(html : String) -> Unit {
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)
  println(@renderer.layout_to_json(layout))
}

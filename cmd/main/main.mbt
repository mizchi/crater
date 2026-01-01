///|
/// HTML/CSS Renderer CLI
/// Renders HTML with inline styles to Sixel graphics
///
/// Usage:
///   moon run cmd/main -- <file.html>
///   moon run cmd/main -- --json <file.html>
///   moon run cmd/main -- --width 800 --height 600 <file.html>
///   moon run cmd/main              (use example)

///|
/// Default viewport dimensions
let default_width : Int = 800
let default_height : Int = 600

///|
fn main {
  let args = @env.args()

  // Parse arguments
  let mut input : String? = None
  let mut json_output = false
  let mut width : Int? = None
  let mut height : Int? = None
  let mut skip_next = false

  for i = 1; i < args.length(); i = i + 1 {
    if skip_next {
      skip_next = false
      continue
    }
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else if arg == "--json" {
      json_output = true
    } else if arg == "--width" || arg == "-w" {
      if i + 1 < args.length() {
        width = parse_int(args[i + 1])
        skip_next = true
      }
    } else if arg == "--height" || arg == "-H" {
      if i + 1 < args.length() {
        height = parse_int(args[i + 1])
        skip_next = true
      }
    } else if arg.has_prefix("--width=") {
      width = parse_int(arg.substring(start=8))
    } else if arg.has_prefix("--height=") {
      height = parse_int(arg.substring(start=9))
    } else if arg.has_prefix("-w=") {
      width = parse_int(arg.substring(start=3))
    } else if arg.has_prefix("-H=") {
      height = parse_int(arg.substring(start=3))
    } else if input is None {
      input = Some(arg)
    }
  }

  // Resolve viewport dimensions
  let viewport_width = width.unwrap_or(default_width)
  let viewport_height = height.unwrap_or(default_height)

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
    render_json(html, viewport_width, viewport_height)
  } else {
    render_html(html, viewport_width, viewport_height)
  }
}

///|
/// Parse integer from string
fn parse_int(s : String) -> Int? {
  try {
    Some(@strconv.parse_int(s.trim().to_string()))
  } catch {
    _ => None
  }
}

///|
fn print_usage() -> Unit {
  println("crater - HTML/CSS Layout Renderer")
  println("")
  println("Usage:")
  println("  moon run cmd/main -- <file.html>")
  println("  moon run cmd/main -- --json <file.html>")
  println("  moon run cmd/main -- --width 800 --height 600 <file.html>")
  println("  moon run cmd/main       (example)")
  println("")
  println("Options:")
  println("  -w, --width <px>   Viewport width (default: 800)")
  println("  -H, --height <px>  Viewport height (default: 600)")
  println("  --json             Output layout as JSON")
  println("  -h, --help         Show this help message")
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
fn render_html(html : String, width : Int, height : Int) -> Unit {
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
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)

  println("=== Layout Tree ===")
  @renderer.print_layout_tree(layout, 0)
  println("")

  println("=== Sixel Output ===")
  let sixel = @sixel.render_layout(layout, width, height)
  println(sixel)
}

///|
fn render_json(html : String, width : Int, height : Int) -> Unit {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  println(@renderer.layout_to_json(layout))
}

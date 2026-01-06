///|
test "img_placeholder_rendering" {
  // Create a simple layout with an img element
  let html = #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|  <p>Before</p>
    #|  <img src="test.jpg" width="160" height="80" alt="Test Image">
    #|  <p>After</p>
    #|</body>
    #|</html>
  
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
  }
  
  // Get node and layout
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  
  // Debug: print layout tree
  println("=== Layout Tree ===")
  @renderer.print_layout_tree(layout, 0)
  
  // Convert to PaintNode
  let paint_node = @paint.from_node_and_layout(node, layout)
  
  // Debug: print paint tree
  fn print_paint_tree(p : @paint.PaintNode, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    println(indent + "tag=" + p.tag + " id=" + p.id + " (" + p.x.to_string() + "," + p.y.to_string() + ") " + p.width.to_string() + "x" + p.height.to_string() + " text=" + p.text.or_else(fn() { "None" }).to_string())
    for child in p.children {
      print_paint_tree(child, depth + 1)
    }
  }
  println("=== Paint Tree ===")
  print_paint_tree(paint_node, 0)
  
  // Find img in paint tree
  fn find_img(p : @paint.PaintNode) -> @paint.PaintNode? {
    if p.tag == "img" {
      return Some(p)
    }
    for child in p.children {
      match find_img(child) {
        Some(img) => return Some(img)
        None => continue
      }
    }
    None
  }
  
  match find_img(paint_node) {
    Some(img) => {
      println("=== Found img ===")
      println("tag: " + img.tag)
      println("width: " + img.width.to_string())
      println("height: " + img.height.to_string())
      println("text: " + img.text.or_else(fn() { "None" }).to_string())
      // Verify img has correct properties
      inspect!(img.tag, content="img")
      inspect!(img.width > 0.0, content="true")
      inspect!(img.height > 0.0, content="true")
    }
    None => {
      println("ERROR: No img found in paint tree!")
      fail!("No img found in paint tree")
    }
  }
  
  // Render to buffer
  let width = 40  // characters
  let height = 20 // characters
  let result = render_to_ansi(node, layout, width, height, 0)
  println("=== ANSI Output (first 500 chars) ===")
  let preview = if result.ansi.length() > 500 {
    result.ansi.substring(end=500)
  } else {
    result.ansi
  }
  println(preview)
}

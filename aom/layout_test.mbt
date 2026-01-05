///|
/// Tests for AOM + Layout integration

///|
test "extract bounds from LayoutTree" {
  @dispatch.setup()
  // Create a simple layout tree manually
  let child = @tree.LayoutNode::new(
    "btn1",
    @style.Style::{
      ..@style.Style::default(),
      width: @types.Length(100.0),
      height: @types.Length(40.0),
    },
    [],
  )
  let root = @tree.LayoutNode::new(
    "container",
    @style.Style::{
      ..@style.Style::default(),
      width: @types.Length(800.0),
      height: @types.Length(600.0),
      display: @style.Flex,
      justify_content: @style.Center,
      align_items: @style.Center,
    },
    [child],
  )
  let layout_tree = @tree.LayoutTree::new(root, 800.0, 600.0)
  // Use calculate_layout which populates computed_* fields
  let _ = layout_tree.calculate_layout(800.0, 600.0)
  // Extract bounds
  let bounds_map = extract_bounds_from_layout(layout_tree)
  // Check container bounds
  match bounds_map.get("container") {
    Some(b) => {
      inspect(b.x, content="0")
      inspect(b.y, content="0")
      inspect(b.width, content="800")
      inspect(b.height, content="600")
    }
    None => panic()
  }
  // Check button bounds (centered)
  match bounds_map.get("btn1") {
    Some(b) => {
      inspect(b.width, content="100")
      inspect(b.height, content="40")
      // Centered: x = (800 - 100) / 2 = 350
      inspect(b.x, content="350")
      // Centered: y = (600 - 40) / 2 = 280
      inspect(b.y, content="280")
    }
    None => panic()
  }
}

///|
test "attach bounds to AccessibilityTree" {
  // Create a simple HTML document
  let html =
    #|<div id="container">
    #|  <button id="btn1">Click me</button>
    #|  <a id="link1" href="/home">Home</a>
    #|</div>
  let doc = @html.parse_document(html)
  // Build accessibility tree
  let a11y_tree = build_accessibility_tree(doc)
  // Create bounds map manually
  let bounds_map : Map[String, Bounds] = {}
  bounds_map["container"] = Bounds::new(0.0, 0.0, 800.0, 600.0)
  bounds_map["btn1"] = Bounds::new(10.0, 10.0, 100.0, 40.0)
  bounds_map["link1"] = Bounds::new(10.0, 60.0, 80.0, 20.0)
  // Attach bounds
  let tree_with_bounds = attach_bounds(a11y_tree, bounds_map)
  // Check that bounds are attached
  match tree_with_bounds.find_by_source_id("btn1") {
    Some(node) => {
      inspect(node.role, content="Button")
      match node.bounds {
        Some(b) => {
          inspect(b.x, content="10")
          inspect(b.y, content="10")
          inspect(b.width, content="100")
          inspect(b.height, content="40")
        }
        None => panic()
      }
    }
    None => panic()
  }
  match tree_with_bounds.find_by_source_id("link1") {
    Some(node) => {
      inspect(node.role, content="Link")
      match node.bounds {
        Some(b) => {
          inspect(b.x, content="10")
          inspect(b.y, content="60")
          inspect(b.width, content="80")
          inspect(b.height, content="20")
        }
        None => panic()
      }
    }
    None => panic()
  }
}

///|
test "build_accessibility_tree_with_layout - full integration" {
  @dispatch.setup()
  // Create HTML
  let html =
    #|<div id="nav">
    #|  <button id="btn">Menu</button>
    #|</div>
  let doc = @html.parse_document(html)
  // Build layout tree from HTML
  let layout_tree = @tree.LayoutTree::from_html_document(doc, 800.0, 600.0)
  // Use calculate_layout which populates computed_* fields
  let _ = layout_tree.calculate_layout(800.0, 600.0)
  // Build integrated accessibility tree with bounds
  let a11y_tree = build_accessibility_tree_with_layout(doc, layout_tree)
  // Check that button has bounds
  match a11y_tree.find_by_source_id("btn") {
    Some(node) => {
      inspect(node.role, content="Button")
      inspect(node.name, content="Some(\"Menu\")")
      // Bounds should be attached from layout
      inspect(node.bounds is Some(_), content="true")
    }
    None => panic()
  }
}

///|
test "find interactive elements with bounds" {
  // Create HTML with multiple interactive elements
  let html =
    #|<div id="form">
    #|  <input id="email" type="text" />
    #|  <button id="submit">Submit</button>
    #|  <a id="cancel" href="/home">Cancel</a>
    #|</div>
  let doc = @html.parse_document(html)
  let a11y_tree = build_accessibility_tree(doc)
  // Create bounds map
  let bounds_map : Map[String, Bounds] = {}
  bounds_map["email"] = Bounds::new(10.0, 10.0, 200.0, 30.0)
  bounds_map["submit"] = Bounds::new(10.0, 50.0, 100.0, 40.0)
  bounds_map["cancel"] = Bounds::new(120.0, 50.0, 80.0, 40.0)
  let tree_with_bounds = attach_bounds(a11y_tree, bounds_map)
  // Find all interactive elements
  let interactive = find_interactive(tree_with_bounds)
  inspect(interactive.length(), content="3")
  // Check that all have bounds
  for node in interactive {
    inspect(node.bounds is Some(_), content="true")
  }
}

///|
test "find focusable elements with bounds for keyboard navigation" {
  let html =
    #|<div id="container">
    #|  <h1 id="title">Page Title</h1>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2">Second</button>
    #|  <p id="text">Some text</p>
    #|</div>
  let doc = @html.parse_document(html)
  let a11y_tree = build_accessibility_tree(doc)
  // Create bounds map with vertical layout
  let bounds_map : Map[String, Bounds] = {}
  bounds_map["title"] = Bounds::new(10.0, 10.0, 300.0, 50.0)
  bounds_map["btn1"] = Bounds::new(10.0, 70.0, 100.0, 40.0)
  bounds_map["btn2"] = Bounds::new(10.0, 120.0, 100.0, 40.0)
  bounds_map["text"] = Bounds::new(10.0, 170.0, 400.0, 30.0)
  let tree_with_bounds = attach_bounds(a11y_tree, bounds_map)
  // Find focusable elements
  let focusable = tree_with_bounds.find_focusable()
  inspect(focusable.length(), content="2")
  // Both should be buttons
  inspect(focusable[0].role, content="Button")
  inspect(focusable[1].role, content="Button")
  // Check bounds for keyboard navigation order (sorted by y position)
  match (focusable[0].bounds, focusable[1].bounds) {
    (Some(b1), Some(b2)) =>
      // btn1 should be above btn2
      inspect(b1.y < b2.y, content="true")
    _ => panic()
  }
}

///|
test "heading navigation with bounds" {
  let html =
    #|<article id="article">
    #|  <h1 id="h1">Main Title</h1>
    #|  <p>Content</p>
    #|  <h2 id="h2">Section 1</h2>
    #|  <p>More content</p>
    #|  <h2 id="h3">Section 2</h2>
    #|</article>
  let doc = @html.parse_document(html)
  let a11y_tree = build_accessibility_tree(doc)
  // Create bounds map
  let bounds_map : Map[String, Bounds] = {}
  bounds_map["h1"] = Bounds::new(10.0, 10.0, 400.0, 40.0)
  bounds_map["h2"] = Bounds::new(10.0, 100.0, 300.0, 30.0)
  bounds_map["h3"] = Bounds::new(10.0, 200.0, 300.0, 30.0)
  let tree_with_bounds = attach_bounds(a11y_tree, bounds_map)
  // Find headings
  let headings = find_headings(tree_with_bounds)
  inspect(headings.length(), content="3")
  // Check levels
  inspect(headings[0].level, content="Some(1)")
  inspect(headings[1].level, content="Some(2)")
  inspect(headings[2].level, content="Some(2)")
  // Check bounds
  for heading in headings {
    inspect(heading.bounds is Some(_), content="true")
  }
}

///|
test "landmark navigation with bounds" {
  let html =
    #|<body id="body">
    #|  <nav id="nav"><a href="/">Home</a></nav>
    #|  <main id="main"><p>Content</p></main>
    #|  <footer id="footer">Copyright</footer>
    #|</body>
  let elem = @html.parse(html).unwrap()
  let a11y_tree = build_accessibility_tree_from_element(elem)
  // Create bounds map
  let bounds_map : Map[String, Bounds] = {}
  bounds_map["nav"] = Bounds::new(0.0, 0.0, 800.0, 60.0)
  bounds_map["main"] = Bounds::new(0.0, 60.0, 800.0, 500.0)
  bounds_map["footer"] = Bounds::new(0.0, 560.0, 800.0, 40.0)
  let tree_with_bounds = attach_bounds(a11y_tree, bounds_map)
  // Find landmarks
  let landmarks = find_landmarks(tree_with_bounds)
  inspect(landmarks.length(), content="3")
  // Check roles
  let roles : Array[String] = []
  for lm in landmarks {
    roles.push(lm.role.to_string())
  }
  inspect(roles.contains("navigation"), content="true")
  inspect(roles.contains("main"), content="true")
  inspect(roles.contains("contentinfo"), content="true")
}

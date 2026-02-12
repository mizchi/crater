///|
/// Build a renderer context from viewport and color mode
pub fn create_render_context(
  viewport_width : Int,
  viewport_height : Int,
  dark_mode : Bool,
) -> @renderer.RenderContext {
  let color_scheme : @media.ColorScheme = if dark_mode {
    @media.ColorScheme::Dark
  } else {
    @media.ColorScheme::Light
  }
  {
    viewport_width: viewport_width.to_double(),
    viewport_height: viewport_height.to_double(),
    root_font_size: 16.0,
    color_scheme,
  }
}

///|
/// Parse CSS with diagnostics and print an aggregated support report
pub fn report_css_support(css_list : Array[String]) -> Unit {
  // Aggregate summaries from all stylesheets
  let mut total = 0
  let mut supported = 0
  let mut partial = 0
  let mut unsupported_layout = 0
  let mut unsupported_visual = 0
  let mut deprecated = 0
  let mut unknown = 0
  let all_diagnostics : Array[@diagnostics.Diagnostic] = []
  let seen : Map[String, Bool] = {}
  // Parse all CSS with diagnostics
  for css in css_list {
    let result = @parser.parse_stylesheet_with_diagnostics(css)
    let summary = result.diagnostics.get_summary()
    // Aggregate counts
    total += summary.total_properties
    supported += summary.supported
    partial += summary.partial
    unsupported_layout += summary.unsupported_layout
    unsupported_visual += summary.unsupported_visual
    deprecated += summary.deprecated
    unknown += summary.unknown
    // Collect unique diagnostics (non-supported only)
    for diag in result.diagnostics.get_diagnostics() {
      let key = diag.property + ":" + diag.value
      if not(seen.contains(key)) {
        seen.set(key, true)
        all_diagnostics.push(diag)
      }
    }
  }
  // Print compact summary
  let buf = StringBuilder::new()
  buf.write_string("\nCSS: ")
  buf.write_string(supported.to_string())
  buf.write_string(" ok")
  if partial > 0 {
    buf.write_string(", ")
    buf.write_string(partial.to_string())
    buf.write_string(" partial")
  }
  if unsupported_visual > 0 {
    buf.write_string(", ")
    buf.write_string(unsupported_visual.to_string())
    buf.write_string(" visual-only")
  }
  if unsupported_layout > 0 {
    buf.write_string(", ")
    buf.write_string(unsupported_layout.to_string())
    buf.write_string(" layout!")
  }
  if unknown > 0 {
    buf.write_string(", ")
    buf.write_string(unknown.to_string())
    buf.write_string(" unknown!")
  }
  println(buf.to_string())
  // Print detailed report if there are issues
  if unsupported_layout > 0 || unknown > 0 {
    println("=== CSS Support Report ===")
    println("Total properties: " + total.to_string())
    println("  Supported: " + supported.to_string())
    if partial > 0 {
      println("  Partial: " + partial.to_string())
    }
    if deprecated > 0 {
      println("  Deprecated: " + deprecated.to_string())
    }
    if unsupported_visual > 0 {
      println("  Unsupported (visual): " + unsupported_visual.to_string())
    }
    if unsupported_layout > 0 {
      println(
        "  Unsupported (layout): " +
        unsupported_layout.to_string() +
        " [WARNING]",
      )
    }
    if unknown > 0 {
      println("  Unknown: " + unknown.to_string() + " [ERROR]")
    }
    // Print first few layout-affecting issues
    let layout_issues : Array[@diagnostics.Diagnostic] = []
    for diag in all_diagnostics {
      if @diagnostics.affects_layout(diag.level) {
        layout_issues.push(diag)
      }
    }
    if layout_issues.length() > 0 {
      println("\n--- Layout-affecting issues ---")
      let count = if layout_issues.length() > 10 {
        10
      } else {
        layout_issues.length()
      }
      for i = 0; i < count; i = i + 1 {
        let diag = layout_issues[i]
        println("  " + diag.property + ": " + diag.value)
      }
      if layout_issues.length() > 10 {
        println(
          "  ... and " + (layout_issues.length() - 10).to_string() + " more",
        )
      }
    }
    // Print first few unknown properties
    let unknown_props : Array[@diagnostics.Diagnostic] = []
    for diag in all_diagnostics {
      match diag.level {
        @diagnostics.Unknown => unknown_props.push(diag)
        _ => ()
      }
    }
    if unknown_props.length() > 0 {
      println("\n--- Unknown properties ---")
      let count = if unknown_props.length() > 10 {
        10
      } else {
        unknown_props.length()
      }
      for i = 0; i < count; i = i + 1 {
        let diag = unknown_props[i]
        println("  " + diag.property + ": " + diag.value)
      }
      if unknown_props.length() > 10 {
        println(
          "  ... and " + (unknown_props.length() - 10).to_string() + " more",
        )
      }
    }
  }
}

///|
fn default_extract_config(
  viewport_width : Int,
  viewport_height : Int,
) -> @arc90.ExtractConfig {
  {
    min_text_length: 50,
    viewport_width: viewport_width.to_double(),
    viewport_height: viewport_height.to_double(),
    ad_sizes: [
      (300.0, 250.0),
      (728.0, 90.0),
      (160.0, 600.0),
      (300.0, 600.0),
      (320.0, 50.0),
      (320.0, 100.0),
    ],
  }
}

///|
/// Run Arc90 extraction and return summary
pub fn render_arc90_summary(
  tree : @aom.AccessibilityTree,
  viewport_width : Int,
  viewport_height : Int,
) -> String {
  let result = @arc90.extract_content(
    tree,
    default_extract_config(viewport_width, viewport_height),
  )
  result.to_summary()
}

///|
/// Extract main content text from accessibility tree
pub fn extract_main_text(
  tree : @aom.AccessibilityTree,
  viewport_width : Int,
  viewport_height : Int,
) -> String {
  let result = @arc90.extract_content(
    tree,
    default_extract_config(viewport_width, viewport_height),
  )
  match result.main_content {
    Some(node) => collect_node_text(node)
    None => "(No main content found)"
  }
}

///|
fn collect_node_text(node : @aom.AccessibilityNode) -> String {
  let buf = StringBuilder::new()
  collect_node_text_recursive(node, buf)
  buf.to_string().trim().to_string()
}

///|
fn collect_node_text_recursive(
  node : @aom.AccessibilityNode,
  buf : StringBuilder,
) -> Unit {
  // Skip navigation elements
  if node.role == @aom.Navigation ||
    node.role == @aom.Banner ||
    node.role == @aom.ContentInfo {
    return
  }
  // Add text content if present
  match node.text {
    Some(text) if text.length() > 0 => {
      buf.write_string(text)
      // Add appropriate spacing based on role
      match node.role {
        @aom.Heading | @aom.Paragraph | @aom.ListItem | @aom.Article =>
          buf.write_string("\n\n")
        _ => buf.write_string(" ")
      }
    }
    _ =>
      // If no text, try name (for links, buttons, etc.)
      match node.name {
        Some(name) if name.length() > 0 && node.children.length() == 0 => {
          buf.write_string(name)
          buf.write_string(" ")
        }
        _ => ()
      }
  }
  // Recurse into children
  for child in node.children {
    collect_node_text_recursive(child, buf)
  }
}

///|
/// Run visual grounding demo and return formatted output
pub fn render_grounding_demo(
  tree : @aom.AccessibilityTree,
  viewport_width : Int,
  viewport_height : Int,
) -> String {
  let viewport : @grounding.Viewport = {
    width: viewport_width.to_double(),
    height: viewport_height.to_double(),
  }
  let buf = StringBuilder::new()
  buf.write_string("=== Visual Grounding Demo ===\n")
  buf.write_string("Viewport: ")
  buf.write_string(viewport_width.to_string())
  buf.write_string("x")
  buf.write_string(viewport_height.to_string())
  buf.write_string("\n\n")

  // Test different spatial queries
  let regions : Array[(@grounding.SpatialRegion, String)] = [
    (@grounding.TopLeft, "Top Left"),
    (@grounding.TopRight, "Top Right"),
    (@grounding.Center, "Center"),
    (@grounding.BottomLeft, "Bottom Left"),
    (@grounding.BottomRight, "Bottom Right"),
  ]
  for region_info in regions {
    let (region, name) = region_info
    buf.write_string("--- ")
    buf.write_string(name)
    buf.write_string(" ---\n")
    let results = @grounding.find_by_spatial(
      tree,
      @grounding.InRegion(region),
      viewport,
    )
    if results.length() == 0 {
      buf.write_string("  (no interactive elements)\n")
    } else {
      let limit = if results.length() < 3 { results.length() } else { 3 }
      for i in 0..<limit {
        let r = results[i]
        buf.write_string("  ")
        buf.write_string(r.to_string())
        buf.write_string("\n")
      }
    }
    buf.write_string("\n")
  }

  // Test role-based search
  buf.write_string("--- Links in Top Right ---\n")
  let top_right_links = @grounding.find_by_spatial(
    tree,
    @grounding.RoleInRegion(@aom.Link, @grounding.TopRight),
    viewport,
  )
  if top_right_links.length() == 0 {
    buf.write_string("  (no links)\n")
  } else {
    let limit = if top_right_links.length() < 5 {
      top_right_links.length()
    } else {
      5
    }
    for i in 0..<limit {
      let r = top_right_links[i]
      buf.write_string("  ")
      buf.write_string(r.to_string())
      buf.write_string("\n")
    }
  }
  buf.to_string()
}

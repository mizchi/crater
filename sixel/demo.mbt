///|
/// Demo: Sixel layout visualization
/// Run with: moon run sixel
fn main {
  // Create a sample layout tree (flex container with 3 children)
  let layout : @node.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 300.0,
    height: 200.0,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 10.0, right: 10.0, bottom: 10.0, left: 10.0 },
    border: { top: 2.0, right: 2.0, bottom: 2.0, left: 2.0 },
    children: [
      // Header
      {
        id: "header",
        x: 12.0,
        y: 12.0,
        width: 276.0,
        height: 40.0,
        margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        children: [],
      },
      // Sidebar
      {
        id: "sidebar",
        x: 12.0,
        y: 62.0,
        width: 80.0,
        height: 126.0,
        margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        children: [],
      },
      // Main content
      {
        id: "main",
        x: 102.0,
        y: 62.0,
        width: 186.0,
        height: 126.0,
        margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        padding: { top: 5.0, right: 5.0, bottom: 5.0, left: 5.0 },
        border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        children: [
          // Nested box
          {
            id: "box1",
            x: 5.0,
            y: 5.0,
            width: 80.0,
            height: 50.0,
            margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            children: [],
          },
          {
            id: "box2",
            x: 95.0,
            y: 5.0,
            width: 80.0,
            height: 50.0,
            margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            children: [],
          },
        ],
      },
    ],
  }
  println("Layout visualization (Sixel):")
  println("==============================")
  println("")

  // Render to Sixel
  let sixel = render_layout(layout, 300, 200)
  println(sixel)
  println("")
  println("Layout structure:")
  println("  root (300x200)")
  println("    ├─ header (276x40)")
  println("    ├─ sidebar (80x126)")
  println("    └─ main (186x126)")
  println("         ├─ box1 (80x50)")
  println("         └─ box2 (80x50)")
}

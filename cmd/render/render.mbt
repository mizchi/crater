///|
fn main {
  render_all()
}

///|
fn render_all() -> Unit {
  // Block layout examples
  render_example("01_basic", example_basic())
  render_example("02_nested", example_nested())
  render_example("03_padding", example_padding())
  render_example("04_border", example_border())
  render_example("05_margin", example_margin())
  render_example("06_margin_collapse", example_margin_collapse())
  render_example("07_percentage_width", example_percentage_width())
  render_example("08_percentage_height", example_percentage_height())
  render_example("09_min_max", example_min_max())
  // Flex layout examples
  render_example("11_flex_row", example_flex_row())
  render_example("12_flex_column", example_flex_column())
  render_example("13_flex_grow", example_flex_grow())
  render_example("14_flex_justify", example_flex_justify())
  render_example("15_flex_align", example_flex_align())
  render_example("16_flex_sidebar", example_flex_sidebar())
}

///|
fn render_example(name : String, node : @node.Node) -> Unit {
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  // Dispatch based on display type
  let layout = match node.style.display {
    @style.Flex => @flex.compute(node, ctx)
    _ => @block.compute(node, ctx)
  }
  let svg = @vis.to_svg(layout, 400.0, 300.0)
  println("===FILE:\{name}.svg===")
  println(svg)
}

///|
fn default_style() -> @style.Style {
  @style.Style::default()
}

///|
/// 01: Basic block layout - two children stacked vertically
fn example_basic() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("child1", {
    ..style,
    height: @types.Length(40.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..style,
    height: @types.Length(60.0),
  })
  let root_style = { ..style, width: @types.Length(200.0) }
  @node.Node::new("root", root_style, [child1, child2])
}

///|
/// 02: Nested elements - 3 levels deep
fn example_nested() -> @node.Node {
  let style = default_style()
  let inner = @node.Node::leaf("inner", { ..style, height: @types.Length(30.0) })
  let middle = @node.Node::new(
    "middle",
    {
      ..style,
      padding: @types.Rect::new(
        @types.Length(10.0),
        @types.Length(10.0),
        @types.Length(10.0),
        @types.Length(10.0),
      ),
    },
    [inner],
  )
  let root_style = {
    ..style,
    width: @types.Length(200.0),
    padding: @types.Rect::new(
      @types.Length(15.0),
      @types.Length(15.0),
      @types.Length(15.0),
      @types.Length(15.0),
    ),
  }
  @node.Node::new("root", root_style, [middle])
}

///|
/// 03: Padding on all sides
fn example_padding() -> @node.Node {
  let style = default_style()
  let child = @node.Node::leaf("child", { ..style, height: @types.Length(50.0) })
  let root_style = {
    ..style,
    width: @types.Length(200.0),
    padding: @types.Rect::new(
      @types.Length(20.0), // left
      @types.Length(30.0), // right
      @types.Length(10.0), // top
      @types.Length(40.0), // bottom
    ),
  }
  @node.Node::new("root", root_style, [child])
}

///|
/// 04: Border box
fn example_border() -> @node.Node {
  let style = default_style()
  let child = @node.Node::leaf("child", { ..style, height: @types.Length(40.0) })
  let root_style = {
    ..style,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
    border: @types.Rect::new(
      @types.Length(5.0), // left
      @types.Length(5.0), // right
      @types.Length(10.0), // top
      @types.Length(10.0), // bottom
    ),
  }
  @node.Node::new("root", root_style, [child])
}

///|
/// 05: Margin on children
fn example_margin() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("child1", {
    ..style,
    height: @types.Length(30.0),
    margin: @types.Rect::new(
      @types.Length(20.0), // left
      @types.Length(20.0), // right
      @types.Length(10.0), // top
      @types.Length(10.0), // bottom
    ),
  })
  let child2 = @node.Node::leaf("child2", {
    ..style,
    height: @types.Length(30.0),
  })
  let root_style = { ..style, width: @types.Length(200.0) }
  @node.Node::new("root", root_style, [child1, child2])
}

///|
/// 06: Margin collapsing between siblings
fn example_margin_collapse() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("child1", {
    ..style,
    height: @types.Length(30.0),
    margin: @types.Rect::new(
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(30.0), // bottom margin 30
    ),
  })
  let child2 = @node.Node::leaf("child2", {
    ..style,
    height: @types.Length(30.0),
    margin: @types.Rect::new(
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(20.0), // top margin 20 (collapses with above)
      @types.Length(0.0),
    ),
  })
  let child3 = @node.Node::leaf("child3", {
    ..style,
    height: @types.Length(30.0),
  })
  let root_style = { ..style, width: @types.Length(200.0) }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 07: Percentage width
fn example_percentage_width() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("50%", {
    ..style,
    width: @types.Percent(0.5),
    height: @types.Length(40.0),
  })
  let child2 = @node.Node::leaf("75%", {
    ..style,
    width: @types.Percent(0.75),
    height: @types.Length(40.0),
  })
  let child3 = @node.Node::leaf("100%", {
    ..style,
    width: @types.Percent(1.0),
    height: @types.Length(40.0),
  })
  let root_style = { ..style, width: @types.Length(300.0) }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 08: Percentage height
fn example_percentage_height() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("25%", { ..style, height: @types.Percent(0.25) })
  let child2 = @node.Node::leaf("50%", { ..style, height: @types.Percent(0.5) })
  let root_style = {
    ..style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  @node.Node::new("root", root_style, [child1, child2])
}

///|
/// 09: Min/max width constraints
fn example_min_max() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("min-w:100", {
    ..style,
    width: @types.Length(50.0), // would be 50, but min is 100
    min_width: @types.Length(100.0),
    height: @types.Length(40.0),
  })
  let child2 = @node.Node::leaf("max-w:150", {
    ..style
    // auto width would be 300, but max is 150
    ,
    max_width: @types.Length(150.0),
    height: @types.Length(40.0),
  })
  let child3 = @node.Node::leaf("max-h:30", {
    ..style,
    height: @types.Length(60.0), // would be 60, but max is 30
    max_height: @types.Length(30.0),
  })
  let root_style = { ..style, width: @types.Length(300.0) }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

// =============================================================================
// Flex Layout Examples
// =============================================================================

///|
/// 11: Basic flex row
fn example_flex_row() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("A", {
    ..style,
    width: @types.Length(60.0),
    height: @types.Length(40.0),
  })
  let child2 = @node.Node::leaf("B", {
    ..style,
    width: @types.Length(80.0),
    height: @types.Length(40.0),
  })
  let child3 = @node.Node::leaf("C", {
    ..style,
    width: @types.Length(60.0),
    height: @types.Length(40.0),
  })
  let root_style = {
    ..style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(300.0),
    height: @types.Length(80.0),
  }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 12: Flex column
fn example_flex_column() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("A", {
    ..style,
    width: @types.Length(100.0),
    height: @types.Length(40.0),
  })
  let child2 = @node.Node::leaf("B", {
    ..style,
    width: @types.Length(100.0),
    height: @types.Length(60.0),
  })
  let child3 = @node.Node::leaf("C", {
    ..style,
    width: @types.Length(100.0),
    height: @types.Length(40.0),
  })
  let root_style = {
    ..style,
    display: @style.Flex,
    flex_direction: @style.Column,
    width: @types.Length(150.0),
  }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 13: Flex grow distribution
fn example_flex_grow() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("grow:1", {
    ..style,
    flex_grow: 1.0,
    height: @types.Length(50.0),
  })
  let child2 = @node.Node::leaf("grow:2", {
    ..style,
    flex_grow: 2.0,
    height: @types.Length(50.0),
  })
  let child3 = @node.Node::leaf("grow:1", {
    ..style,
    flex_grow: 1.0,
    height: @types.Length(50.0),
  })
  let root_style = {
    ..style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(400.0),
    height: @types.Length(80.0),
  }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 14: Justify content examples
fn example_flex_justify() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("A", {
    ..style,
    width: @types.Length(50.0),
    height: @types.Length(40.0),
  })
  let child2 = @node.Node::leaf("B", {
    ..style,
    width: @types.Length(50.0),
    height: @types.Length(40.0),
  })
  let child3 = @node.Node::leaf("C", {
    ..style,
    width: @types.Length(50.0),
    height: @types.Length(40.0),
  })
  let root_style = {
    ..style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.SpaceBetween,
    width: @types.Length(300.0),
    height: @types.Length(80.0),
  }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 15: Align items center
fn example_flex_align() -> @node.Node {
  let style = default_style()
  let child1 = @node.Node::leaf("S", {
    ..style,
    width: @types.Length(60.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("M", {
    ..style,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
  })
  let child3 = @node.Node::leaf("L", {
    ..style,
    width: @types.Length(60.0),
    height: @types.Length(90.0),
  })
  let root_style = {
    ..style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Center,
    width: @types.Length(250.0),
    height: @types.Length(120.0),
  }
  @node.Node::new("root", root_style, [child1, child2, child3])
}

///|
/// 16: Sidebar layout with flex
fn example_flex_sidebar() -> @node.Node {
  let style = default_style()

  // Sidebar (fixed width)
  let sidebar = @node.Node::leaf("sidebar", {
    ..style,
    width: @types.Length(80.0),
    height: @types.Length(200.0),
  })

  // Content (flex grow)
  let content = @node.Node::leaf("content", {
    ..style,
    flex_grow: 1.0,
    height: @types.Length(200.0),
  })
  let root_style = {
    ..style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(350.0),
    height: @types.Length(220.0),
    padding: @types.Rect::new(
      @types.Length(10.0),
      @types.Length(10.0),
      @types.Length(10.0),
      @types.Length(10.0),
    ),
  }
  @node.Node::new("root", root_style, [sidebar, content])
}

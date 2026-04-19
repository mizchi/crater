///|
/// SVG Layout Integration
/// Provides utilities for integrating SVG rendering with the layout system

///|
/// Check if a tag name is an SVG element
pub fn is_svg_element_tag(tag : String) -> Bool {
  tag == "svg" ||
  tag == "rect" ||
  tag == "circle" ||
  tag == "ellipse" ||
  tag == "line" ||
  tag == "polyline" ||
  tag == "polygon" ||
  tag == "path" ||
  tag == "g" ||
  tag == "defs" ||
  tag == "use" ||
  tag == "text" ||
  tag == "tspan"
}

///|
/// Check if a tag name is an SVG root element
pub fn is_svg_root_tag(tag : String) -> Bool {
  tag == "svg"
}

///|
/// Create an SVG layout from attributes
/// This is a simpler interface that doesn't require Node access
pub fn create_svg_layout(
  tag : String,
  attributes : Array[(String, String)],
  available_width : Double,
  available_height : Double?,
) -> @types.Layout {
  // Parse width/height from attributes
  let mut width = available_width
  let mut height = match available_height {
    Some(h) => h
    None => available_width // Default to square
  }
  for attr in attributes {
    match attr {
      ("width", v) => width = parse_attr_number(v)
      ("height", v) => height = parse_attr_number(v)
      _ => ()
    }
  }
  {
    id: tag,
    x: 0.0,
    y: 0.0,
    width,
    height,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: width,
    scroll_height: height,
    children: [],
    text: None,
  }
}

///|
/// Convert attributes array to SVGNode
pub fn attributes_to_svg_node(
  tag : String,
  attributes : Array[(String, String)],
) -> @svgcore.SVGNode {
  let svg_node = create_svg_node_for_tag(tag)
  for attr in attributes {
    apply_attribute(svg_node, attr.0, attr.1)
  }
  svg_node
}

///|
fn create_svg_node_for_tag(tag : String) -> @svgcore.SVGNode {
  match tag {
    "rect" =>
      @svgcore.SVGNode::new(
        @svgcore.Rect(x=0.0, y=0.0, width=0.0, height=0.0, rx=0.0, ry=0.0),
      )
    "circle" => @svgcore.SVGNode::new(@svgcore.Circle(cx=0.0, cy=0.0, r=0.0))
    "ellipse" =>
      @svgcore.SVGNode::new(@svgcore.Ellipse(cx=0.0, cy=0.0, rx=0.0, ry=0.0))
    "line" =>
      @svgcore.SVGNode::new(@svgcore.Line(x1=0.0, y1=0.0, x2=0.0, y2=0.0))
    "polyline" => @svgcore.SVGNode::new(@svgcore.Polyline(points=[]))
    "polygon" => @svgcore.SVGNode::new(@svgcore.Polygon(points=[]))
    "path" => @svgcore.SVGNode::new(@svgcore.Path(commands=[]))
    _ => @svgcore.SVGNode::new(@svgcore.Group) // svg, g, defs, etc.
  }
}

///|
fn apply_attribute(
  node : @svgcore.SVGNode,
  name : String,
  value : String,
) -> Unit {
  match name {
    "id" => node.id = value
    "x" =>
      match node.shape {
        @svgcore.Rect(..) as r =>
          node.shape = @svgcore.Rect(
            x=parse_attr_number(value),
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "y" =>
      match node.shape {
        @svgcore.Rect(..) as r =>
          node.shape = @svgcore.Rect(
            x=r.x,
            y=parse_attr_number(value),
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "width" =>
      match node.shape {
        @svgcore.Rect(..) as r =>
          node.shape = @svgcore.Rect(
            x=r.x,
            y=r.y,
            width=parse_attr_number(value),
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "height" =>
      match node.shape {
        @svgcore.Rect(..) as r =>
          node.shape = @svgcore.Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=parse_attr_number(value),
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "cx" =>
      match node.shape {
        @svgcore.Circle(..) as c =>
          node.shape = @svgcore.Circle(
            cx=parse_attr_number(value),
            cy=c.cy,
            r=c.r,
          )
        @svgcore.Ellipse(..) as e =>
          node.shape = @svgcore.Ellipse(
            cx=parse_attr_number(value),
            cy=e.cy,
            rx=e.rx,
            ry=e.ry,
          )
        _ => ()
      }
    "cy" =>
      match node.shape {
        @svgcore.Circle(..) as c =>
          node.shape = @svgcore.Circle(
            cx=c.cx,
            cy=parse_attr_number(value),
            r=c.r,
          )
        @svgcore.Ellipse(..) as e =>
          node.shape = @svgcore.Ellipse(
            cx=e.cx,
            cy=parse_attr_number(value),
            rx=e.rx,
            ry=e.ry,
          )
        _ => ()
      }
    "r" =>
      match node.shape {
        @svgcore.Circle(..) as c =>
          node.shape = @svgcore.Circle(
            cx=c.cx,
            cy=c.cy,
            r=parse_attr_number(value),
          )
        _ => ()
      }
    "rx" =>
      match node.shape {
        @svgcore.Rect(..) as r =>
          node.shape = @svgcore.Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=parse_attr_number(value),
            ry=r.ry,
          )
        @svgcore.Ellipse(..) as e =>
          node.shape = @svgcore.Ellipse(
            cx=e.cx,
            cy=e.cy,
            rx=parse_attr_number(value),
            ry=e.ry,
          )
        _ => ()
      }
    "ry" =>
      match node.shape {
        @svgcore.Rect(..) as r =>
          node.shape = @svgcore.Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=parse_attr_number(value),
          )
        @svgcore.Ellipse(..) as e =>
          node.shape = @svgcore.Ellipse(
            cx=e.cx,
            cy=e.cy,
            rx=e.rx,
            ry=parse_attr_number(value),
          )
        _ => ()
      }
    "x1" =>
      match node.shape {
        @svgcore.Line(..) as l =>
          node.shape = @svgcore.Line(
            x1=parse_attr_number(value),
            y1=l.y1,
            x2=l.x2,
            y2=l.y2,
          )
        _ => ()
      }
    "y1" =>
      match node.shape {
        @svgcore.Line(..) as l =>
          node.shape = @svgcore.Line(
            x1=l.x1,
            y1=parse_attr_number(value),
            x2=l.x2,
            y2=l.y2,
          )
        _ => ()
      }
    "x2" =>
      match node.shape {
        @svgcore.Line(..) as l =>
          node.shape = @svgcore.Line(
            x1=l.x1,
            y1=l.y1,
            x2=parse_attr_number(value),
            y2=l.y2,
          )
        _ => ()
      }
    "y2" =>
      match node.shape {
        @svgcore.Line(..) as l =>
          node.shape = @svgcore.Line(
            x1=l.x1,
            y1=l.y1,
            x2=l.x2,
            y2=parse_attr_number(value),
          )
        _ => ()
      }
    "d" =>
      match node.shape {
        @svgcore.Path(..) =>
          node.shape = @svgcore.Path(commands=@svgcore.parse_path(value))
        _ => ()
      }
    "points" => {
      let points = parse_points(value)
      match node.shape {
        @svgcore.Polyline(..) => node.shape = @svgcore.Polyline(points~)
        @svgcore.Polygon(..) => node.shape = @svgcore.Polygon(points~)
        _ => ()
      }
    }
    "fill" => node.fill = parse_paint(value)
    "stroke" =>
      node.stroke = {
        paint: parse_paint(value),
        width: node.stroke.width,
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
    "stroke-width" =>
      node.stroke = {
        paint: node.stroke.paint,
        width: parse_attr_number(value),
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
    "opacity" => node.opacity = parse_attr_number(value)
    "fill-opacity" => node.fill_opacity = parse_attr_number(value)
    "stroke-opacity" => node.stroke_opacity = parse_attr_number(value)
    "transform" => node.transform = @svgcore.parse_transform(value)
    _ => () // Ignore unknown attributes
  }
}

///|
fn parse_attr_number(s : String) -> Double {
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  // Skip leading whitespace
  while i < len {
    let c = Int::unsafe_to_char(s[i].to_int())
    if c == ' ' || c == '\t' {
      i = i + 1
    } else {
      break
    }
  }
  // Sign
  if i < len && Int::unsafe_to_char(s[i].to_int()) == '-' {
    sign = -1.0
    i = i + 1
  } else if i < len && Int::unsafe_to_char(s[i].to_int()) == '+' {
    i = i + 1
  }
  // Integer part
  while i < len {
    let c = Int::unsafe_to_char(s[i].to_int())
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  // Fractional part
  if i < len && Int::unsafe_to_char(s[i].to_int()) == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let c = Int::unsafe_to_char(s[i].to_int())
      if c >= '0' && c <= '9' {
        result = result + (c.to_int() - 48).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  sign * result
}

///|
fn parse_paint(value : String) -> @svgcore.Paint {
  if value == "none" {
    return @svgcore.None
  }
  @svgcore.SolidColor(parse_color(value))
}

///|
fn parse_color(value : String) -> @svgcore.Color {
  match value {
    "black" => return @svgcore.Color::black()
    "white" => return @svgcore.Color::white()
    "red" => return @svgcore.Color::rgb(255, 0, 0)
    "green" => return @svgcore.Color::rgb(0, 128, 0)
    "blue" => return @svgcore.Color::rgb(0, 0, 255)
    "yellow" => return @svgcore.Color::rgb(255, 255, 0)
    "cyan" => return @svgcore.Color::rgb(0, 255, 255)
    "magenta" => return @svgcore.Color::rgb(255, 0, 255)
    "gray" | "grey" => return @svgcore.Color::rgb(128, 128, 128)
    "orange" => return @svgcore.Color::rgb(255, 165, 0)
    _ => ()
  }
  // Hex color
  if value.length() > 0 && Int::unsafe_to_char(value[0].to_int()) == '#' {
    return parse_hex_color(value)
  }
  @svgcore.Color::black()
}

///|
fn parse_hex_color(value : String) -> @svgcore.Color {
  fn hex_digit(c : Char) -> Int {
    if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      0
    }
  }

  fn char_at(s : String, i : Int) -> Char {
    Int::unsafe_to_char(s[i].to_int())
  }

  if value.length() == 4 {
    let r = hex_digit(char_at(value, 1))
    let g = hex_digit(char_at(value, 2))
    let b = hex_digit(char_at(value, 3))
    @svgcore.Color::rgb(r * 17, g * 17, b * 17)
  } else if value.length() == 7 {
    let r = hex_digit(char_at(value, 1)) * 16 + hex_digit(char_at(value, 2))
    let g = hex_digit(char_at(value, 3)) * 16 + hex_digit(char_at(value, 4))
    let b = hex_digit(char_at(value, 5)) * 16 + hex_digit(char_at(value, 6))
    @svgcore.Color::rgb(r, g, b)
  } else {
    @svgcore.Color::black()
  }
}

///|
fn parse_points(value : String) -> Array[(Double, Double)] {
  let result : Array[(Double, Double)] = []
  let nums : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i = 0; i < value.length(); i = i + 1 {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        nums.push(parse_attr_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    nums.push(parse_attr_number(buf.to_string()))
  }
  let mut i = 0
  while i + 1 < nums.length() {
    result.push((nums[i], nums[i + 1]))
    i = i + 2
  }
  result
}

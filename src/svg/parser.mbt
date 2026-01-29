///|
/// SVG XML Parser
/// Parses SVG markup into SVGNode tree

///|
/// SVG Parser state
priv struct SVGParser {
  data : String
  mut pos : Int
  len : Int
}

///|
fn SVGParser::new(data : String) -> SVGParser {
  { data, pos: 0, len: data.length() }
}

///|
fn SVGParser::is_end(self : SVGParser) -> Bool {
  self.pos >= self.len
}

///|
fn SVGParser::peek(self : SVGParser) -> Char {
  if self.pos < self.len {
    Int::unsafe_to_char(self.data[self.pos].to_int())
  } else {
    '\u0000'
  }
}

///|
fn SVGParser::advance(self : SVGParser) -> Char {
  if self.pos < self.len {
    let c = Int::unsafe_to_char(self.data[self.pos].to_int())
    self.pos = self.pos + 1
    c
  } else {
    '\u0000'
  }
}

///|
fn SVGParser::skip_whitespace(self : SVGParser) -> Unit {
  while not(self.is_end()) {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      let _ = self.advance()

    } else {
      break
    }
  }
}

///|
fn SVGParser::expect_char(self : SVGParser, expected : Char) -> Bool {
  if self.peek() == expected {
    let _ = self.advance()
    true
  } else {
    false
  }
}

///|
fn SVGParser::read_until(self : SVGParser, stop : Char) -> String {
  let buf = StringBuilder::new()
  while not(self.is_end()) && self.peek() != stop {
    buf.write_char(self.advance())
  }
  buf.to_string()
}

///|
fn SVGParser::read_name(self : SVGParser) -> String {
  let buf = StringBuilder::new()
  while not(self.is_end()) {
    let c = self.peek()
    if is_name_char(c) {
      buf.write_char(self.advance())
    } else {
      break
    }
  }
  buf.to_string()
}

///|
fn is_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':'
}

///|
fn SVGParser::read_attr_value(self : SVGParser) -> String {
  self.skip_whitespace()
  if not(self.expect_char('=')) {
    return ""
  }
  self.skip_whitespace()
  let quote = self.peek()
  if quote != '"' && quote != '\'' {
    return ""
  }
  let _ = self.advance()
  let value = self.read_until(quote)
  let _ = self.advance() // Skip closing quote
  value
}

///|
/// Parse SVG markup string into SVGNode
pub fn parse_svg(svg_str : String) -> SVGNode? {
  let parser = SVGParser::new(svg_str)
  parse_element(parser)
}

///|
fn parse_element(parser : SVGParser) -> SVGNode? {
  parser.skip_whitespace()
  // Skip comments and declarations
  while not(parser.is_end()) {
    if parser.peek() == '<' {
      let _ = parser.advance()
      if parser.peek() == '!' || parser.peek() == '?' {
        // Skip comment or declaration
        skip_comment_or_decl(parser)
        parser.skip_whitespace()
        continue
      }
      break
    } else {
      let _ = parser.advance()

    }
  }
  if parser.is_end() {
    return None
  }
  // Read tag name
  let tag_name = parser.read_name()
  if tag_name.length() == 0 {
    return None
  }
  // Create node based on tag
  let node = create_node_for_tag(tag_name)
  // Parse attributes
  parse_attributes(parser, node)
  parser.skip_whitespace()
  // Check for self-closing tag
  if parser.peek() == '/' {
    let _ = parser.advance()
    let _ = parser.expect_char('>')
    return Some(node)
  }
  // Expect closing '>'
  if not(parser.expect_char('>')) {
    return Some(node)
  }
  // Parse children (for container elements)
  match node.shape {
    Group => parse_children(parser, node, tag_name)
    _ =>
      // Skip to end tag for non-container elements
      skip_to_end_tag(parser, tag_name)
  }
  Some(node)
}

///|
fn skip_comment_or_decl(parser : SVGParser) -> Unit {
  // Skip until we find '>'
  while not(parser.is_end()) {
    if parser.advance() == '>' {
      break
    }
  }
}

///|
fn skip_to_end_tag(parser : SVGParser, _tag_name : String) -> Unit {
  // Skip until we find the closing tag
  while not(parser.is_end()) {
    if parser.peek() == '<' {
      let _ = parser.advance()
      if parser.peek() == '/' {
        let _ = parser.advance()
        let _ = parser.read_name() // Read the tag name
        parser.skip_whitespace()
        let _ = parser.expect_char('>')
        break
      }
    } else {
      let _ = parser.advance()

    }
  }
}

///|
fn parse_children(
  parser : SVGParser,
  parent : SVGNode,
  parent_tag : String,
) -> Unit {
  while not(parser.is_end()) {
    parser.skip_whitespace()
    if parser.peek() != '<' {
      // Skip text content
      while not(parser.is_end()) && parser.peek() != '<' {
        let _ = parser.advance()

      }
      continue
    }
    let _ = parser.advance()
    // Check for end tag
    if parser.peek() == '/' {
      let _ = parser.advance()
      let end_tag = parser.read_name()
      if end_tag == parent_tag {
        parser.skip_whitespace()
        let _ = parser.expect_char('>')
        break
      }
      // Skip malformed end tag
      while not(parser.is_end()) && parser.advance() != '>' {

      }
      continue
    }
    // Check for comment/declaration
    if parser.peek() == '!' || parser.peek() == '?' {
      skip_comment_or_decl(parser)
      continue
    }
    // Parse child element
    // Backtrack the '<' we consumed
    parser.pos = parser.pos - 1
    match parse_element(parser) {
      Some(child) => parent.children.push(child)
      None => break
    }
  }
}

///|
fn create_node_for_tag(tag_name : String) -> SVGNode {
  let node = match tag_name {
    "rect" =>
      SVGNode::new(Rect(x=0.0, y=0.0, width=0.0, height=0.0, rx=0.0, ry=0.0))
    "circle" => SVGNode::new(Circle(cx=0.0, cy=0.0, r=0.0))
    "ellipse" => SVGNode::new(Ellipse(cx=0.0, cy=0.0, rx=0.0, ry=0.0))
    "line" => SVGNode::new(Line(x1=0.0, y1=0.0, x2=0.0, y2=0.0))
    "polyline" => SVGNode::new(Polyline(points=[]))
    "polygon" => SVGNode::new(Polygon(points=[]))
    "path" => SVGNode::new(Path(commands=[]))
    _ => SVGNode::new(Group) // svg, g, defs, etc. are groups
  }
  node
}

///|
fn parse_attributes(parser : SVGParser, node : SVGNode) -> Unit {
  while not(parser.is_end()) {
    parser.skip_whitespace()
    let c = parser.peek()
    if c == '>' || c == '/' {
      break
    }
    let attr_name = parser.read_name()
    if attr_name.length() == 0 {
      break
    }
    let attr_value = parser.read_attr_value()
    apply_attribute(node, attr_name, attr_value)
  }
}

///|
fn apply_attribute(node : SVGNode, name : String, value : String) -> Unit {
  match name {
    "id" => node.id = value
    "x" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=parse_length(value),
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
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=parse_length(value),
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "width" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=parse_length(value),
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "height" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=parse_length(value),
            rx=r.rx,
            ry=r.ry,
          )
        _ => ()
      }
    "rx" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=parse_length(value),
            ry=r.ry,
          )
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=e.cx,
            cy=e.cy,
            rx=parse_length(value),
            ry=e.ry,
          )
        _ => ()
      }
    "ry" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=parse_length(value),
          )
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=e.cx,
            cy=e.cy,
            rx=e.rx,
            ry=parse_length(value),
          )
        _ => ()
      }
    "cx" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=parse_length(value), cy=c.cy, r=c.r)
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=parse_length(value),
            cy=e.cy,
            rx=e.rx,
            ry=e.ry,
          )
        _ => ()
      }
    "cy" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=c.cx, cy=parse_length(value), r=c.r)
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=e.cx,
            cy=parse_length(value),
            rx=e.rx,
            ry=e.ry,
          )
        _ => ()
      }
    "r" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=c.cx, cy=c.cy, r=parse_length(value))
        _ => ()
      }
    "x1" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=parse_length(value), y1=l.y1, x2=l.x2, y2=l.y2)
        _ => ()
      }
    "y1" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=parse_length(value), x2=l.x2, y2=l.y2)
        _ => ()
      }
    "x2" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=l.y1, x2=parse_length(value), y2=l.y2)
        _ => ()
      }
    "y2" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=l.y1, x2=l.x2, y2=parse_length(value))
        _ => ()
      }
    "d" =>
      match node.shape {
        Path(..) => node.shape = Path(commands=parse_path(value))
        _ => ()
      }
    "points" =>
      match node.shape {
        Polyline(..) => node.shape = Polyline(points=parse_points(value))
        Polygon(..) => node.shape = Polygon(points=parse_points(value))
        _ => ()
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
        width: parse_length(value),
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
    "opacity" => node.opacity = parse_number(value)
    "fill-opacity" => node.fill_opacity = parse_number(value)
    "stroke-opacity" => node.stroke_opacity = parse_number(value)
    "transform" => node.transform = parse_transform(value)
    _ => () // Ignore unknown attributes
  }
}

///|
fn trim_string(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = Int::unsafe_to_char(s[start].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = Int::unsafe_to_char(s[end - 1].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  build_substring(s, start, end)
}

///|
fn string_starts_with(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  for i = 0; i < prefix.length(); i = i + 1 {
    if s[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
fn string_ends_with(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    return false
  }
  let start = s.length() - suffix.length()
  for i = 0; i < suffix.length(); i = i + 1 {
    if s[start + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
fn parse_length(s : String) -> Double {
  // Simple number parsing (strips common units)
  let s = trim_string(s)
  // Remove units
  let cleaned = if string_ends_with(s, "px") {
    build_substring(s, 0, s.length() - 2)
  } else if string_ends_with(s, "em") || string_ends_with(s, "pt") {
    build_substring(s, 0, s.length() - 2)
  } else if string_ends_with(s, "%") {
    build_substring(s, 0, s.length() - 1)
  } else {
    s
  }
  parse_number(cleaned)
}

///|
fn parse_number(s : String) -> Double {
  let s = trim_string(s)
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  fn char_at(str : String, idx : Int) -> Char {
    Int::unsafe_to_char(str[idx].to_int())
  }
  // Sign
  if i < len && char_at(s, i) == '-' {
    sign = -1.0
    i = i + 1
  } else if i < len && char_at(s, i) == '+' {
    i = i + 1
  }
  // Integer part
  while i < len {
    let c = char_at(s, i)
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  // Fractional part
  if i < len && char_at(s, i) == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let c = char_at(s, i)
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
fn parse_paint(value : String) -> Paint {
  let value = trim_string(value)
  if value == "none" {
    return None
  }
  // Parse color
  let color = parse_color(value)
  SolidColor(color)
}

///|
fn parse_color(value : String) -> Color {
  let value = trim_string(value)
  if value.length() == 0 {
    return Color::black()
  }
  // Named colors
  match value {
    "black" => return Color::black()
    "white" => return Color::white()
    "red" => return Color::rgb(255, 0, 0)
    "green" => return Color::rgb(0, 128, 0)
    "blue" => return Color::rgb(0, 0, 255)
    "yellow" => return Color::rgb(255, 255, 0)
    "cyan" => return Color::rgb(0, 255, 255)
    "magenta" => return Color::rgb(255, 0, 255)
    "gray" | "grey" => return Color::rgb(128, 128, 128)
    "orange" => return Color::rgb(255, 165, 0)
    "purple" => return Color::rgb(128, 0, 128)
    "pink" => return Color::rgb(255, 192, 203)
    "brown" => return Color::rgb(165, 42, 42)
    _ => ()
  }
  // Hex color
  if value.length() > 0 && Int::unsafe_to_char(value[0].to_int()) == '#' {
    return parse_hex_color(value)
  }
  // rgb(r, g, b)
  if string_starts_with(value, "rgb") {
    return parse_rgb_color(value)
  }
  Color::black()
}

///|
fn parse_hex_color(value : String) -> Color {
  // #RGB or #RRGGBB
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
    // #RGB
    let r = hex_digit(char_at(value, 1))
    let g = hex_digit(char_at(value, 2))
    let b = hex_digit(char_at(value, 3))
    Color::rgb(r * 17, g * 17, b * 17)
  } else if value.length() == 7 {
    // #RRGGBB
    let r = hex_digit(char_at(value, 1)) * 16 + hex_digit(char_at(value, 2))
    let g = hex_digit(char_at(value, 3)) * 16 + hex_digit(char_at(value, 4))
    let b = hex_digit(char_at(value, 5)) * 16 + hex_digit(char_at(value, 6))
    Color::rgb(r, g, b)
  } else {
    Color::black()
  }
}

///|
fn parse_rgb_color(value : String) -> Color {
  // rgb(r, g, b) or rgba(r, g, b, a)
  // Find numbers between parentheses
  let mut start = 0
  while start < value.length() &&
        Int::unsafe_to_char(value[start].to_int()) != '(' {
    start = start + 1
  }
  start = start + 1
  let mut end = start
  while end < value.length() && Int::unsafe_to_char(value[end].to_int()) != ')' {
    end = end + 1
  }
  if start >= end {
    return Color::black()
  }
  // Parse comma-separated numbers
  let nums : Array[Int] = []
  let mut num_start = start
  for i = start; i <= end; i = i + 1 {
    let c = if i < value.length() {
      Int::unsafe_to_char(value[i].to_int())
    } else {
      ')'
    }
    if c == ',' || c == ')' {
      if num_start < i {
        let num_str = build_substring(value, num_start, i)
        nums.push(parse_number(num_str).to_int())
      }
      num_start = i + 1
    }
  }
  if nums.length() >= 3 {
    Color::rgb(nums[0], nums[1], nums[2])
  } else {
    Color::black()
  }
}

///|
fn build_substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(Int::unsafe_to_char(s[i].to_int()))
  }
  buf.to_string()
}

///|
fn parse_points(value : String) -> Array[(Double, Double)] {
  // Parse space/comma separated list of x,y pairs
  let result : Array[(Double, Double)] = []
  let nums : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i = 0; i < value.length(); i = i + 1 {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        nums.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    nums.push(parse_number(buf.to_string()))
  }
  // Pair up the numbers
  let mut i = 0
  while i + 1 < nums.length() {
    result.push((nums[i], nums[i + 1]))
    i = i + 2
  }
  result
}

///|
pub fn parse_transform(value : String) -> Transform {
  // Parse transform attribute: translate(x, y) scale(sx, sy) rotate(angle) etc.
  let mut result = Transform::identity()
  let mut i = 0
  while i < value.length() {
    // Skip whitespace
    while i < value.length() {
      let c = Int::unsafe_to_char(value[i].to_int())
      if c == ' ' || c == ',' {
        i = i + 1
      } else {
        break
      }
    }
    if i >= value.length() {
      break
    }
    // Read function name
    let name_start = i
    while i < value.length() {
      let c = Int::unsafe_to_char(value[i].to_int())
      if c >= 'a' && c <= 'z' {
        i = i + 1
      } else {
        break
      }
    }
    let name = build_substring(value, name_start, i)
    // Find '('
    while i < value.length() && Int::unsafe_to_char(value[i].to_int()) != '(' {
      i = i + 1
    }
    i = i + 1 // Skip '('
    // Find ')' and parse arguments
    let args_start = i
    while i < value.length() && Int::unsafe_to_char(value[i].to_int()) != ')' {
      i = i + 1
    }
    let args_str = build_substring(value, args_start, i)
    i = i + 1 // Skip ')'
    // Parse arguments
    let args = parse_transform_args(args_str)
    // Apply transform
    let t = match name {
      "translate" =>
        if args.length() >= 2 {
          Transform::translate(args[0], args[1])
        } else if args.length() >= 1 {
          Transform::translate(args[0], 0.0)
        } else {
          Transform::identity()
        }
      "scale" =>
        if args.length() >= 2 {
          Transform::scale(args[0], args[1])
        } else if args.length() >= 1 {
          Transform::scale(args[0], args[0])
        } else {
          Transform::identity()
        }
      "rotate" =>
        if args.length() >= 3 {
          Transform::rotate_around(
            degrees_to_radians(args[0]),
            args[1],
            args[2],
          )
        } else if args.length() >= 1 {
          Transform::rotate(degrees_to_radians(args[0]))
        } else {
          Transform::identity()
        }
      "skewX" =>
        if args.length() >= 1 {
          Transform::skew_x(degrees_to_radians(args[0]))
        } else {
          Transform::identity()
        }
      "skewY" =>
        if args.length() >= 1 {
          Transform::skew_y(degrees_to_radians(args[0]))
        } else {
          Transform::identity()
        }
      "matrix" =>
        if args.length() >= 6 {
          Transform::matrix(
            args[0],
            args[1],
            args[2],
            args[3],
            args[4],
            args[5],
          )
        } else {
          Transform::identity()
        }
      _ => Transform::identity()
    }
    result = result.multiply(t)
  }
  result
}

///|
fn parse_transform_args(s : String) -> Array[Double] {
  let result : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let c = Int::unsafe_to_char(s[i].to_int())
    if c == ' ' || c == ',' {
      if buf.to_string().length() > 0 {
        result.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    result.push(parse_number(buf.to_string()))
  }
  result
}

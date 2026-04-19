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
/// SVG parse context for reusable resources
priv struct SVGParseContext {
  symbols : SymbolRegistry
  defs : DefsRegistry
  clips : ClipPathRegistry
  masks : MaskRegistry
  patterns : PatternRegistry
  gradients : GradientRegistry
  markers : MarkerRegistry
  style_stack : Array[InheritedStyle]
  viewport_stack : Array[(Double, Double)]
}

///|
fn SVGParseContext::new() -> SVGParseContext {
  {
    symbols: SymbolRegistry::new(),
    defs: DefsRegistry::new(),
    clips: ClipPathRegistry::new(),
    masks: MaskRegistry::new(),
    patterns: PatternRegistry::new(),
    gradients: GradientRegistry::new(),
    markers: MarkerRegistry::new(),
    style_stack: [],
    viewport_stack: [],
  }
}

///|
priv struct InheritedStyle {
  fill : Paint
  stroke : StrokeStyle
  color : Color?
}

///|
fn InheritedStyle::default() -> InheritedStyle {
  {
    fill: SolidColor(Color::black()),
    stroke: StrokeStyle::default(),
    color: None,
  }
}

///|
fn SVGParseContext::current_style(self : SVGParseContext) -> InheritedStyle {
  if self.style_stack.length() == 0 {
    InheritedStyle::default()
  } else {
    self.style_stack[self.style_stack.length() - 1]
  }
}

///|
fn inherited_style_from_node(node : SVGNode) -> InheritedStyle {
  { fill: node.fill, stroke: node.stroke, color: node.color }
}

///|
fn apply_inherited_style(node : SVGNode, inherited : InheritedStyle) -> Unit {
  if not(node.fill_is_set) {
    node.fill = inherited.fill
  }
  if not(node.stroke_paint_is_set) {
    node.stroke = { ..node.stroke, paint: inherited.stroke.paint }
  }
  if not(node.stroke_width_is_set) {
    node.stroke = { ..node.stroke, width: inherited.stroke.width }
  }
  if not(node.color_is_set) {
    node.color = inherited.color
  }
}

///|
fn apply_inherited_markers(child : SVGNode, parent : SVGNode) -> Unit {
  if not(child.marker_start_is_set) {
    child.marker_start = parent.marker_start
  }
  if not(child.marker_mid_is_set) {
    child.marker_mid = parent.marker_mid
  }
  if not(child.marker_end_is_set) {
    child.marker_end = parent.marker_end
  }
}

///|
fn SVGParseContext::current_viewport(
  self : SVGParseContext,
) -> (Double, Double)? {
  if self.viewport_stack.length() == 0 {
    None
  } else {
    Some(self.viewport_stack[self.viewport_stack.length() - 1])
  }
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
  match parse_svg_document(svg_str) {
    Some(doc) => Some(doc.root)
    None => None
  }
}

///|
/// Parse SVG markup string into SVGDocument with resources
pub fn parse_svg_document(svg_str : String) -> SVGDocument? {
  let parser = SVGParser::new(svg_str)
  let ctx = SVGParseContext::new()
  match parse_element(parser, ctx, "") {
    Some(root) =>
      Some({
        root,
        symbols: ctx.symbols,
        clips: ctx.clips,
        masks: ctx.masks,
        patterns: ctx.patterns,
        gradients: ctx.gradients,
        markers: ctx.markers,
      })
    None => None
  }
}

///|
fn parse_element(
  parser : SVGParser,
  ctx : SVGParseContext,
  parent_tag : String,
) -> SVGNode? {
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
  // Parse attributes (raw)
  let attrs = parse_attributes(parser)
  parser.skip_whitespace()
  // Check for self-closing tag
  let mut self_closing = false
  if parser.peek() == '/' {
    let _ = parser.advance()
    let _ = parser.expect_char('>')
    self_closing = true
  } else {
    // Expect closing '>'
    let _ = parser.expect_char('>')
  }
  match tag_name {
    "defs" => {
      if not(self_closing) {
        let temp = SVGNode::new(Group)
        parse_children(parser, temp, tag_name, ctx)
      }
      Group |> SVGNode::new |> Some
    }
    "symbol" => {
      let symbol_node = SVGNode::new(Group)
      let id = match get_attr(attrs, "id") {
        Some(v) => v
        None => ""
      }
      symbol_node.id = id
      let view_box = match get_attr(attrs, "viewBox") {
        Some(v) => parse_view_box(v)
        None => None
      }
      let width = match get_attr(attrs, "width") {
        Some(v) => v |> parse_length |> Some
        None => None
      }
      let height = match get_attr(attrs, "height") {
        Some(v) => v |> parse_length |> Some
        None => None
      }
      let display_none = match get_attr(attrs, "display") {
        Some(v) => trim_string(v) == "none"
        None => false
      }
      let preserve = match get_attr(attrs, "preserveAspectRatio") {
        Some(v) => parse_preserve_aspect_ratio(v)
        None => PreserveAspectRatio::default()
      }
      if not(self_closing) {
        parse_children(parser, symbol_node, tag_name, ctx)
      }
      let symbol = match view_box {
        Some(vb) =>
          {
            ..Symbol::with_viewbox(id, symbol_node, vb),
            preserve_aspect_ratio: preserve,
          }
        None =>
          { ..Symbol::new(id, symbol_node), preserve_aspect_ratio: preserve }
      }
      let symbol = { ..symbol, width, height, display_none }
      ctx.symbols.add(symbol)
      Group |> SVGNode::new |> Some
    }
    "clipPath" => {
      if not(self_closing) {
        parse_clip_path(parser, attrs, ctx, tag_name)
      } else {
        parse_clip_path_from_attrs(attrs, ctx)
      }
      Group |> SVGNode::new |> Some
    }
    "mask" => {
      if not(self_closing) {
        parse_mask(parser, attrs, ctx, tag_name)
      } else {
        parse_mask_from_attrs(attrs, ctx)
      }
      Group |> SVGNode::new |> Some
    }
    "marker" => {
      if not(self_closing) {
        parse_marker(parser, attrs, ctx, tag_name, parent_tag)
      } else {
        parse_marker_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "image" => {
      let node = parse_image(attrs)
      if not(self_closing) {
        skip_to_end_tag(parser, tag_name)
      }
      node
    }
    "pattern" => {
      if not(self_closing) {
        parse_pattern(parser, attrs, ctx, tag_name, parent_tag)
      } else {
        parse_pattern_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "linearGradient" => {
      if not(self_closing) {
        parse_linear_gradient(parser, attrs, ctx, tag_name, parent_tag)
      } else {
        parse_linear_gradient_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "radialGradient" => {
      if not(self_closing) {
        parse_radial_gradient(parser, attrs, ctx, tag_name, parent_tag)
      } else {
        parse_radial_gradient_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "use" => {
      let node = parse_use(attrs, ctx)
      if not(self_closing) {
        skip_to_end_tag(parser, tag_name)
      }
      match node {
        Some(_) => node
        None => Group |> SVGNode::new |> Some
      }
    }
    _ => {
      // Create node based on tag
      let node = create_node_for_tag(tag_name)
      // Apply attributes
      apply_attributes(node, attrs)
      if tag_name == "svg" {
        if parent_tag != "" {
          if get_attr(attrs, "width") is Some(v) {
            node.viewport_width = v |> parse_length |> Some
          }
          if get_attr(attrs, "height") is Some(v) {
            node.viewport_height = v |> parse_length |> Some
          }
        }
        if get_attr(attrs, "overflow") is Some(v) {
          if trim_string(v) == "visible" {
            node.clip_overflow = false
          }
        }
        let x = match get_attr(attrs, "x") {
          Some(v) => parse_length(v)
          None => 0.0
        }
        let y = match get_attr(attrs, "y") {
          Some(v) => parse_length(v)
          None => 0.0
        }
        if x != 0.0 || y != 0.0 {
          node.transform = Transform::translate(x, y).multiply(node.transform)
        }
      }
      let mut pushed = false
      if tag_name == "svg" && not(self_closing) {
        match (node.viewport_width, node.viewport_height) {
          (Some(w), Some(h)) => {
            ctx.viewport_stack.push((w, h))
            pushed = true
          }
          _ => ()
        }
      }
      // Parse children (for container elements)
      if not(self_closing) {
        match node.shape {
          Group => parse_children(parser, node, tag_name, ctx)
          _ =>
            // Skip to end tag for non-container elements
            skip_to_end_tag(parser, tag_name)
        }
      }
      if pushed {
        let _ = ctx.viewport_stack.pop()
      }
      Some(node)
    }
  }
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
  ctx : SVGParseContext,
) -> Unit {
  let parent_style = ctx.current_style()
  apply_inherited_style(parent, parent_style)
  ctx.style_stack.push(inherited_style_from_node(parent))
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
    match parse_element(parser, ctx, parent_tag) {
      Some(child) => {
        let child_node = child
        apply_inherited_style(child_node, ctx.current_style())
        apply_inherited_markers(child_node, parent)
        parent.children.push(child_node)
        if child_node.id.length() > 0 {
          ctx.defs.add(child_node.id, child_node)
        }
      }
      None => break
    }
  }
  let _ = ctx.style_stack.pop()
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
fn parse_attributes(parser : SVGParser) -> Array[(String, String)] {
  let attrs : Array[(String, String)] = []
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
    attrs.push((attr_name, attr_value))
  }
  attrs
}

///|
fn apply_attributes(node : SVGNode, attrs : Array[(String, String)]) -> Unit {
  for attr in attrs {
    apply_presentation_attribute(node, attr.0, attr.1)
  }
}

///|
fn apply_attribute(node : SVGNode, name : String, value : String) -> Unit {
  match name {
    "id" => node.id = value
    "style" => apply_style_attributes(node, value)
    "viewBox" => node.view_box = parse_view_box(value)
    "preserveAspectRatio" => {
      node.preserve_aspect_ratio = parse_preserve_aspect_ratio(value)
      node.preserve_aspect_ratio_is_set = true
    }
    "clip-path" =>
      if parse_url_ref(value) is Some(id) {
        node.set_clip_path(id)
      }
    "mask" => if parse_url_ref(value) is Some(id) { node.set_mask(id) }
    "requiredExtensions" => node.opacity = 0.0
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
        Image(..) as i =>
          node.shape = Image(
            x=parse_length(value),
            y=i.y,
            width=i.width,
            height=i.height,
            href=i.href,
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
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=parse_length(value),
            width=i.width,
            height=i.height,
            href=i.href,
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
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=i.y,
            width=parse_length(value),
            height=i.height,
            href=i.href,
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
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=i.y,
            width=i.width,
            height=parse_length(value),
            href=i.href,
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
    "fill" => {
      node.fill = parse_paint(value)
      node.fill_is_set = true
    }
    "color" => {
      node.color = Some(parse_color(value))
      node.color_is_set = true
    }
    "paint-order" => node.paint_order = parse_paint_order(value)
    "stroke" => {
      node.stroke = {
        paint: parse_paint(value),
        width: node.stroke.width,
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
      node.stroke_paint_is_set = true
    }
    "stroke-width" => {
      node.stroke_width_is_set = true
      node.stroke = {
        paint: node.stroke.paint,
        width: parse_length(value),
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
    }
    "opacity" => node.opacity = parse_number(value)
    "fill-opacity" => node.fill_opacity = parse_number(value)
    "stroke-opacity" => node.stroke_opacity = parse_number(value)
    "transform" => node.transform = parse_transform(value)
    // Stroke detail attributes
    "stroke-linecap" =>
      node.stroke = { ..node.stroke, linecap: parse_linecap(value) }
    "stroke-linejoin" =>
      node.stroke = { ..node.stroke, linejoin: parse_linejoin(value) }
    "stroke-miterlimit" =>
      node.stroke = { ..node.stroke, miterlimit: parse_number(value) }
    "stroke-dasharray" =>
      node.stroke = { ..node.stroke, dasharray: parse_dasharray(value) }
    "stroke-dashoffset" =>
      node.stroke = { ..node.stroke, dashoffset: parse_number(value) }
    "marker-start" => {
      node.marker_start = parse_marker_ref(value)
      node.marker_start_is_set = true
    }
    "marker-mid" => {
      node.marker_mid = parse_marker_ref(value)
      node.marker_mid_is_set = true
    }
    "marker-end" => {
      node.marker_end = parse_marker_ref(value)
      node.marker_end_is_set = true
    }
    "marker" =>
      match parse_marker_ref(value) {
        Some(id) => {
          node.marker_start = Some(id)
          node.marker_mid = Some(id)
          node.marker_end = Some(id)
          node.marker_start_is_set = true
          node.marker_mid_is_set = true
          node.marker_end_is_set = true
        }
        None => {
          node.marker_start = None
          node.marker_mid = None
          node.marker_end = None
          node.marker_start_is_set = true
          node.marker_mid_is_set = true
          node.marker_end_is_set = true
        }
      }
    // Fill rule
    "fill-rule" => node.fill_rule = parse_fill_rule(value)
    "clip-rule" => node.fill_rule = parse_fill_rule(value)
    _ => () // Ignore unknown attributes
  }
}

///|
fn apply_presentation_attribute(
  node : SVGNode,
  name : String,
  value : String,
) -> Unit {
  if name == "marker" {
    return
  }
  apply_attribute(node, name, value)
}

///|
fn parse_marker_ref(value : String) -> String? {
  let v = trim_string(value)
  if v.length() == 0 || v == "none" {
    return None
  }
  parse_url_ref(v)
}

///|
fn apply_style_attributes(node : SVGNode, value : String) -> Unit {
  let pairs = parse_style_pairs(value)
  for pair in pairs {
    let name = pair.0.to_lower()
    if name == "style" {
      continue
    }
    apply_attribute(node, name, pair.1)
  }
}

///|
fn apply_style_attributes_filtered(node : SVGNode, value : String) -> Unit {
  let pairs = parse_style_pairs(value)
  for pair in pairs {
    let name = pair.0.to_lower()
    if name == "style" ||
      name == "transform" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" {
      continue
    }
    apply_attribute(node, name, pair.1)
  }
}

///|
fn apply_presentation_attributes(
  node : SVGNode,
  attrs : Array[(String, String)],
) -> Unit {
  for attr in attrs {
    let name = attr.0
    if name == "id" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href" ||
      name == "xlink:href" ||
      name == "transform" {
      continue
    }
    if name == "style" {
      apply_style_attributes_filtered(node, attr.1)
    } else {
      apply_presentation_attribute(node, name, attr.1)
    }
  }
}

///|
fn extract_paint_order(attrs : Array[(String, String)]) -> PaintOrder? {
  if get_attr(attrs, "paint-order") is Some(v) {
    return v |> parse_paint_order |> Some
  }
  if get_attr(attrs, "style") is Some(style) {
    let pairs = parse_style_pairs(style)
    for pair in pairs {
      let name = pair.0.to_lower()
      if name == "paint-order" {
        return pair.1 |> parse_paint_order |> Some
      }
    }
  }
  None
}

///|
fn apply_paint_order_recursive(node : SVGNode, order : PaintOrder) -> Unit {
  node.paint_order = order
  for child in node.children {
    apply_paint_order_recursive(child, order)
  }
}

///|
fn parse_style_pairs(value : String) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ';' {
      let entry = trim_string(buf.to_string())
      if entry.length() > 0 {
        parse_style_entry(entry, pairs)
      }
      buf = StringBuilder::new()
    } else {
      buf.write_char(c)
    }
  }
  let entry = trim_string(buf.to_string())
  if entry.length() > 0 {
    parse_style_entry(entry, pairs)
  }
  pairs
}

///|
fn parse_style_entry(entry : String, pairs : Array[(String, String)]) -> Unit {
  let mut colon_index = -1
  for i in 0..<entry.length() {
    let c = Int::unsafe_to_char(entry[i].to_int())
    if c == ':' {
      colon_index = i
      break
    }
  }
  if colon_index < 0 {
    return
  }
  let key = trim_string(build_substring(entry, 0, colon_index))
  let value = trim_string(
    build_substring(entry, colon_index + 1, entry.length()),
  )
  if key.length() > 0 {
    pairs.push((key, value))
  }
}

///|
fn get_attr(attrs : Array[(String, String)], name : String) -> String? {
  for attr in attrs {
    if attr.0 == name {
      return Some(attr.1)
    }
  }
  None
}

///|
fn parse_url_ref(value : String) -> String? {
  let v = trim_string(value)
  if v.length() == 0 {
    return None
  }
  if string_starts_with(v, "url(") && string_ends_with(v, ")") {
    let inner = build_substring(v, 4, v.length() - 1)
    let trimmed = trim_string(inner)
    if trimmed.length() > 0 && Int::unsafe_to_char(trimmed[0].to_int()) == '#' {
      return Some(build_substring(trimmed, 1, trimmed.length()))
    }
    return Some(trimmed)
  }
  if Int::unsafe_to_char(v[0].to_int()) == '#' {
    return Some(build_substring(v, 1, v.length()))
  }
  None
}

///|
fn parse_number_list(value : String) -> Array[Double] {
  let nums : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
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
  nums
}

///|
fn split_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        tokens.push(buf.to_string())
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    tokens.push(buf.to_string())
  }
  tokens
}

///|
fn parse_view_box(value : String) -> ViewBox? {
  let nums = parse_number_list(value)
  if nums.length() < 4 {
    return None
  }
  Some(ViewBox::{
    min_x: nums[0],
    min_y: nums[1],
    width: nums[2],
    height: nums[3],
  })
}

///|
fn parse_preserve_aspect_ratio(value : String) -> PreserveAspectRatio {
  let v = trim_string(value)
  if v.length() == 0 {
    return PreserveAspectRatio::default()
  }
  let tokens = split_tokens(v)
  if tokens.length() == 0 {
    return PreserveAspectRatio::default()
  }
  if tokens[0] == "none" {
    return PreserveAspectRatio::{ align: None, meet_or_slice: Meet }
  }
  let align = match tokens[0] {
    "xMinYMin" => XMinYMin
    "xMidYMin" => XMidYMin
    "xMaxYMin" => XMaxYMin
    "xMinYMid" => XMinYMid
    "xMidYMid" => XMidYMid
    "xMaxYMid" => XMaxYMid
    "xMinYMax" => XMinYMax
    "xMidYMax" => XMidYMax
    "xMaxYMax" => XMaxYMax
    _ => XMidYMid
  }
  let meet_or_slice = if tokens.length() > 1 {
    match tokens[1] {
      "slice" => Slice
      _ => Meet
    }
  } else {
    Meet
  }
  PreserveAspectRatio::{ align, meet_or_slice }
}

///|
fn parse_mask_units(value : String) -> MaskUnits {
  match trim_string(value) {
    "userSpaceOnUse" => MaskUnits::UserSpaceOnUse
    "objectBoundingBox" => MaskUnits::ObjectBoundingBox
    _ => MaskUnits::ObjectBoundingBox
  }
}

///|
fn parse_clip_path_units(value : String) -> ClipPathUnits {
  match trim_string(value) {
    "objectBoundingBox" => ClipPathUnits::ObjectBoundingBox
    _ => ClipPathUnits::UserSpaceOnUse
  }
}

///|
fn parse_mask_type(value : String) -> MaskType {
  match trim_string(value) {
    "alpha" => Alpha
    _ => Luminance
  }
}

///|
fn parse_use(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> SVGNode? {
  let href = match get_attr(attrs, "href") {
    Some(v) => Some(v)
    None => get_attr(attrs, "xlink:href")
  }
  let href = match href {
    Some(v) => v
    None => return None
  }
  let x = match get_attr(attrs, "x") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let y = match get_attr(attrs, "y") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let width = match get_attr(attrs, "width") {
    Some(v) => v |> parse_length |> Some
    None => None
  }
  let height = match get_attr(attrs, "height") {
    Some(v) => v |> parse_length |> Some
    None => None
  }
  let (width, height) = match get_attr(attrs, "style") {
    Some(style) => {
      let mut w = width
      let mut h = height
      let pairs = parse_style_pairs(style)
      for pair in pairs {
        let name = pair.0.to_lower()
        if name == "width" {
          w = pair.1 |> parse_length |> Some
        } else if name == "height" {
          h = pair.1 |> parse_length |> Some
        }
      }
      (w, h)
    }
    None => (width, height)
  }
  let use_elem = { ..UseElement::new(href, x, y), width, height }
  let use_elem = match get_attr(attrs, "transform") {
    Some(v) => { ..use_elem, transform: parse_transform(v) }
    None => use_elem
  }
  let viewport_fallback = ctx.current_viewport()
  let (base_href, frag) = split_href_fragment(use_elem.href)
  let allow_data_url_use = false
  match decode_data_svg(base_href) {
    Some(svg_data) if allow_data_url_use =>
      match parse_svg_document(svg_data) {
        Some(doc) => {
          let node = match frag {
            Some(id) =>
              match find_node_by_id(doc.root, id) {
                Some(found) => found.clone()
                None => return None
              }
            None => doc.root.clone()
          }
          let (vb, force_non_uniform) = match node.view_box {
            Some(vb) => (Some(vb), false)
            None =>
              match (node.viewport_width, node.viewport_height) {
                (Some(w), Some(h)) =>
                  (
                    Some(ViewBox::{
                      min_x: 0.0,
                      min_y: 0.0,
                      width: w,
                      height: h,
                    }),
                    true,
                  )
                _ =>
                  match viewport_fallback {
                    Some((vw, vh)) =>
                      (
                        Some(ViewBox::{
                          min_x: 0.0,
                          min_y: 0.0,
                          width: vw,
                          height: vh,
                        }),
                        true,
                      )
                    None => (None, false)
                  }
              }
          }
          if force_non_uniform {
            node.preserve_aspect_ratio = PreserveAspectRatio::{
              align: None,
              meet_or_slice: Meet,
            }
          }
          let vw = match use_elem.width {
            Some(w) => Some(w)
            None =>
              match node.viewport_width {
                Some(w) => Some(w)
                None =>
                  match viewport_fallback {
                    Some((vw, _)) => Some(vw)
                    None => None
                  }
              }
          }
          let vh = match use_elem.height {
            Some(h) => Some(h)
            None =>
              match node.viewport_height {
                Some(h) => Some(h)
                None =>
                  match viewport_fallback {
                    Some((_, vh)) => Some(vh)
                    None => None
                  }
              }
          }
          node.view_box = vb
          node.viewport_width = vw
          node.viewport_height = vh
          let translate = Transform::translate(use_elem.x, use_elem.y)
          let base = translate.multiply(use_elem.transform)
          node.transform = base.multiply(node.transform)
          node.id = get_attr(attrs, "id").unwrap_or("")
          apply_presentation_attributes(node, attrs)
          if extract_paint_order(attrs) is Some(order) {
            apply_paint_order_recursive(node, order)
          }
          Some(node)
        }
        None => None
      }
    _ =>
      match use_elem.instantiate(ctx.symbols) {
        Some(node) => {
          if viewport_fallback is Some((vw, vh)) {
            if node.viewport_width is None {
              node.viewport_width = Some(vw)
            }
            if node.viewport_height is None {
              node.viewport_height = Some(vh)
            }
            if node.view_box is None &&
              node.viewport_width is Some(_) &&
              node.viewport_height is Some(_) {
              node.view_box = Some(ViewBox::{
                min_x: 0.0,
                min_y: 0.0,
                width: node.viewport_width.unwrap(),
                height: node.viewport_height.unwrap(),
              })
              node.preserve_aspect_ratio = PreserveAspectRatio::{
                align: None,
                meet_or_slice: Meet,
              }
            }
          }
          node.id = get_attr(attrs, "id").unwrap_or("")
          apply_presentation_attributes(node, attrs)
          if extract_paint_order(attrs) is Some(order) {
            apply_paint_order_recursive(node, order)
          }
          Some(node)
        }
        None => {
          let id = use_elem.get_id()
          match ctx.defs.get(id) {
            Some(target) => {
              let node = target.clone()
              let (vb, force_non_uniform) = match node.view_box {
                Some(vb) => (Some(vb), false)
                None =>
                  match (node.viewport_width, node.viewport_height) {
                    (Some(w), Some(h)) =>
                      (
                        Some(ViewBox::{
                          min_x: 0.0,
                          min_y: 0.0,
                          width: w,
                          height: h,
                        }),
                        true,
                      )
                    _ =>
                      match viewport_fallback {
                        Some((vw, vh)) =>
                          (
                            Some(ViewBox::{
                              min_x: 0.0,
                              min_y: 0.0,
                              width: vw,
                              height: vh,
                            }),
                            true,
                          )
                        None => (None, false)
                      }
                  }
              }
              if force_non_uniform {
                node.preserve_aspect_ratio = PreserveAspectRatio::{
                  align: None,
                  meet_or_slice: Meet,
                }
              }
              let vw = match use_elem.width {
                Some(w) => Some(w)
                None =>
                  match node.viewport_width {
                    Some(w) => Some(w)
                    None =>
                      match viewport_fallback {
                        Some((vw, _)) => Some(vw)
                        None => None
                      }
                  }
              }
              let vh = match use_elem.height {
                Some(h) => Some(h)
                None =>
                  match node.viewport_height {
                    Some(h) => Some(h)
                    None =>
                      match viewport_fallback {
                        Some((_, vh)) => Some(vh)
                        None => None
                      }
                  }
              }
              node.view_box = vb
              node.viewport_width = vw
              node.viewport_height = vh
              let translate = Transform::translate(use_elem.x, use_elem.y)
              let base = translate.multiply(use_elem.transform)
              node.transform = base.multiply(node.transform)
              node.id = get_attr(attrs, "id").unwrap_or("")
              apply_presentation_attributes(node, attrs)
              if extract_paint_order(attrs) is Some(order) {
                apply_paint_order_recursive(node, order)
              }
              Some(node)
            }
            None => None
          }
        }
      }
  }
}

///|
fn decode_html_entities(value : String) -> String {
  let mut i = 0
  let len = value.length()
  let buf = StringBuilder::new()
  while i < len {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == '&' {
      if i + 3 < len &&
        value[i + 1] == 'l' &&
        value[i + 2] == 't' &&
        value[i + 3] == ';' {
        buf.write_char('<')
        i = i + 4
        continue
      }
      if i + 3 < len &&
        value[i + 1] == 'g' &&
        value[i + 2] == 't' &&
        value[i + 3] == ';' {
        buf.write_char('>')
        i = i + 4
        continue
      }
      if i + 4 < len &&
        value[i + 1] == 'a' &&
        value[i + 2] == 'm' &&
        value[i + 3] == 'p' &&
        value[i + 4] == ';' {
        buf.write_char('&')
        i = i + 5
        continue
      }
      if i + 5 < len &&
        value[i + 1] == 'q' &&
        value[i + 2] == 'u' &&
        value[i + 3] == 'o' &&
        value[i + 4] == 't' &&
        value[i + 5] == ';' {
        buf.write_char('"')
        i = i + 6
        continue
      }
      if i + 5 < len &&
        value[i + 1] == 'a' &&
        value[i + 2] == 'p' &&
        value[i + 3] == 'o' &&
        value[i + 4] == 's' &&
        value[i + 5] == ';' {
        buf.write_char('\'')
        i = i + 6
        continue
      }
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
fn hex_value_local(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(10 + (c.to_int() - 'a'.to_int()))
  } else if c >= 'A' && c <= 'F' {
    Some(10 + (c.to_int() - 'A'.to_int()))
  } else {
    None
  }
}

///|
fn decode_percent_local(value : String) -> String {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == '%' && i + 2 < len {
      let c1 = Int::unsafe_to_char(value[i + 1].to_int())
      let c2 = Int::unsafe_to_char(value[i + 2].to_int())
      match (hex_value_local(c1), hex_value_local(c2)) {
        (Some(h1), Some(h2)) => {
          let v = h1 * 16 + h2
          buf.write_char(Int::unsafe_to_char(v))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
fn base64_value_local(c : Char) -> Int? {
  if c >= 'A' && c <= 'Z' {
    Some(c.to_int() - 'A'.to_int())
  } else if c >= 'a' && c <= 'z' {
    Some(26 + (c.to_int() - 'a'.to_int()))
  } else if c >= '0' && c <= '9' {
    Some(52 + (c.to_int() - '0'.to_int()))
  } else if c == '+' || c == '-' {
    Some(62)
  } else if c == '/' || c == '_' {
    Some(63)
  } else {
    None
  }
}

///|
fn is_base64_ws_local(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn decode_base64_local(value : String) -> String? {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut q0 = 0
  let mut q1 = 0
  let mut q2 = 0
  let mut q3 = 0
  let mut qlen = 0
  let mut pad = 0
  let mut finished = false
  let mut i = 0
  while i < len {
    let c = Int::unsafe_to_char(value[i].to_int())
    if is_base64_ws_local(c) {
      i = i + 1
      continue
    }
    if finished {
      return None
    }
    let v = if c == '=' {
      pad = pad + 1
      -1
    } else {
      match base64_value_local(c) {
        Some(v) => v
        None => return None
      }
    }
    if qlen == 0 {
      q0 = v
    } else if qlen == 1 {
      q1 = v
    } else if qlen == 2 {
      q2 = v
    } else {
      q3 = v
    }
    qlen = qlen + 1
    if qlen == 4 {
      if q0 < 0 || q1 < 0 {
        return None
      }
      if pad == 0 {
        if q2 < 0 || q3 < 0 {
          return None
        }
        let b0 = (q0 << 2) | (q1 >> 4)
        let b1 = ((q1 & 15) << 4) | (q2 >> 2)
        let b2 = ((q2 & 3) << 6) | q3
        buf.write_char(Int::unsafe_to_char(b0))
        buf.write_char(Int::unsafe_to_char(b1))
        buf.write_char(Int::unsafe_to_char(b2))
      } else if pad == 1 {
        if q2 < 0 || q3 >= 0 {
          return None
        }
        let b0 = (q0 << 2) | (q1 >> 4)
        let b1 = ((q1 & 15) << 4) | (q2 >> 2)
        buf.write_char(Int::unsafe_to_char(b0))
        buf.write_char(Int::unsafe_to_char(b1))
        finished = true
      } else if pad == 2 {
        if q2 >= 0 || q3 >= 0 {
          return None
        }
        let b0 = (q0 << 2) | (q1 >> 4)
        buf.write_char(Int::unsafe_to_char(b0))
        finished = true
      } else {
        return None
      }
      qlen = 0
      pad = 0
    }
    i = i + 1
  }
  if qlen != 0 {
    return None
  }
  Some(buf.to_string())
}

///|
fn decode_data_svg(href : String) -> String? {
  let v = trim_string(href)
  if not(string_starts_with(v, "data:image/svg+xml")) {
    return None
  }
  let comma = find_first(v, ',')
  if comma < 0 {
    return None
  }
  let meta = build_substring(v, 0, comma)
  let data = build_substring(v, comma + 1, v.length())
  let meta_lower = meta.to_lower()
  let mut has_base64 = false
  let mut start = 0
  for i = 0; i <= meta_lower.length(); i = i + 1 {
    let is_sep = i == meta_lower.length() ||
      Int::unsafe_to_char(meta_lower[i].to_int()) == ';'
    if is_sep {
      let token = trim_string(build_substring(meta_lower, start, i))
      if token == "base64" {
        has_base64 = true
      }
      start = i + 1
    }
  }
  if has_base64 {
    let cleaned = decode_percent_local(data)
    return decode_base64_local(cleaned)
  }
  let decoded = decode_html_entities(data)
  decoded |> decode_percent_local |> Some
}

///|
fn split_href_fragment(href : String) -> (String, String?) {
  let idx = find_first(href, '#')
  if idx < 0 {
    (href, None)
  } else {
    let base = build_substring(href, 0, idx)
    let frag = build_substring(href, idx + 1, href.length())
    (base, frag |> decode_percent_local |> Some)
  }
}

///|
fn find_node_by_id(node : SVGNode, id : String) -> SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    if find_node_by_id(child, id) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
fn parse_image(attrs : Array[(String, String)]) -> SVGNode? {
  let href = match get_attr(attrs, "href") {
    Some(v) => Some(v)
    None => get_attr(attrs, "xlink:href")
  }
  let href = match href {
    Some(v) => v
    None => return None
  }
  let x = match get_attr(attrs, "x") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let y = match get_attr(attrs, "y") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let mut width = match get_attr(attrs, "width") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let mut height = match get_attr(attrs, "height") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  if height <= 0.0 && width > 0.0 {
    height = width
  }
  if width <= 0.0 && height > 0.0 {
    width = height
  }
  let svg_data = match decode_data_svg(href) {
    Some(data) => data
    None => ""
  }
  let node = SVGNode::new(Image(x~, y~, width~, height~, href=svg_data))
  apply_attributes(node, attrs)
  match node.shape {
    Image(..) as img =>
      node.shape = Image(
        x=img.x,
        y=img.y,
        width=img.width,
        height=img.height,
        href=svg_data,
      )
    _ => ()
  }
  Some(node)
}

///|
fn parse_clip_path_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let clip_rule = match get_attr(attrs, "clip-rule") {
    Some(v) => parse_fill_rule(v)
    None => NonZero
  }
  let transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let units = match get_attr(attrs, "clipPathUnits") {
    Some(v) => parse_clip_path_units(v)
    None => ClipPathUnits::UserSpaceOnUse
  }
  let clip = ClipPath::{ id, shape: Group, transform, clip_rule, units }
  ctx.clips.add(clip)
}

///|
fn parse_clip_path(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
) -> Unit {
  let temp = SVGNode::new(Group)
  parse_children(parser, temp, tag_name, ctx)
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let clip_rule = match get_attr(attrs, "clip-rule") {
    Some(v) => parse_fill_rule(v)
    None => NonZero
  }
  let transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let units = match get_attr(attrs, "clipPathUnits") {
    Some(v) => parse_clip_path_units(v)
    None => ClipPathUnits::UserSpaceOnUse
  }
  let mut shape : Shape? = None
  let mut child_transform = Transform::identity()
  for child in temp.children {
    match child.shape {
      Group => ()
      _ => {
        shape = Some(child.shape)
        child_transform = child.transform
        break
      }
    }
  }
  match shape {
    Some(s) => {
      let combined = transform.multiply(child_transform)
      let clip = ClipPath::{
        id,
        shape: s,
        transform: combined,
        clip_rule,
        units,
      }
      ctx.clips.add(clip)
    }
    None => ()
  }
}

///|
fn parse_mask_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> Unit {
  parse_mask_with_content(attrs, [], ctx)
}

///|
fn parse_mask(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
) -> Unit {
  let temp = SVGNode::new(Group)
  parse_children(parser, temp, tag_name, ctx)
  parse_mask_with_content(attrs, temp.children, ctx)
}

///|
fn parse_mask_with_content(
  attrs : Array[(String, String)],
  content : Array[SVGNode],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let mask_units = match get_attr(attrs, "maskUnits") {
    Some(v) => parse_mask_units(v)
    None => MaskUnits::ObjectBoundingBox
  }
  let mask_content_units = match get_attr(attrs, "maskContentUnits") {
    Some(v) => parse_mask_units(v)
    None => MaskUnits::UserSpaceOnUse
  }
  let mask_type = match get_attr(attrs, "mask-type") {
    Some(v) => parse_mask_type(v)
    None => Luminance
  }
  let mut has_bounds = false
  let mut x = 0.0
  let mut y = 0.0
  let mut width = 0.0
  let mut height = 0.0
  let mut x_is_percent = false
  let mut y_is_percent = false
  let mut width_is_percent = false
  let mut height_is_percent = false
  if get_attr(attrs, "x") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    x = val
    x_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "y") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    y = val
    y_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "width") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    width = val
    width_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "height") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    height = val
    height_is_percent = is_percent
    has_bounds = true
  }
  let base = if has_bounds {
    Mask::with_bounds(id, content, x, y, width, height)
  } else {
    Mask::new(id, content)
  }
  let mask = if has_bounds {
    {
      ..base,
      x_is_percent,
      y_is_percent,
      width_is_percent,
      height_is_percent,
      mask_units,
      mask_content_units,
      mask_type,
    }
  } else {
    { ..base, mask_units, mask_content_units, mask_type }
  }
  ctx.masks.add(mask)
}

///|
fn is_paint_server_context(parent_tag : String) -> Bool {
  parent_tag == "svg" || parent_tag == "defs" || parent_tag == "symbol"
}

///|
fn parse_pattern_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if not(is_paint_server_context(parent_tag)) {
    return
  }
  parse_pattern_with_content(attrs, [], ctx)
}

///|
fn parse_pattern(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
) -> Unit {
  if not(is_paint_server_context(parent_tag)) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let temp = SVGNode::new(Group)
  parse_children(parser, temp, tag_name, ctx)
  parse_pattern_with_content(attrs, temp.children, ctx)
}

///|
fn parse_marker_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  _parent_tag : String,
) -> Unit {
  let node = SVGNode::new(Group)
  apply_attributes(node, attrs)
  apply_inherited_style(node, ctx.current_style())
  parse_marker_with_content(attrs, node, ctx)
}

///|
fn parse_marker(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  _parent_tag : String,
) -> Unit {
  let temp = SVGNode::new(Group)
  apply_attributes(temp, attrs)
  apply_inherited_style(temp, ctx.current_style())
  parse_children(parser, temp, tag_name, ctx)
  parse_marker_with_content(attrs, temp, ctx)
}

///|
fn parse_marker_with_content(
  attrs : Array[(String, String)],
  content : SVGNode,
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let mut ref_x = 0.0
  let mut ref_y = 0.0
  let mut marker_width = 3.0
  let mut marker_height = 3.0
  let mut marker_units = MarkerUnits::StrokeWidth
  let mut orient = MarkerOrient::Angle(0.0)
  let mut view_box : ViewBox? = None
  let mut preserve_aspect_ratio = PreserveAspectRatio::default()
  let mut overflow_visible = false
  if get_attr(attrs, "refX") is Some(v) {
    ref_x = parse_length(v)
  }
  if get_attr(attrs, "refY") is Some(v) {
    ref_y = parse_length(v)
  }
  if get_attr(attrs, "markerWidth") is Some(v) {
    marker_width = parse_length(v)
  }
  if get_attr(attrs, "markerHeight") is Some(v) {
    marker_height = parse_length(v)
  }
  if get_attr(attrs, "markerUnits") is Some(v) {
    marker_units = parse_marker_units(v)
  }
  if get_attr(attrs, "orient") is Some(v) {
    orient = parse_marker_orient(v)
  }
  if get_attr(attrs, "viewBox") is Some(v) {
    view_box = parse_view_box(v)
  }
  if get_attr(attrs, "preserveAspectRatio") is Some(v) {
    preserve_aspect_ratio = parse_preserve_aspect_ratio(v)
  }
  if get_attr(attrs, "overflow") is Some(v) {
    overflow_visible = trim_string(v) == "visible"
  }
  content.viewport_width = Some(marker_width)
  content.viewport_height = Some(marker_height)
  // Marker viewBox is handled by marker transform, not by content node.
  content.view_box = None
  content.preserve_aspect_ratio = PreserveAspectRatio::default()
  content.preserve_aspect_ratio_is_set = false
  // Marker viewport clipping is handled at render time.
  content.clip_overflow = false
  let clip_overflow = not(overflow_visible)
  let marker = {
    ..Marker::new(id, content),
    ref_x,
    ref_y,
    marker_width,
    marker_height,
    marker_units,
    orient,
    view_box,
    preserve_aspect_ratio,
    clip_overflow,
  }
  ctx.markers.add(marker)
}

///|
fn parse_marker_units(value : String) -> MarkerUnits {
  match trim_string(value) {
    "userSpaceOnUse" => MarkerUnits::UserSpaceOnUse_
    "strokeWidth" => MarkerUnits::StrokeWidth
    _ => MarkerUnits::StrokeWidth
  }
}

///|
fn parse_marker_orient(value : String) -> MarkerOrient {
  let v = trim_string(value)
  if v == "auto" {
    MarkerOrient::Auto
  } else if v == "auto-start-reverse" {
    MarkerOrient::AutoStartReverse
  } else {
    let angle = if string_ends_with(v, "deg") {
      parse_number(build_substring(v, 0, v.length() - 3))
    } else {
      parse_number(v)
    }
    MarkerOrient::Angle(angle)
  }
}

///|
fn parse_pattern_with_content(
  attrs : Array[(String, String)],
  content : Array[SVGNode],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let mut width = 0.0
  let mut height = 0.0
  if get_attr(attrs, "width") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    width = val
  }
  if get_attr(attrs, "height") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    height = val
  }
  let pattern_units = match get_attr(attrs, "patternUnits") {
    Some(v) => parse_pattern_units(v)
    None => ObjectBoundingBox
  }
  let pattern_content_units = match get_attr(attrs, "patternContentUnits") {
    Some(v) => parse_pattern_units(v)
    None => UserSpaceOnUse
  }
  let transform = match get_attr(attrs, "patternTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let view_box = match get_attr(attrs, "viewBox") {
    Some(v) => parse_view_box(v)
    None => None
  }
  let pattern = {
    ..Pattern::new(id, width, height, content),
    pattern_units,
    pattern_content_units,
    transform,
    view_box,
  }
  ctx.patterns.add(pattern)
}

///|
fn parse_pattern_units(value : String) -> PatternUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_gradient_units(value : String) -> GradientUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_linear_gradient_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if not(is_paint_server_context(parent_tag)) {
    return
  }
  parse_linear_gradient_with_stops(attrs, [], ctx)
}

///|
fn parse_linear_gradient(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
) -> Unit {
  if not(is_paint_server_context(parent_tag)) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let stops = parse_gradient_stops(parser, tag_name)
  parse_linear_gradient_with_stops(attrs, stops, ctx)
}

///|
fn parse_linear_gradient_with_stops(
  attrs : Array[(String, String)],
  stops : Array[GradientStop],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let x1 = parse_gradient_coord(get_attr(attrs, "x1"), 0.0)
  let y1 = parse_gradient_coord(get_attr(attrs, "y1"), 0.0)
  let x2 = parse_gradient_coord(get_attr(attrs, "x2"), 1.0)
  let y2 = parse_gradient_coord(get_attr(attrs, "y2"), 0.0)
  let spread_method = match get_attr(attrs, "spreadMethod") {
    Some(v) => parse_spread_method(v)
    None => Pad
  }
  let units = match get_attr(attrs, "gradientUnits") {
    Some(v) => parse_gradient_units(v)
    None => ObjectBoundingBox
  }
  let transform = match get_attr(attrs, "gradientTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let grad = {
    ..LinearGradient::new(x1, y1, x2, y2, stops),
    spread_method,
    units,
    transform,
  }
  ctx.gradients.add(id, Gradient::Linear(grad))
}

///|
fn parse_radial_gradient_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if not(is_paint_server_context(parent_tag)) {
    return
  }
  parse_radial_gradient_with_stops(attrs, [], ctx)
}

///|
fn parse_radial_gradient(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
) -> Unit {
  if not(is_paint_server_context(parent_tag)) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let stops = parse_gradient_stops(parser, tag_name)
  parse_radial_gradient_with_stops(attrs, stops, ctx)
}

///|
fn parse_radial_gradient_with_stops(
  attrs : Array[(String, String)],
  stops : Array[GradientStop],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let cx = parse_gradient_coord(get_attr(attrs, "cx"), 0.5)
  let cy = parse_gradient_coord(get_attr(attrs, "cy"), 0.5)
  let r = parse_gradient_coord(get_attr(attrs, "r"), 0.5)
  let fx = match get_attr(attrs, "fx") {
    Some(v) => parse_gradient_coord(Some(v), cx)
    None => cx
  }
  let fy = match get_attr(attrs, "fy") {
    Some(v) => parse_gradient_coord(Some(v), cy)
    None => cy
  }
  let spread_method = match get_attr(attrs, "spreadMethod") {
    Some(v) => parse_spread_method(v)
    None => Pad
  }
  let units = match get_attr(attrs, "gradientUnits") {
    Some(v) => parse_gradient_units(v)
    None => ObjectBoundingBox
  }
  let transform = match get_attr(attrs, "gradientTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let grad = {
    ..RadialGradient::new(cx, cy, r, stops),
    fx,
    fy,
    spread_method,
    units,
    transform,
  }
  ctx.gradients.add(id, Gradient::Radial(grad))
}

///|
fn parse_gradient_coord(value : String?, default : Double) -> Double {
  match value {
    Some(v) => {
      let (val, _) = parse_length_or_percent(v)
      val
    }
    None => default
  }
}

///|
fn parse_spread_method(value : String) -> SpreadMethod {
  match trim_string(value) {
    "repeat" => Repeat
    "reflect" => Reflect
    _ => Pad
  }
}

///|
fn parse_gradient_stops(
  parser : SVGParser,
  parent_tag : String,
) -> Array[GradientStop] {
  let stops : Array[GradientStop] = []
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
    // End tag
    if parser.peek() == '/' {
      let _ = parser.advance()
      let end_tag = parser.read_name()
      if end_tag == parent_tag {
        parser.skip_whitespace()
        let _ = parser.expect_char('>')
        break
      }
      while not(parser.is_end()) && parser.advance() != '>' {

      }
      continue
    }
    if parser.peek() == '!' || parser.peek() == '?' {
      skip_comment_or_decl(parser)
      continue
    }
    let tag_name = parser.read_name()
    if tag_name.length() == 0 {
      continue
    }
    let attrs = parse_attributes(parser)
    parser.skip_whitespace()
    let mut self_closing = false
    if parser.peek() == '/' {
      let _ = parser.advance()
      let _ = parser.expect_char('>')
      self_closing = true
    } else {
      let _ = parser.expect_char('>')
    }
    if tag_name == "stop" {
      stops.push(parse_gradient_stop(attrs))
    }
    if not(self_closing) {
      skip_to_end_tag(parser, tag_name)
    }
  }
  stops
}

///|
fn parse_gradient_stop(attrs : Array[(String, String)]) -> GradientStop {
  let offset = match get_attr(attrs, "offset") {
    Some(v) => parse_gradient_offset(v)
    None => 0.0
  }
  let mut color = Color::black()
  let mut opacity = 1.0
  if get_attr(attrs, "stop-color") is Some(v) {
    color = parse_color(v)
  }
  if get_attr(attrs, "stop-opacity") is Some(v) {
    opacity = parse_number(v)
  }
  if get_attr(attrs, "style") is Some(style) {
    let pairs = parse_style_pairs(style)
    for pair in pairs {
      let key = pair.0.to_lower()
      if key == "stop-color" {
        color = parse_color(pair.1)
      } else if key == "stop-opacity" {
        opacity = parse_number(pair.1)
      }
    }
  }
  if opacity < 0.0 {
    opacity = 0.0
  }
  if opacity > 1.0 {
    opacity = 1.0
  }
  let final_color = if opacity < 1.0 {
    Color::rgba(
      color.r,
      color.g,
      color.b,
      (color.a.to_double() * opacity).to_int(),
    )
  } else {
    color
  }
  { offset, color: final_color }
}

///|
fn parse_gradient_offset(value : String) -> Double {
  let v = trim_string(value)
  let t = if string_ends_with(v, "%") {
    let cleaned = build_substring(v, 0, v.length() - 1)
    parse_number(cleaned) / 100.0
  } else {
    parse_number(v)
  }
  if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
}

///|
fn parse_linecap(value : String) -> LineCap {
  let v = trim_string(value)
  match v {
    "round" => Round
    "square" => Square
    _ => Butt // Default
  }
}

///|
fn parse_linejoin(value : String) -> LineJoin {
  let v = trim_string(value)
  match v {
    "round" => Round
    "bevel" => Bevel
    _ => Miter // Default
  }
}

///|
fn parse_dasharray(value : String) -> Array[Double]? {
  let v = trim_string(value)
  if v == "none" || v.length() == 0 {
    return None
  }
  let result : Array[Double] = []
  let mut current = ""
  for c in v {
    if c == ',' || c == ' ' {
      if current.length() > 0 {
        result.push(parse_number(current))
        current = ""
      }
    } else {
      current = current + c.to_string()
    }
  }
  if current.length() > 0 {
    result.push(parse_number(current))
  }
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
fn parse_fill_rule(value : String) -> FillRule {
  let v = trim_string(value)
  match v {
    "evenodd" => EvenOdd
    _ => NonZero // Default
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
  for i in 0..<prefix.length() {
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
  for i in 0..<suffix.length() {
    if s[start + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
fn find_first(s : String, target : Char) -> Int {
  for i in 0..<s.length() {
    if Int::unsafe_to_char(s[i].to_int()) == target {
      return i
    }
  }
  -1
}

///|
fn parse_length(s : String) -> Double {
  // Simple number parsing (strips common units)
  let s = trim_string(s)
  if string_starts_with(s, "var(") && string_ends_with(s, ")") {
    let inner = build_substring(s, 4, s.length() - 1)
    let comma = find_first(inner, ',')
    if comma >= 0 {
      let fallback = trim_string(
        build_substring(inner, comma + 1, inner.length()),
      )
      if fallback.length() > 0 {
        return parse_length(fallback)
      }
    }
    return 0.0
  }
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
fn parse_length_or_percent(s : String) -> (Double, Bool) {
  let s = trim_string(s)
  if string_ends_with(s, "%") {
    let cleaned = build_substring(s, 0, s.length() - 1)
    (parse_number(cleaned) / 100.0, true)
  } else {
    (parse_length(s), false)
  }
}

///|
fn parse_mask_length(value : String, units : MaskUnits) -> (Double, Bool) {
  let (val, is_percent) = parse_length_or_percent(value)
  match units {
    MaskUnits::ObjectBoundingBox => (val, false)
    MaskUnits::UserSpaceOnUse => (val, is_percent)
  }
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
  if value.length() == 0 {
    return None
  }
  if value == "none" {
    return None
  }
  if value == "currentColor" {
    return CurrentColor
  }
  // Paint server with optional fallback: url(#id) <fallback>
  if string_starts_with(value, "url(") {
    let close_index = find_first(value, ')')
    if close_index >= 0 {
      let url_part = build_substring(value, 0, close_index + 1)
      let rest = trim_string(
        build_substring(value, close_index + 1, value.length()),
      )
      match parse_url_ref(url_part) {
        Some(id) => {
          let fallback = if rest.length() == 0 {
            PaintFallback::NoPaint
          } else {
            parse_paint_fallback(rest)
          }
          return PaintServerRef(id, fallback)
        }
        None => ()
      }
    }
  }
  // Parse color
  let color = parse_color(value)
  SolidColor(color)
}

///|
fn parse_paint_fallback(value : String) -> PaintFallback {
  let value = trim_string(value)
  if value.length() == 0 || value == "none" {
    return PaintFallback::NoPaint
  }
  if value == "currentColor" {
    return PaintFallback::CurrentColor
  }
  PaintFallback::SolidColor(parse_color(value))
}

///|
fn parse_paint_order(value : String) -> PaintOrder {
  let v = trim_string(value)
  if v.length() == 0 || v == "normal" {
    return PaintOrder::default()
  }
  let tokens = split_tokens(v)
  if tokens.length() == 0 {
    return PaintOrder::default()
  }
  let order : Array[PaintOrderItem] = []
  for t in tokens {
    match t {
      "fill" => if not(order.contains(Fill)) { order.push(Fill) }
      "stroke" => if not(order.contains(Stroke)) { order.push(Stroke) }
      "markers" => if not(order.contains(Markers)) { order.push(Markers) }
      _ => ()
    }
  }
  if order.length() == 0 {
    return PaintOrder::default()
  }
  if not(order.contains(Fill)) {
    order.push(Fill)
  }
  if not(order.contains(Stroke)) {
    order.push(Stroke)
  }
  if not(order.contains(Markers)) {
    order.push(Markers)
  }
  PaintOrder::{ order, }
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
  for i in start..<end {
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
  for i in 0..<value.length() {
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
          Transform::rotate(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "skewX" =>
        if args.length() >= 1 {
          Transform::skew_x(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "skewY" =>
        if args.length() >= 1 {
          Transform::skew_y(args[0] |> degrees_to_radians)
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
  for i in 0..<s.length() {
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

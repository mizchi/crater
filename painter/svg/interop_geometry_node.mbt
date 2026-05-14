///|
pub fn path_command_from_msvg(cmd : @msvg.PathCommand) -> PathCommand {
  match cmd {
    MoveTo(x, y) => MoveTo(x, y)
    LineTo(x, y) => LineTo(x, y)
    HorizontalLineTo(x) => HorizontalLineTo(x)
    VerticalLineTo(y) => VerticalLineTo(y)
    CurveTo(x1, y1, x2, y2, x, y) => CurveTo(x1, y1, x2, y2, x, y)
    SmoothCurveTo(x2, y2, x, y) => SmoothCurveTo(x2, y2, x, y)
    QuadraticCurveTo(x1, y1, x, y) => QuadraticCurveTo(x1, y1, x, y)
    SmoothQuadraticCurveTo(x, y) => SmoothQuadraticCurveTo(x, y)
    ArcTo(rx, ry, rotation, large_arc, sweep, x, y) =>
      ArcTo(rx, ry, rotation, large_arc, sweep, x, y)
    ClosePath => ClosePath
    MoveToRel(dx, dy) => MoveToRel(dx, dy)
    LineToRel(dx, dy) => LineToRel(dx, dy)
    HorizontalLineToRel(dx) => HorizontalLineToRel(dx)
    VerticalLineToRel(dy) => VerticalLineToRel(dy)
    CurveToRel(dx1, dy1, dx2, dy2, dx, dy) =>
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy)
    SmoothCurveToRel(dx2, dy2, dx, dy) => SmoothCurveToRel(dx2, dy2, dx, dy)
    QuadraticCurveToRel(dx1, dy1, dx, dy) =>
      QuadraticCurveToRel(dx1, dy1, dx, dy)
    SmoothQuadraticCurveToRel(dx, dy) => SmoothQuadraticCurveToRel(dx, dy)
    ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) =>
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy)
  }
}

///|
fn path_command_to_msvg(cmd : PathCommand) -> @msvg.PathCommand {
  match cmd {
    MoveTo(x, y) => @msvg.PathCommand::MoveTo(x, y)
    LineTo(x, y) => @msvg.PathCommand::LineTo(x, y)
    HorizontalLineTo(x) => @msvg.PathCommand::HorizontalLineTo(x)
    VerticalLineTo(y) => @msvg.PathCommand::VerticalLineTo(y)
    CurveTo(x1, y1, x2, y2, x, y) =>
      @msvg.PathCommand::CurveTo(x1, y1, x2, y2, x, y)
    SmoothCurveTo(x2, y2, x, y) =>
      @msvg.PathCommand::SmoothCurveTo(x2, y2, x, y)
    QuadraticCurveTo(x1, y1, x, y) =>
      @msvg.PathCommand::QuadraticCurveTo(x1, y1, x, y)
    SmoothQuadraticCurveTo(x, y) =>
      @msvg.PathCommand::SmoothQuadraticCurveTo(x, y)
    ArcTo(rx, ry, rotation, large_arc, sweep, x, y) =>
      @msvg.PathCommand::ArcTo(rx, ry, rotation, large_arc, sweep, x, y)
    ClosePath => @msvg.PathCommand::ClosePath
    MoveToRel(dx, dy) => @msvg.PathCommand::MoveToRel(dx, dy)
    LineToRel(dx, dy) => @msvg.PathCommand::LineToRel(dx, dy)
    HorizontalLineToRel(dx) => @msvg.PathCommand::HorizontalLineToRel(dx)
    VerticalLineToRel(dy) => @msvg.PathCommand::VerticalLineToRel(dy)
    CurveToRel(dx1, dy1, dx2, dy2, dx, dy) =>
      @msvg.PathCommand::CurveToRel(dx1, dy1, dx2, dy2, dx, dy)
    SmoothCurveToRel(dx2, dy2, dx, dy) =>
      @msvg.PathCommand::SmoothCurveToRel(dx2, dy2, dx, dy)
    QuadraticCurveToRel(dx1, dy1, dx, dy) =>
      @msvg.PathCommand::QuadraticCurveToRel(dx1, dy1, dx, dy)
    SmoothQuadraticCurveToRel(dx, dy) =>
      @msvg.PathCommand::SmoothQuadraticCurveToRel(dx, dy)
    ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) =>
      @msvg.PathCommand::ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy)
  }
}

///|
fn path_commands_to_msvg(
  commands : Array[PathCommand],
) -> Array[@msvg.PathCommand] {
  commands.map(path_command_to_msvg)
}

///|
fn bounding_box_from_msvg(bbox : @msvg.BoundingBox) -> BoundingBox {
  { min_x: bbox.min_x, min_y: bbox.min_y, max_x: bbox.max_x, max_y: bbox.max_y }
}

///|
fn bounding_box_to_msvg(bbox : BoundingBox) -> @msvg.BoundingBox {
  @msvg.BoundingBox::{
    min_x: bbox.min_x,
    min_y: bbox.min_y,
    max_x: bbox.max_x,
    max_y: bbox.max_y,
  }
}

///|
fn bounding_box_from_msvg_option(bbox : @msvg.BoundingBox?) -> BoundingBox? {
  match bbox {
    Some(b) => Some(bounding_box_from_msvg(b))
    None => None
  }
}

///|
fn clip_rect_from_msvg(clip : @msvg.ClipRect) -> ClipRect {
  { x: clip.x, y: clip.y, width: clip.width, height: clip.height }
}

///|
fn clip_rect_to_msvg(clip : ClipRect) -> @msvg.ClipRect {
  @msvg.ClipRect::{
    x: clip.x,
    y: clip.y,
    width: clip.width,
    height: clip.height,
  }
}

///|
fn camera_from_msvg(camera : @msvg.Camera) -> Camera {
  {
    x: camera.x,
    y: camera.y,
    zoom: camera.zoom,
    viewport_width: camera.viewport_width,
    viewport_height: camera.viewport_height,
  }
}

///|
fn copy_camera_from_msvg(target : Camera, source : @msvg.Camera) -> Unit {
  target.x = source.x
  target.y = source.y
  target.zoom = source.zoom
}

///|
fn camera_to_msvg(camera : Camera) -> @msvg.Camera {
  @msvg.Camera::{
    x: camera.x,
    y: camera.y,
    zoom: camera.zoom,
    viewport_width: camera.viewport_width,
    viewport_height: camera.viewport_height,
  }
}

///|
fn shape_from_msvg(shape : @msvg.Shape) -> Shape {
  match shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      Rect(x~, y~, width~, height~, rx~, ry~)
    Circle(cx~, cy~, r~) => Circle(cx~, cy~, r~)
    Ellipse(cx~, cy~, rx~, ry~) => Ellipse(cx~, cy~, rx~, ry~)
    Line(x1~, y1~, x2~, y2~) => Line(x1~, y1~, x2~, y2~)
    Polyline(points~) => Polyline(points~)
    Polygon(points~) => Polygon(points~)
    Path(commands~) => Path(commands=commands.map(path_command_from_msvg))
    Text(x~, y~, text~, font_size~) => Text(x~, y~, text~, font_size~)
    Image(..) => Group
    Group => Group
  }
}

///|
fn shape_to_msvg(shape : Shape) -> @msvg.Shape {
  match shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      @msvg.Shape::Rect(x~, y~, width~, height~, rx~, ry~)
    Circle(cx~, cy~, r~) => @msvg.Shape::Circle(cx~, cy~, r~)
    Ellipse(cx~, cy~, rx~, ry~) => @msvg.Shape::Ellipse(cx~, cy~, rx~, ry~)
    Line(x1~, y1~, x2~, y2~) => @msvg.Shape::Line(x1~, y1~, x2~, y2~)
    Polyline(points~) => @msvg.Shape::Polyline(points~)
    Polygon(points~) => @msvg.Shape::Polygon(points~)
    Path(commands~) =>
      @msvg.Shape::Path(commands=path_commands_to_msvg(commands))
    Text(x~, y~, text~, font_size~) =>
      @msvg.Shape::Text(x~, y~, text~, font_size~)
    Group => @msvg.Shape::Group
  }
}

///|
fn clip_path_from_msvg(clip : @msvg.ClipPath) -> ClipPath {
  {
    id: clip.id,
    shape: shape_from_msvg(clip.shape),
    transform: transform_from_msvg(clip.transform),
    clip_rule: fill_rule_from_msvg(clip.clip_rule),
  }
}

///|
fn clip_path_to_msvg(clip : ClipPath) -> @msvg.ClipPath {
  @msvg.ClipPath::{
    id: clip.id,
    shape: shape_to_msvg(clip.shape),
    transform: clip.transform.to_msvg(),
    clip_rule: fill_rule_to_msvg(clip.clip_rule),
    units: @msvg.ClipPathUnits::UserSpaceOnUse,
  }
}

///|
fn svg_node_to_msvg(source : SVGNode) -> @msvg.SVGNode {
  let node = @msvg.SVGNode::new(shape_to_msvg(source.shape))
  node.id = source.id
  node.transform = source.transform.to_msvg()
  node.fill = paint_to_msvg(source.fill)
  node.fill_rule = fill_rule_to_msvg(source.fill_rule)
  node.fill_opacity = source.fill_opacity
  node.stroke = stroke_style_to_msvg(source.stroke)
  node.stroke_opacity = source.stroke_opacity
  node.opacity = source.opacity
  node.z_index = source.z_index
  node.node_dirty = source.node_dirty
  node.prev_bounds = match source.prev_bounds {
    Some(bbox) => Some(bounding_box_to_msvg(bbox))
    None => None
  }
  node.filters = source.filters.map(filter_to_msvg)
  node.mask_id = source.mask_id
  node.clip_path_id = source.clip_path_id
  for child in source.children {
    node.children.push(svg_node_to_msvg(child))
  }
  node
}

///|
fn svg_node_from_msvg(source : @msvg.SVGNode) -> SVGNode {
  let current_color = color_from_msvg_option(source.color)
  let node = SVGNode::new(shape_from_msvg(source.shape))
  node.id = source.id
  node.transform = transform_from_msvg(source.transform)
  node.fill = paint_from_msvg(source.fill, current_color)
  node.fill_rule = fill_rule_from_msvg(source.fill_rule)
  node.fill_opacity = source.fill_opacity
  node.stroke = stroke_style_from_msvg(source.stroke, current_color)
  node.stroke_opacity = source.stroke_opacity
  node.opacity = source.opacity
  node.z_index = source.z_index
  node.node_dirty = source.node_dirty
  node.prev_bounds = bounding_box_from_msvg_option(source.prev_bounds)
  node.filters = source.filters.map(filter_from_msvg)
  node.mask_id = source.mask_id
  node.clip_path_id = source.clip_path_id
  for child in source.children {
    node.children.push(svg_node_from_msvg(child))
  }
  node
}

///|
fn pattern_from_msvg(
  pattern : @msvg.Pattern,
  content : Array[SVGNode],
) -> Pattern {
  {
    id: pattern.id,
    width: pattern.width,
    height: pattern.height,
    content,
    pattern_units: pattern_units_from_msvg(pattern.pattern_units),
    pattern_content_units: pattern_units_from_msvg(
      pattern.pattern_content_units,
    ),
    transform: transform_from_msvg(pattern.transform),
  }
}

///|
fn pattern_to_msvg(pattern : Pattern) -> @msvg.Pattern {
  @msvg.Pattern::{
    id: pattern.id,
    width: pattern.width,
    height: pattern.height,
    content: pattern.content.map(svg_node_to_msvg),
    pattern_units: pattern_units_to_msvg(pattern.pattern_units),
    pattern_content_units: pattern_units_to_msvg(pattern.pattern_content_units),
    transform: pattern.transform.to_msvg(),
    view_box: None,
    preserve_aspect_ratio: @msvg.PreserveAspectRatio::default(),
  }
}

///|
fn marker_orient_from_msvg(orient : @msvg.MarkerOrient) -> MarkerOrient {
  match orient {
    Auto => Auto
    AutoStartReverse => AutoStartReverse
    Angle(angle) => Angle(angle)
  }
}

///|
fn marker_orient_to_msvg(orient : MarkerOrient) -> @msvg.MarkerOrient {
  match orient {
    Auto => @msvg.MarkerOrient::Auto
    AutoStartReverse => @msvg.MarkerOrient::AutoStartReverse
    Angle(angle) => @msvg.MarkerOrient::Angle(angle)
  }
}

///|
fn marker_units_from_msvg(units : @msvg.MarkerUnits) -> MarkerUnits {
  match units {
    StrokeWidth => StrokeWidth
    UserSpaceOnUse_ => UserSpaceOnUse_
  }
}

///|
fn marker_units_to_msvg(units : MarkerUnits) -> @msvg.MarkerUnits {
  match units {
    StrokeWidth => @msvg.MarkerUnits::StrokeWidth
    UserSpaceOnUse_ => @msvg.MarkerUnits::UserSpaceOnUse_
  }
}

///|
fn marker_from_msvg(marker : @msvg.Marker) -> Marker {
  {
    id: marker.id,
    content: svg_node_from_msvg(marker.content),
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: marker_orient_from_msvg(marker.orient),
    marker_units: marker_units_from_msvg(marker.marker_units),
    view_box: view_box_from_msvg_option(marker.view_box),
  }
}

///|
fn marker_to_msvg(marker : Marker) -> @msvg.Marker {
  @msvg.Marker::{
    id: marker.id,
    content: svg_node_to_msvg(marker.content),
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: marker_orient_to_msvg(marker.orient),
    marker_units: marker_units_to_msvg(marker.marker_units),
    view_box: view_box_to_msvg_option(marker.view_box),
    preserve_aspect_ratio: @msvg.PreserveAspectRatio::default(),
    clip_overflow: true,
  }
}

///|
fn marked_line_from_msvg(line : @msvg.MarkedLine) -> MarkedLine {
  {
    points: line.points,
    marker_start: line.marker_start,
    marker_mid: line.marker_mid,
    marker_end: line.marker_end,
  }
}

///|
fn marked_line_to_msvg(line : MarkedLine) -> @msvg.MarkedLine {
  @msvg.MarkedLine::{
    points: line.points,
    marker_start: line.marker_start,
    marker_mid: line.marker_mid,
    marker_end: line.marker_end,
  }
}

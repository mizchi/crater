// ============================================================================
// Marker
// ============================================================================

///|
/// Marker definition (for line endpoints)
pub(all) struct Marker {
  id : String
  content : SVGNode
  ref_x : Double // Reference point x
  ref_y : Double // Reference point y
  marker_width : Double
  marker_height : Double
  orient : MarkerOrient
  marker_units : MarkerUnits
  view_box : ViewBox?
}

///|
pub(all) enum MarkerOrient {
  Auto // Orient along path direction
  AutoStartReverse // Reverse at start
  Angle(Double) // Fixed angle in degrees
}

///|
pub(all) enum MarkerUnits {
  StrokeWidth // Marker size relative to stroke width
  UserSpaceOnUse_ // Marker size in user space (renamed to avoid conflict)
}

///|
pub fn Marker::new(id : String, content : SVGNode) -> Marker {
  let marker = Marker::from_msvg(
    @msvg.Marker::new(id, content.to_msvg()),
  )
  {
    id: marker.id,
    content,
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: Auto,
    marker_units: marker.marker_units,
    view_box: marker.view_box,
  }
}

///|
pub fn Marker::arrow(id : String) -> Marker {
  Marker::from_msvg(@msvg.Marker::arrow(id))
}

///|
pub fn Marker::dot(id : String, radius : Double) -> Marker {
  Marker::from_msvg(@msvg.Marker::dot(id, radius))
}

///|
/// Get transform for marker at a point with given angle
pub fn Marker::get_transform(
  self : Marker,
  x : Double,
  y : Double,
  angle : Double,
  stroke_width : Double,
) -> Transform {
  Transform::from_msvg(
    self.to_msvg().get_transform(x, y, angle, stroke_width),
  )
}

///|
/// Marker registry
pub(all) struct MarkerRegistry {
  markers : Map[String, Marker]
}

///|
pub fn MarkerRegistry::new() -> MarkerRegistry {
  { markers: {} }
}

///|
pub fn MarkerRegistry::add(self : MarkerRegistry, marker : Marker) -> Unit {
  self.markers.set(marker.id, marker)
}

///|
pub fn MarkerRegistry::get(self : MarkerRegistry, id : String) -> Marker? {
  self.markers.get(id)
}

///|
/// Line with markers
pub(all) struct MarkedLine {
  points : Array[(Double, Double)]
  marker_start : String? // Marker ID
  marker_mid : String?
  marker_end : String?
}

///|
pub fn MarkedLine::new(points : Array[(Double, Double)]) -> MarkedLine {
  MarkedLine::from_msvg(@msvg.MarkedLine::new(points))
}

///|
pub fn MarkedLine::with_markers(
  points : Array[(Double, Double)],
  start : String?,
  mid : String?,
  end : String?,
) -> MarkedLine {
  MarkedLine::from_msvg(@msvg.MarkedLine::with_markers(points, start, mid, end))
}

///|
/// Get angle at a point on the line
pub fn MarkedLine::get_angle_at(self : MarkedLine, index : Int) -> Double {
  self.to_msvg().get_angle_at(index)
}

///|
fn MarkerOrient::from_msvg(orient : @msvg.MarkerOrient) -> MarkerOrient {
  match orient {
    Auto => Auto
    AutoStartReverse => AutoStartReverse
    Angle(angle) => Angle(angle)
  }
}

///|
fn MarkerOrient::to_msvg(self : MarkerOrient) -> @msvg.MarkerOrient {
  match self {
    Auto => @msvg.MarkerOrient::Auto
    AutoStartReverse => @msvg.MarkerOrient::AutoStartReverse
    Angle(angle) => @msvg.MarkerOrient::Angle(angle)
  }
}

///|
fn MarkerUnits::from_msvg(units : @msvg.MarkerUnits) -> MarkerUnits {
  match units {
    StrokeWidth => StrokeWidth
    UserSpaceOnUse_ => UserSpaceOnUse_
  }
}

///|
fn MarkerUnits::to_msvg(self : MarkerUnits) -> @msvg.MarkerUnits {
  match self {
    StrokeWidth => @msvg.MarkerUnits::StrokeWidth
    UserSpaceOnUse_ => @msvg.MarkerUnits::UserSpaceOnUse_
  }
}

///|
fn Marker::from_msvg(marker : @msvg.Marker) -> Marker {
  {
    id: marker.id,
    content: SVGNode::from_msvg(marker.content),
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: MarkerOrient::from_msvg(marker.orient),
    marker_units: MarkerUnits::from_msvg(marker.marker_units),
    view_box: ViewBox::from_msvg_option(marker.view_box),
  }
}

///|
fn Marker::to_msvg(self : Marker) -> @msvg.Marker {
  @msvg.Marker::{
    id: self.id,
    content: self.content.to_msvg(),
    ref_x: self.ref_x,
    ref_y: self.ref_y,
    marker_width: self.marker_width,
    marker_height: self.marker_height,
    orient: self.orient.to_msvg(),
    marker_units: self.marker_units.to_msvg(),
    view_box: ViewBox::to_msvg_option(self.view_box),
    preserve_aspect_ratio: @msvg.PreserveAspectRatio::default(),
    clip_overflow: true,
  }
}

///|
fn MarkedLine::from_msvg(line : @msvg.MarkedLine) -> MarkedLine {
  {
    points: line.points,
    marker_start: line.marker_start,
    marker_mid: line.marker_mid,
    marker_end: line.marker_end,
  }
}

///|
fn MarkedLine::to_msvg(self : MarkedLine) -> @msvg.MarkedLine {
  @msvg.MarkedLine::{
    points: self.points,
    marker_start: self.marker_start,
    marker_mid: self.marker_mid,
    marker_end: self.marker_end,
  }
}

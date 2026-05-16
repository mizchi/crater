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
  let marker = marker_from_msvg(
    @msvg.Marker::new(id, svg_node_to_msvg(content)),
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
  marker_from_msvg(@msvg.Marker::arrow(id))
}

///|
pub fn Marker::dot(id : String, radius : Double) -> Marker {
  marker_from_msvg(@msvg.Marker::dot(id, radius))
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
    marker_to_msvg(self).get_transform(x, y, angle, stroke_width),
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
  marked_line_from_msvg(@msvg.MarkedLine::new(points))
}

///|
pub fn MarkedLine::with_markers(
  points : Array[(Double, Double)],
  start : String?,
  mid : String?,
  end : String?,
) -> MarkedLine {
  marked_line_from_msvg(@msvg.MarkedLine::with_markers(points, start, mid, end))
}

///|
/// Get angle at a point on the line
pub fn MarkedLine::get_angle_at(self : MarkedLine, index : Int) -> Double {
  marked_line_to_msvg(self).get_angle_at(index)
}

///|
/// SVG DOM API
///
/// Provides SVG-specific DOM methods:
/// - getBBox() for bounding box retrieval
/// - Factory methods for SVG geometry objects

// =============================================================================
// getBBox Options
// =============================================================================

///|
/// Options for getBBox() method
/// Corresponds to SVGBoundingBoxOptions in the spec
pub struct GetBBoxOptions {
  fill : Bool // Include fill geometry (default true)
  stroke : Bool // Include stroke geometry (default false)
  markers : Bool // Include markers (default false)
  clipped : Bool // Apply clipping (default false)
} derive(Eq, Show)

///|
/// Default getBBox options (fill only)
pub fn GetBBoxOptions::default() -> GetBBoxOptions {
  { fill: true, stroke: false, markers: false, clipped: false }
}

///|
/// Create getBBox options with all geometry
pub fn GetBBoxOptions::all() -> GetBBoxOptions {
  { fill: true, stroke: true, markers: true, clipped: false }
}

// =============================================================================
// DomTree SVG Extensions
// =============================================================================

///|
/// Get the bounding box of an SVG element
/// Returns the tight bounding box in user space coordinates
pub fn DomTree::get_bbox(
  self : DomTree,
  node_id : NodeId,
  options? : GetBBoxOptions,
) -> SVGRect? {
  let _opts = options.unwrap_or(GetBBoxOptions::default())
  // Get cached rect from layout
  match self.get_cached_rect(node_id) {
    Some(rect) => Some(SVGRect::from_rect(rect))
    None => None
  }
}

///|
/// Get the Current Transformation Matrix (CTM)
/// Returns the transformation from user space to viewport
pub fn DomTree::get_ctm(self : DomTree, node_id : NodeId) -> SVGMatrix? {
  // For now, return identity matrix if node exists
  // Full implementation would traverse parent transforms
  match self.get_node_info(node_id) {
    Ok(_) => Some(SVGMatrix::identity())
    Err(_) => None
  }
}

///|
/// Get the Screen CTM
/// Returns the transformation from user space to screen pixels
pub fn DomTree::get_screen_ctm(self : DomTree, node_id : NodeId) -> SVGMatrix? {
  // For now, same as getCTM
  // Full implementation would include viewport transforms
  self.get_ctm(node_id)
}

// =============================================================================
// Factory Methods (SVGSVGElement equivalents)
// =============================================================================

///|
/// Create a new SVGRect object
/// Equivalent to SVGSVGElement.createSVGRect()
pub fn create_svg_rect() -> SVGRect {
  SVGRect::empty()
}

///|
/// Create a new SVGRect with values
pub fn create_svg_rect_with(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGRect {
  SVGRect::new(x, y, width, height)
}

///|
/// Create a new SVGPoint object
/// Equivalent to SVGSVGElement.createSVGPoint()
pub fn create_svg_point() -> SVGPoint {
  SVGPoint::origin()
}

///|
/// Create a new SVGPoint with values
pub fn create_svg_point_with(x : Double, y : Double) -> SVGPoint {
  SVGPoint::new(x, y)
}

///|
/// Create a new SVGMatrix object (identity matrix)
/// Equivalent to SVGSVGElement.createSVGMatrix()
pub fn create_svg_matrix() -> SVGMatrix {
  SVGMatrix::identity()
}

///|
/// Create a new SVGMatrix with values
pub fn create_svg_matrix_with(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> SVGMatrix {
  SVGMatrix::new(a, b, c, d, e, f)
}

// =============================================================================
// SVGNumber (simple wrapper for animated numbers)
// =============================================================================

///|
/// SVGNumber - represents an animated number value
pub struct SVGNumber {
  value : Double
} derive(Eq, Show)

///|
/// Create a new SVGNumber
pub fn SVGNumber::new(value : Double) -> SVGNumber {
  { value, }
}

///|
/// Create a zero SVGNumber
pub fn create_svg_number() -> SVGNumber {
  SVGNumber::new(0.0)
}

// =============================================================================
// SVGLength (length with unit)
// =============================================================================

///|
/// SVG Length unit types
pub enum SVGLengthType {
  Unknown
  Number // Unitless number
  Percentage
  Ems
  Exs
  Px
  Cm
  Mm
  In
  Pt
  Pc
} derive(Eq, Show)

///|
/// SVGLength - represents a length value with unit
pub struct SVGLength {
  unit_type : SVGLengthType
  value : Double // Value in user units
  value_in_specified_units : Double // Value in specified units
} derive(Eq, Show)

///|
/// Create a new SVGLength (unitless)
pub fn SVGLength::new(value : Double) -> SVGLength {
  { unit_type: Number, value, value_in_specified_units: value }
}

///|
/// Create a zero SVGLength
pub fn create_svg_length() -> SVGLength {
  SVGLength::new(0.0)
}

///|
/// Convert SVGLength to user units (pixels)
pub fn SVGLength::to_user_units(
  self : SVGLength,
  dpi? : Double,
  font_size? : Double,
) -> Double {
  let dpi_val = dpi.unwrap_or(96.0)
  let font_size_val = font_size.unwrap_or(16.0)
  match self.unit_type {
    Unknown | Number | Px => self.value_in_specified_units
    Percentage => self.value_in_specified_units / 100.0 // Needs context
    Ems => self.value_in_specified_units * font_size_val
    Exs => self.value_in_specified_units * font_size_val * 0.5 // Approximation
    Pt => self.value_in_specified_units * dpi_val / 72.0
    Pc => self.value_in_specified_units * dpi_val / 6.0
    In => self.value_in_specified_units * dpi_val
    Cm => self.value_in_specified_units * dpi_val / 2.54
    Mm => self.value_in_specified_units * dpi_val / 25.4
  }
}

// =============================================================================
// SVGAngle (angle with unit)
// =============================================================================

///|
/// SVG Angle unit types
pub enum SVGAngleType {
  Unknown
  Unspecified // Unitless (degrees)
  Deg
  Rad
  Grad
  Turn
} derive(Eq, Show)

///|
/// SVGAngle - represents an angle value with unit
pub struct SVGAngle {
  unit_type : SVGAngleType
  value : Double // Value in degrees
  value_in_specified_units : Double // Value in specified units
} derive(Eq, Show)

///|
/// Create a new SVGAngle (degrees)
pub fn SVGAngle::new(value : Double) -> SVGAngle {
  { unit_type: Deg, value, value_in_specified_units: value }
}

///|
/// Create a zero SVGAngle
pub fn create_svg_angle() -> SVGAngle {
  SVGAngle::new(0.0)
}

///|
/// Convert SVGAngle to radians
pub fn SVGAngle::to_radians(self : SVGAngle) -> Double {
  let pi = 3.14159265358979323846
  match self.unit_type {
    Unknown | Unspecified | Deg => self.value * pi / 180.0
    Rad => self.value_in_specified_units
    Grad => self.value_in_specified_units * pi / 200.0
    Turn => self.value_in_specified_units * 2.0 * pi
  }
}

///|
/// Convert SVGAngle to degrees
pub fn SVGAngle::to_degrees(self : SVGAngle) -> Double {
  let pi = 3.14159265358979323846
  match self.unit_type {
    Unknown | Unspecified | Deg => self.value_in_specified_units
    Rad => self.value_in_specified_units * 180.0 / pi
    Grad => self.value_in_specified_units * 0.9
    Turn => self.value_in_specified_units * 360.0
  }
}

// =============================================================================
// SVGTransform (single transform)
// =============================================================================

///|
/// SVG Transform types
pub enum SVGTransformType {
  Unknown
  Matrix
  Translate
  Scale
  Rotate
  SkewX
  SkewY
} derive(Eq, Show)

///|
/// SVGTransform - represents a single transformation
pub struct SVGTransform {
  transform_type : SVGTransformType
  matrix : SVGMatrix
  angle : Double // For rotate, skewX, skewY
} derive(Eq, Show)

///|
/// Create an SVGTransform from a matrix
pub fn SVGTransform::from_matrix(matrix : SVGMatrix) -> SVGTransform {
  { transform_type: Matrix, matrix, angle: 0.0 }
}

///|
/// Create a translate transform
pub fn SVGTransform::translate(tx : Double, ty : Double) -> SVGTransform {
  {
    transform_type: Translate,
    matrix: SVGMatrix::translate(tx, ty),
    angle: 0.0,
  }
}

///|
/// Create a scale transform
pub fn SVGTransform::scale(sx : Double, sy : Double) -> SVGTransform {
  { transform_type: Scale, matrix: SVGMatrix::scale(sx, sy), angle: 0.0 }
}

///|
/// Create a rotate transform (angle in degrees)
pub fn SVGTransform::rotate(
  angle : Double,
  cx? : Double,
  cy? : Double,
) -> SVGTransform {
  let cx_val = cx.unwrap_or(0.0)
  let cy_val = cy.unwrap_or(0.0)
  let rad = angle * 3.14159265358979323846 / 180.0
  // Rotate around (cx, cy): translate(-cx,-cy) * rotate * translate(cx,cy)
  let matrix = if cx_val == 0.0 && cy_val == 0.0 {
    SVGMatrix::rotate(rad)
  } else {
    SVGMatrix::translate(cx_val, cy_val)
    .multiply(SVGMatrix::rotate(rad))
    .multiply(SVGMatrix::translate(-cx_val, -cy_val))
  }
  { transform_type: Rotate, matrix, angle }
}

///|
/// Create a skewX transform (angle in degrees)
pub fn SVGTransform::skew_x(angle : Double) -> SVGTransform {
  let rad = angle * 3.14159265358979323846 / 180.0
  { transform_type: SkewX, matrix: SVGMatrix::skew_x(rad), angle }
}

///|
/// Create a skewY transform (angle in degrees)
pub fn SVGTransform::skew_y(angle : Double) -> SVGTransform {
  let rad = angle * 3.14159265358979323846 / 180.0
  { transform_type: SkewY, matrix: SVGMatrix::skew_y(rad), angle }
}

///|
/// Create a new SVGTransform
pub fn create_svg_transform() -> SVGTransform {
  SVGTransform::from_matrix(SVGMatrix::identity())
}

///|
/// Create a translation SVGTransform
pub fn create_svg_transform_translate(tx : Double, ty : Double) -> SVGTransform {
  SVGTransform::translate(tx, ty)
}

///|
/// Create a scale SVGTransform
pub fn create_svg_transform_scale(sx : Double, sy : Double) -> SVGTransform {
  SVGTransform::scale(sx, sy)
}

///|
/// Create a rotation SVGTransform
pub fn create_svg_transform_rotate(angle : Double) -> SVGTransform {
  SVGTransform::rotate(angle)
}

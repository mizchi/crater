///|
/// SVG Path Parser and Rasterizer
/// Full SVG 1.1 path command support

///|
/// Parse a path data string into an array of path commands
pub fn parse_path(data : String) -> Array[PathCommand] {
  @msvg.parse_path(data).map(PathCommand::from_msvg)
}

///|
/// Convert path commands to an array of polylines (for rendering)
/// Returns array of point arrays, each representing a subpath
pub fn path_to_polylines(
  commands : Array[PathCommand],
  flatness : Double,
) -> Array[Array[(Double, Double)]] {
  @msvg.path_to_polylines(commands.map(fn(c) { c.to_msvg() }), flatness)
}

///|
/// Rasterize path commands
pub fn raster_path(
  commands : Array[PathCommand],
  fill_color : Color?,
  stroke_color : Color?,
  flatness : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_path(
    commands.map(fn(c) { c.to_msvg() }),
    match fill_color {
      Some(color) => Some(color.to_msvg())
      None => None
    },
    match stroke_color {
      Some(color) => Some(color.to_msvg())
      None => None
    },
    flatness,
    pixel_setter_to_msvg(setter),
  )
}

///|
/// Compute bounding box of path commands
pub fn path_bbox(commands : Array[PathCommand]) -> BoundingBox {
  BoundingBox::from_msvg(@msvg.path_bbox(commands.map(fn(c) { c.to_msvg() })))
}

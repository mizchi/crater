///|
/// SVG Path Parser and Rasterizer
/// Full SVG 1.1 path command support

///|
/// Parse a path data string into an array of path commands
pub fn parse_path(data : String) -> Array[PathCommand] {
  @msvg.parse_path(data).map(path_command_from_msvg)
}

///|
/// Convert path commands to an array of polylines (for rendering)
/// Returns array of point arrays, each representing a subpath
pub fn path_to_polylines(
  commands : Array[PathCommand],
  flatness : Double,
) -> Array[Array[(Double, Double)]] {
  @msvg.path_to_polylines(path_commands_to_msvg(commands), flatness)
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
  let polylines = path_to_polylines(commands, flatness)
  // Fill
  match fill_color {
    Some(color) =>
      for polyline in polylines {
        let int_points = polyline.map(fn(p) { (p.0.to_int(), p.1.to_int()) })
        if int_points.length() >= 3 {
          raster_polygon_fill(int_points, color, setter)
        }
      }
    None => ()
  }
  // Stroke
  match stroke_color {
    Some(color) =>
      for polyline in polylines {
        let int_points = polyline.map(fn(p) { (p.0.to_int(), p.1.to_int()) })
        raster_polyline(int_points, color, setter)
      }
    None => ()
  }
}

///|
/// Compute bounding box of path commands
pub fn path_bbox(commands : Array[PathCommand]) -> BoundingBox {
  bounding_box_from_msvg(@msvg.path_bbox(path_commands_to_msvg(commands)))
}

///|
/// Public API helpers
/// Convenience functions for rendering to Image and bridging external trees.

///|
/// Render an SVGDocument into an Image.
pub fn render_svg_document_to_image(
  doc : SVGDocument,
  width : Int,
  height : Int,
) -> Image {
  let image = Image::new(width, height)
  let setter : PixelSetter = {
    set: (x, y, color) => image.set_pixel(x, y, color),
  }
  let ctx = RenderContext::new(setter, width, height)
  doc.render(ctx)
  image
}

///|
/// Render a Scene into an Image.
pub fn render_svg_scene_to_image(
  scene : Scene,
  width : Int,
  height : Int,
) -> Image {
  let image = Image::new(width, height)
  let setter : PixelSetter = {
    set: (x, y, color) => image.set_pixel(x, y, color),
  }
  let ctx = RenderContext::new(setter, width, height)
  scene.render(ctx)
  image
}

///|
/// Render a raw SVGNode tree into an Image.
pub fn render_svg_node_to_image(
  node : SVGNode,
  width : Int,
  height : Int,
) -> Image {
  let scene = Scene::new(node)
  render_svg_scene_to_image(scene, width, height)
}

///|
/// Parse and render an SVG markup string into an Image.
pub fn render_svg_to_image(
  svg_str : String,
  width : Int,
  height : Int,
) -> Image? {
  parse_svg_document(svg_str).map(fn(doc) {
    render_svg_document_to_image(doc, width, height)
  })
}

///|
/// Render PathCommand array directly to an Image (no SVG string parsing).
/// This is much faster than render_svg_to_image for programmatic paths
/// (e.g., font glyph outlines) because it skips SVG serialization and parsing.
///
/// `transform` is a 6-element affine transform [a, b, c, d, e, f] or empty for identity.
pub fn render_path_commands_to_image(
  commands : Array[PathCommand],
  width : Int,
  height : Int,
  fill_color : Color,
  transform? : Array[Double] = [],
) -> Image {
  let image = Image::new(width, height)
  if commands.is_empty() || width <= 0 || height <= 0 {
    return image
  }
  let flatness = 0.5
  let polylines = path_to_polylines(commands, flatness)
  let tf = if transform.length() >= 6 {
    Transform::matrix(
      transform[0],
      transform[1],
      transform[2],
      transform[3],
      transform[4],
      transform[5],
    )
  } else {
    Transform::identity()
  }
  let transformed_polylines : Array[Array[(Int, Int)]] = []
  for polyline in polylines {
    let transformed = polyline.map(fn(p) {
      let (x, y) = tf.apply(p.0, p.1)
      (x.to_int(), y.to_int())
    })
    if transformed.length() >= 3 {
      transformed_polylines.push(transformed)
    }
  }
  if transformed_polylines.length() > 0 {
    raster_polygons_fill_direct(transformed_polylines, fill_color, image)
  }
  image
}

///|
/// Optimized scanline fill that writes directly to Image pixels.
/// Avoids per-pixel callback overhead and reuses intersection buffer.
fn raster_polygons_fill_direct(
  polygons : Array[Array[(Int, Int)]],
  color : Color,
  image : Image,
) -> Unit {
  if polygons.length() == 0 {
    return
  }
  let w = image.width
  let h = image.height
  // Find bounding box
  let mut min_y = h
  let mut max_y = 0
  for poly in polygons {
    for pt in poly {
      let y = pt.1
      if y < min_y {
        min_y = y
      }
      if y > max_y {
        max_y = y
      }
    }
  }
  if min_y < 0 {
    min_y = 0
  }
  if max_y >= h {
    max_y = h - 1
  }
  if min_y > max_y {
    return
  }
  // Build edge table: collect all edges sorted by min_y
  let edges : Array[(Int, Int, Int, Int, Int)] = [] // (y_min, y_max, x1, x2, winding_sign)
  for poly in polygons {
    let n = poly.length()
    if n < 3 {
      continue
    }
    for i in 0..<n {
      let j = (i + 1) % n
      let (x1, y1) = poly[i]
      let (x2, y2) = poly[j]
      if y1 == y2 {
        continue // Skip horizontal edges
      }
      if y1 < y2 {
        edges.push((y1, y2, x1, x2, 1))
      } else {
        edges.push((y2, y1, x2, x1, -1))
      }
    }
  }
  if edges.is_empty() {
    return
  }
  // Sort edges by y_min for efficient activation
  edges.sort_by(fn(a, b) { a.0.compare(b.0) })
  // Reusable intersection buffer
  let intersections : Array[Int] = []
  let mut edge_start = 0
  // Scanline loop
  for y = min_y; y <= max_y; y = y + 1 {
    intersections.clear()
    // Skip edges that end before current scanline
    while edge_start < edges.length() && edges[edge_start].1 <= y {
      edge_start += 1
    }
    // Find intersections with active edges
    for ei = edge_start; ei < edges.length(); ei = ei + 1 {
      let (y_min, y_max, x1, x2, _winding) = edges[ei]
      if y_min > y {
        break
      }
      if y >= y_min && y < y_max {
        let x = x1 + (y - y_min) * (x2 - x1) / (y_max - y_min)
        intersections.push(x)
      }
    }
    if intersections.length() < 2 {
      continue
    }
    // Sort intersections
    for i = 1; i < intersections.length(); i = i + 1 {
      let key = intersections[i]
      let mut j = i - 1
      while j >= 0 && intersections[j] > key {
        intersections[j + 1] = intersections[j]
        j -= 1
      }
      intersections[j + 1] = key
    }
    // Fill between pairs — direct pixel array write
    let mut i = 0
    while i + 1 < intersections.length() {
      let mut x_start = intersections[i]
      let mut x_end = intersections[i + 1]
      if x_start < 0 {
        x_start = 0
      }
      if x_end >= w {
        x_end = w - 1
      }
      if x_start <= x_end && y >= 0 && y < h {
        let row_offset = y * w
        for x = x_start; x <= x_end; x = x + 1 {
          image.pixels[row_offset + x] = color
        }
      }
      i += 2
    }
  }
}

///|
/// SVG Scene Graph Management
/// Optimized for games and animations with dirty tracking and transform caching

///|
/// Scene represents a renderable SVG scene with optimization support
pub(all) struct Scene {
  root : SVGNode
  mut dirty : Bool
}

///|
/// Create a new scene from a root SVGNode
pub fn Scene::new(root : SVGNode) -> Scene {
  { root, dirty: true }
}

///|
/// Create an empty scene with a group root
pub fn Scene::empty() -> Scene {
  Scene::new(SVGNode::new(Group))
}

///|
/// Mark the scene as dirty (needs re-render)
pub fn Scene::mark_dirty(self : Scene) -> Unit {
  self.dirty = true
}

///|
/// Check if scene needs re-render
pub fn Scene::is_dirty(self : Scene) -> Bool {
  self.dirty
}

///|
/// Clear the dirty flag
pub fn Scene::clear_dirty(self : Scene) -> Unit {
  self.dirty = false
}

///|
/// Get the root node
pub fn Scene::get_root(self : Scene) -> SVGNode {
  self.root
}

///|
/// Update a node by ID (returns true if found and updated)
pub fn Scene::update_node(
  self : Scene,
  id : String,
  updater : (SVGNode) -> SVGNode,
) -> Bool {
  let found = update_node_recursive(self.root, id, updater)
  if found {
    self.mark_dirty()
  }
  found
}

///|
fn update_node_recursive(
  node : SVGNode,
  id : String,
  updater : (SVGNode) -> SVGNode,
) -> Bool {
  if node.id == id {
    let updated = updater(node)
    // Copy updated fields to node (mutation)
    node.shape = updated.shape
    node.transform = updated.transform
    node.fill = updated.fill
    node.fill_rule = updated.fill_rule
    node.fill_opacity = updated.fill_opacity
    node.stroke = updated.stroke
    node.stroke_opacity = updated.stroke_opacity
    node.opacity = updated.opacity
    return true
  }
  for child in node.children {
    if update_node_recursive(child, id, updater) {
      return true
    }
  }
  false
}

///|
/// Find a node by ID
pub fn Scene::find_node(self : Scene, id : String) -> SVGNode? {
  find_node_recursive(self.root, id)
}

///|
fn find_node_recursive(node : SVGNode, id : String) -> SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    match find_node_recursive(child, id) {
      Some(found) => return Some(found)
      None => continue
    }
  }
  None
}

///|
/// Add a child to a node by parent ID
pub fn Scene::add_child(
  self : Scene,
  parent_id : String,
  child : SVGNode,
) -> Bool {
  let found = add_child_recursive(self.root, parent_id, child)
  if found {
    self.mark_dirty()
  }
  found
}

///|
fn add_child_recursive(
  node : SVGNode,
  parent_id : String,
  child : SVGNode,
) -> Bool {
  if node.id == parent_id {
    node.children.push(child)
    return true
  }
  for c in node.children {
    if add_child_recursive(c, parent_id, child) {
      return true
    }
  }
  false
}

///|
/// Remove a node by ID
pub fn Scene::remove_node(self : Scene, id : String) -> Bool {
  let found = remove_node_recursive(self.root, id)
  if found {
    self.mark_dirty()
  }
  found
}

///|
fn remove_node_recursive(node : SVGNode, id : String) -> Bool {
  let mut found_idx : Int? = None
  for i, child in node.children {
    if child.id == id {
      found_idx = Some(i)
      break
    }
  }
  match found_idx {
    Some(idx) => {
      let _ = node.children.remove(idx)
      true
    }
    None => {
      for child in node.children {
        if remove_node_recursive(child, id) {
          return true
        }
      }
      false
    }
  }
}

///|
/// Compute the bounding box of the entire scene
pub fn Scene::get_bounds(self : Scene) -> BoundingBox {
  compute_bounds(self.root, Transform::identity())
}

///|
fn compute_bounds(node : SVGNode, parent_transform : Transform) -> BoundingBox {
  let transform = parent_transform.multiply(node.transform)
  let mut bbox = get_shape_bounds(node.shape)
  if not(bbox.is_empty()) {
    bbox = transform.apply_bbox(bbox)
  }
  for child in node.children {
    let child_bbox = compute_bounds(child, transform)
    bbox = bbox.union(child_bbox)
  }
  bbox
}

///|
fn get_shape_bounds(shape : Shape) -> BoundingBox {
  match shape {
    Rect(x~, y~, width~, height~, ..) =>
      BoundingBox::from_rect(x, y, width, height)
    Circle(cx~, cy~, r~) =>
      BoundingBox::from_rect(cx - r, cy - r, r * 2.0, r * 2.0)
    Ellipse(cx~, cy~, rx~, ry~) =>
      BoundingBox::from_rect(cx - rx, cy - ry, rx * 2.0, ry * 2.0)
    Line(x1~, y1~, x2~, y2~) => {
      let mut bbox = BoundingBox::empty()
      bbox = bbox.expand_by_point(x1, y1)
      bbox = bbox.expand_by_point(x2, y2)
      bbox
    }
    Polyline(points~) | Polygon(points~) => {
      let mut bbox = BoundingBox::empty()
      for p in points {
        bbox = bbox.expand_by_point(p.0, p.1)
      }
      bbox
    }
    Path(commands~) => path_bbox(commands)
    Group => BoundingBox::empty()
  }
}

///|
/// Render context for drawing
pub(all) struct RenderContext {
  setter : PixelSetter
  width : Int
  height : Int
  flatness : Double // For path flattening
  clip : ClipRect? // Optional clipping rectangle for culling
}

///|
/// Render the scene to a pixel setter
pub fn Scene::render(self : Scene, ctx : RenderContext) -> Unit {
  render_node(self.root, Transform::identity(), ctx)
  self.clear_dirty()
}

///|
/// Render the scene with a camera transform
pub fn Scene::render_with_camera(
  self : Scene,
  ctx : RenderContext,
  camera : Camera,
) -> Unit {
  let camera_transform = camera.get_transform()
  render_node(self.root, camera_transform, ctx)
  self.clear_dirty()
}

///|
/// Check if a bounding box is visible within the render context
fn is_visible(bbox : BoundingBox, ctx : RenderContext) -> Bool {
  match ctx.clip {
    Some(clip) => bbox.intersects(clip.to_bbox())
    None => {
      // Default: check against render context bounds
      let ctx_bbox = BoundingBox::from_rect(
        0.0,
        0.0,
        ctx.width.to_double(),
        ctx.height.to_double(),
      )
      bbox.intersects(ctx_bbox)
    }
  }
}

///|
fn render_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
) -> Unit {
  // Skip invisible nodes
  if node.opacity <= 0.0 {
    return
  }
  let transform = parent_transform.multiply(node.transform)
  // Early culling: check if node's bounding box is visible
  let shape_bbox = get_shape_bounds(node.shape)
  if not(shape_bbox.is_empty()) {
    let transformed_bbox = transform.apply_bbox(shape_bbox)
    if not(is_visible(transformed_bbox, ctx)) {
      // Node is outside visible area, but still need to check children
      // (they might have different transforms that make them visible)
      for child in node.children {
        render_node(child, transform, ctx)
      }
      return
    }
  }
  // Render shape
  match node.shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      render_rect(x, y, width, height, rx, ry, node, transform, ctx)
    Circle(cx~, cy~, r~) => render_circle(cx, cy, r, node, transform, ctx)
    Ellipse(cx~, cy~, rx~, ry~) =>
      render_ellipse(cx, cy, rx, ry, node, transform, ctx)
    Line(x1~, y1~, x2~, y2~) =>
      render_line(x1, y1, x2, y2, node, transform, ctx)
    Polyline(points~) => render_polyline(points, node, transform, ctx)
    Polygon(points~) => render_polygon(points, node, transform, ctx)
    Path(commands~) => render_path(commands, node, transform, ctx)
    Group => ()
  }
  // Render children
  for child in node.children {
    render_node(child, transform, ctx)
  }
}

///|
fn render_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  // Transform corners
  let (x0, y0) = transform.apply(x, y)
  let (x1, y1) = transform.apply(x + width, y + height)
  let ix = x0.to_int()
  let iy = y0.to_int()
  let iw = (x1 - x0).to_int()
  let ih = (y1 - y0).to_int()
  let irx = rx.to_int()
  let iry = ry.to_int()
  // Fill
  match node.fill {
    SolidColor(color) =>
      if node.fill_opacity > 0.0 {
        let fill_color = apply_opacity(color, node.fill_opacity * node.opacity)
        if irx > 0 || iry > 0 {
          // Rounded rect fill approximated as regular rect (simplified)
          raster_rect_fill(ix, iy, iw, ih, fill_color, ctx.setter)
        } else {
          raster_rect_fill(ix, iy, iw, ih, fill_color, ctx.setter)
        }
      }
    None => ()
  }
  // Stroke
  match node.stroke.paint {
    SolidColor(color) =>
      if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
        let stroke_color = apply_opacity(
          color,
          node.stroke_opacity * node.opacity,
        )
        if irx > 0 || iry > 0 {
          raster_rounded_rect_stroke(
            ix,
            iy,
            iw,
            ih,
            irx,
            iry,
            stroke_color,
            ctx.setter,
          )
        } else {
          raster_rect_stroke(ix, iy, iw, ih, stroke_color, ctx.setter)
        }
      }
    None => ()
  }
}

///|
fn render_circle(
  cx : Double,
  cy : Double,
  r : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let (tx, ty) = transform.apply(cx, cy)
  let (sx, sy) = transform.get_scale()
  let tr = (r * (sx + sy) / 2.0).to_int()
  let icx = tx.to_int()
  let icy = ty.to_int()
  // Fill
  match node.fill {
    SolidColor(color) =>
      if node.fill_opacity > 0.0 {
        let fill_color = apply_opacity(color, node.fill_opacity * node.opacity)
        raster_circle_fill(icx, icy, tr, fill_color, ctx.setter)
      }
    None => ()
  }
  // Stroke
  match node.stroke.paint {
    SolidColor(color) =>
      if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
        let stroke_color = apply_opacity(
          color,
          node.stroke_opacity * node.opacity,
        )
        raster_circle_stroke(icx, icy, tr, stroke_color, ctx.setter)
      }
    None => ()
  }
}

///|
fn render_ellipse(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let (tx, ty) = transform.apply(cx, cy)
  let (sx, sy) = transform.get_scale()
  let trx = (rx * sx).to_int()
  let try_ = (ry * sy).to_int()
  let icx = tx.to_int()
  let icy = ty.to_int()
  // Fill
  match node.fill {
    SolidColor(color) =>
      if node.fill_opacity > 0.0 {
        let fill_color = apply_opacity(color, node.fill_opacity * node.opacity)
        raster_ellipse_fill(icx, icy, trx, try_, fill_color, ctx.setter)
      }
    None => ()
  }
  // Stroke
  match node.stroke.paint {
    SolidColor(color) =>
      if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
        let stroke_color = apply_opacity(
          color,
          node.stroke_opacity * node.opacity,
        )
        raster_ellipse_stroke(icx, icy, trx, try_, stroke_color, ctx.setter)
      }
    None => ()
  }
}

///|
fn render_line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let (tx1, ty1) = transform.apply(x1, y1)
  let (tx2, ty2) = transform.apply(x2, y2)
  match node.stroke.paint {
    SolidColor(color) =>
      if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
        let stroke_color = apply_opacity(
          color,
          node.stroke_opacity * node.opacity,
        )
        if node.stroke.width <= 1.0 {
          raster_line(
            tx1.to_int(),
            ty1.to_int(),
            tx2.to_int(),
            ty2.to_int(),
            stroke_color,
            ctx.setter,
          )
        } else {
          raster_thick_line(
            tx1.to_int(),
            ty1.to_int(),
            tx2.to_int(),
            ty2.to_int(),
            node.stroke.width.to_int(),
            stroke_color,
            ctx.setter,
          )
        }
      }
    None => ()
  }
}

///|
fn render_polyline(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let transformed = points.map(fn(p) {
    let (x, y) = transform.apply(p.0, p.1)
    (x.to_int(), y.to_int())
  })
  match node.stroke.paint {
    SolidColor(color) =>
      if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
        let stroke_color = apply_opacity(
          color,
          node.stroke_opacity * node.opacity,
        )
        raster_polyline(transformed, stroke_color, ctx.setter)
      }
    None => ()
  }
}

///|
fn render_polygon(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let transformed = points.map(fn(p) {
    let (x, y) = transform.apply(p.0, p.1)
    (x.to_int(), y.to_int())
  })
  // Fill
  match node.fill {
    SolidColor(color) =>
      if node.fill_opacity > 0.0 {
        let fill_color = apply_opacity(color, node.fill_opacity * node.opacity)
        raster_polygon_fill(transformed, fill_color, ctx.setter)
      }
    None => ()
  }
  // Stroke
  match node.stroke.paint {
    SolidColor(color) =>
      if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
        let stroke_color = apply_opacity(
          color,
          node.stroke_opacity * node.opacity,
        )
        raster_polygon_stroke(transformed, stroke_color, ctx.setter)
      }
    None => ()
  }
}

///|
fn render_path(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  // Convert to polylines with transform
  let polylines = path_to_polylines(commands, ctx.flatness)
  for polyline in polylines {
    let transformed = polyline.map(fn(p) {
      let (x, y) = transform.apply(p.0, p.1)
      (x.to_int(), y.to_int())
    })
    // Fill
    match node.fill {
      SolidColor(color) =>
        if node.fill_opacity > 0.0 && transformed.length() >= 3 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_polygon_fill(transformed, fill_color, ctx.setter)
        }
      None => ()
    }
    // Stroke
    match node.stroke.paint {
      SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_polyline(transformed, stroke_color, ctx.setter)
        }
      None => ()
    }
  }
}

///|
/// Apply opacity to a color
fn apply_opacity(color : Color, opacity : Double) -> Color {
  if opacity >= 1.0 {
    color
  } else if opacity <= 0.0 {
    Color::transparent()
  } else {
    {
      r: color.r,
      g: color.g,
      b: color.b,
      a: (color.a.to_double() * opacity).to_int(),
    }
  }
}

///|
/// Helper: Create a rectangle node
pub fn rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGNode {
  let node = SVGNode::new(Rect(x~, y~, width~, height~, rx=0.0, ry=0.0))
  node.id = id
  node
}

///|
/// Helper: Create a circle node
pub fn circle(id : String, cx : Double, cy : Double, r : Double) -> SVGNode {
  let node = SVGNode::new(Circle(cx~, cy~, r~))
  node.id = id
  node
}

///|
/// Helper: Create a line node
pub fn line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> SVGNode {
  let node = SVGNode::new(Line(x1~, y1~, x2~, y2~))
  node.id = id
  node.fill = None // Lines have no fill by default
  node
}

///|
/// Helper: Create a path node from path data string
pub fn path(id : String, d : String) -> SVGNode {
  let commands = parse_path(d)
  let node = SVGNode::new(Path(commands~))
  node.id = id
  node
}

///|
/// Helper: Create a group node
pub fn group(id : String, children : Array[SVGNode]) -> SVGNode {
  let node = SVGNode::new(Group)
  node.id = id
  for child in children {
    node.children.push(child)
  }
  node
}

///|
/// Create a RenderContext with default settings
pub fn RenderContext::new(
  setter : PixelSetter,
  width : Int,
  height : Int,
) -> RenderContext {
  { setter, width, height, flatness: 0.5, clip: None }
}

///|
/// Create a RenderContext with clipping
pub fn RenderContext::with_clip(
  setter : PixelSetter,
  width : Int,
  height : Int,
  clip : ClipRect,
) -> RenderContext {
  { setter, width, height, flatness: 0.5, clip: Some(clip) }
}

///|
/// Create a RenderContext for a camera
pub fn RenderContext::for_camera(
  setter : PixelSetter,
  camera : Camera,
) -> RenderContext {
  let clip = ClipRect::from_size(camera.viewport_width, camera.viewport_height)
  {
    setter,
    width: camera.viewport_width,
    height: camera.viewport_height,
    flatness: 0.5,
    clip: Some(clip),
  }
}

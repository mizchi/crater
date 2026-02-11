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
/// Animation manager for coordinating multiple tweens
pub(all) struct AnimationManager {
  tweens : Array[Tween]
}

///|
pub fn AnimationManager::new() -> AnimationManager {
  { tweens: [] }
}

///|
/// Add a new tween animation
pub fn AnimationManager::add(self : AnimationManager, tween : Tween) -> Unit {
  self.tweens.push(tween)
}

///|
/// Create and add a simple translate animation
pub fn AnimationManager::animate_translate(
  self : AnimationManager,
  target_id : String,
  x : Double,
  y : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  self.add(Tween::new(target_id, Translate(x, y), duration, easing))
}

///|
/// Create and add a simple opacity animation
pub fn AnimationManager::animate_opacity(
  self : AnimationManager,
  target_id : String,
  opacity : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  self.add(Tween::new(target_id, Opacity(opacity), duration, easing))
}

///|
/// Create and add a simple scale animation
pub fn AnimationManager::animate_scale(
  self : AnimationManager,
  target_id : String,
  scale : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  self.add(Tween::new(target_id, ScaleUniform(scale), duration, easing))
}

///|
/// Update all animations with delta time
/// Returns true if any animations are still running
pub fn AnimationManager::update(
  self : AnimationManager,
  dt : Double,
  scene : Scene,
) -> Bool {
  let mut any_running = false
  // Update each tween
  for tween in self.tweens {
    if not(tween.is_complete()) {
      match scene.find_node(tween.target_id) {
        Some(node) => if tween.update(dt, node) { any_running = true }
        None => () // Node not found, skip
      }
    }
  }
  // Mark scene dirty if any animations ran
  if any_running {
    scene.mark_dirty()
  }
  any_running
}

///|
/// Remove completed animations
pub fn AnimationManager::cleanup(self : AnimationManager) -> Unit {
  // Remove completed tweens (iterate backwards to avoid index issues)
  let mut i = self.tweens.length() - 1
  while i >= 0 {
    if self.tweens[i].is_complete() {
      let _ = self.tweens.remove(i)
    }
    i = i - 1
  }
}

///|
/// Check if any animations are running
pub fn AnimationManager::is_animating(self : AnimationManager) -> Bool {
  for tween in self.tweens {
    if not(tween.is_complete()) {
      return true
    }
  }
  false
}

///|
/// Clear all animations
pub fn AnimationManager::clear(self : AnimationManager) -> Unit {
  self.tweens.clear()
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
/// Compute the dirty region (union of all dirty node bounds)
pub fn Scene::get_dirty_region(self : Scene) -> BoundingBox {
  compute_dirty_region(self.root, Transform::identity())
}

///|
fn compute_dirty_region(
  node : SVGNode,
  parent_transform : Transform,
) -> BoundingBox {
  let transform = parent_transform.multiply(node.transform)
  let mut dirty_bbox = BoundingBox::empty()
  // If this node is dirty, include its current and previous bounds
  if node.node_dirty {
    let current_bbox = get_shape_bounds(node.shape)
    if not(current_bbox.is_empty()) {
      let transformed_bbox = transform.apply_bbox(current_bbox)
      dirty_bbox = dirty_bbox.union(transformed_bbox)
    }
    // Include previous bounds if available
    match node.prev_bounds {
      Some(prev) => dirty_bbox = dirty_bbox.union(prev)
      None => ()
    }
  }
  // Recurse to children
  for child in node.children {
    let child_dirty = compute_dirty_region(child, transform)
    dirty_bbox = dirty_bbox.union(child_dirty)
  }
  dirty_bbox
}

///|
/// Render only nodes that intersect with the dirty region
pub fn Scene::render_dirty(self : Scene, ctx : RenderContext) -> BoundingBox {
  let dirty_region = self.get_dirty_region()
  if dirty_region.is_empty() {
    // Nothing dirty
    return dirty_region
  }
  // Create a clipped render context
  let clip = ClipRect::new(
    dirty_region.min_x.to_int(),
    dirty_region.min_y.to_int(),
    (dirty_region.max_x - dirty_region.min_x).to_int(),
    (dirty_region.max_y - dirty_region.min_y).to_int(),
  )
  let clipped_ctx = RenderContext::with_clip(
    ctx.setter,
    ctx.width,
    ctx.height,
    clip,
  )
  // Render nodes, update bounds, and clear dirty flags
  render_and_update_dirty(self.root, Transform::identity(), clipped_ctx)
  self.clear_dirty()
  dirty_region
}

///|
fn render_and_update_dirty(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let transform = parent_transform.multiply(node.transform)
  // Update previous bounds and clear dirty
  let current_bbox = get_shape_bounds(node.shape)
  if not(current_bbox.is_empty()) {
    node.prev_bounds = Some(transform.apply_bbox(current_bbox))
  }
  node.node_dirty = false
  // Render the node (existing render_node logic will handle clipping)
  render_node(node, parent_transform, ctx)
  // Note: render_node already recurses into children
}

///|
/// Mark a node and its ancestors as dirty
pub fn Scene::mark_node_dirty(self : Scene, id : String) -> Bool {
  match self.find_node(id) {
    Some(node) => {
      node.mark_dirty()
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
/// Clear all dirty flags in the scene
pub fn Scene::clear_all_dirty(self : Scene) -> Unit {
  clear_dirty_recursive(self.root)
  self.clear_dirty()
}

///|
fn clear_dirty_recursive(node : SVGNode) -> Unit {
  node.node_dirty = false
  for child in node.children {
    clear_dirty_recursive(child)
  }
}

///|
/// Set z_index of a node by ID
pub fn Scene::set_z_index(self : Scene, id : String, z_index : Int) -> Bool {
  match self.find_node(id) {
    Some(node) => {
      node.z_index = z_index
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
/// Bring a node to front (set z_index higher than all siblings)
pub fn Scene::bring_to_front(self : Scene, id : String) -> Bool {
  match find_parent_and_node(self.root, id) {
    Some((parent, node)) => {
      let max_z = get_max_z_index(parent.children)
      node.z_index = max_z + 1
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
/// Send a node to back (set z_index lower than all siblings)
pub fn Scene::send_to_back(self : Scene, id : String) -> Bool {
  match find_parent_and_node(self.root, id) {
    Some((parent, node)) => {
      let min_z = get_min_z_index(parent.children)
      node.z_index = min_z - 1
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
fn find_parent_and_node(node : SVGNode, id : String) -> (SVGNode, SVGNode)? {
  for child in node.children {
    if child.id == id {
      return Some((node, child))
    }
    match find_parent_and_node(child, id) {
      Some(result) => return Some(result)
      None => continue
    }
  }
  None
}

///|
fn get_max_z_index(nodes : Array[SVGNode]) -> Int {
  if nodes.is_empty() {
    return 0
  }
  let mut max_z = nodes[0].z_index
  for i = 1; i < nodes.length(); i = i + 1 {
    if nodes[i].z_index > max_z {
      max_z = nodes[i].z_index
    }
  }
  max_z
}

///|
fn get_min_z_index(nodes : Array[SVGNode]) -> Int {
  if nodes.is_empty() {
    return 0
  }
  let mut min_z = nodes[0].z_index
  for i = 1; i < nodes.length(); i = i + 1 {
    if nodes[i].z_index < min_z {
      min_z = nodes[i].z_index
    }
  }
  min_z
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
    Text(x~, y~, text~, font_size~) => {
      // Approximate text bounds using character count
      // Each character is approximately 0.6 * font_size wide
      let char_width = font_size * 0.6
      let width = char_width * text.length().to_double()
      let height = font_size
      // y is baseline, so text extends upward
      BoundingBox::from_rect(x, y - height, width, height)
    }
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
/// Render the scene with viewBox coordinate mapping
pub fn Scene::render_with_viewbox(
  self : Scene,
  ctx : RenderContext,
  viewbox : ViewBox,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Unit {
  let viewbox_transform = viewbox.get_transform(
    ctx.width.to_double(),
    ctx.height.to_double(),
    preserve_aspect_ratio,
  )
  render_node(self.root, viewbox_transform, ctx)
  self.clear_dirty()
}

///|
/// Render the scene with both viewBox and camera
pub fn Scene::render_with_viewbox_and_camera(
  self : Scene,
  ctx : RenderContext,
  viewbox : ViewBox,
  preserve_aspect_ratio : PreserveAspectRatio,
  camera : Camera,
) -> Unit {
  let viewbox_transform = viewbox.get_transform(
    ctx.width.to_double(),
    ctx.height.to_double(),
    preserve_aspect_ratio,
  )
  let camera_transform = camera.get_transform()
  // Apply viewBox first, then camera
  let combined = viewbox_transform.multiply(camera_transform)
  render_node(self.root, combined, ctx)
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
    Text(x~, y~, text~, font_size~) =>
      render_text(x, y, text, font_size, node, transform, ctx)
    Group => ()
  }
  // Render children sorted by z_index (lower z_index first = back to front)
  let sorted_children = sort_by_z_index(node.children)
  for child in sorted_children {
    render_node(child, transform, ctx)
  }
}

///|
/// Sort nodes by z_index (ascending order: lower z_index drawn first)
fn sort_by_z_index(nodes : Array[SVGNode]) -> Array[SVGNode] {
  if nodes.length() <= 1 {
    return nodes
  }
  // Simple insertion sort (good for small arrays, stable)
  let result = nodes.copy()
  for i = 1; i < result.length(); i = i + 1 {
    let current = result[i]
    let mut j = i - 1
    while j >= 0 && result[j].z_index > current.z_index {
      result[j + 1] = result[j]
      j = j - 1
    }
    result[j + 1] = current
  }
  result
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
    LinearGrad(grad) =>
      if node.fill_opacity > 0.0 {
        raster_rect_gradient(
          ix,
          iy,
          iw,
          ih,
          grad,
          node.fill_opacity * node.opacity,
          ctx.setter,
        )
      }
    RadialGrad(grad) =>
      if node.fill_opacity > 0.0 {
        raster_rect_radial_gradient(
          ix,
          iy,
          iw,
          ih,
          grad,
          node.fill_opacity * node.opacity,
          ctx.setter,
        )
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
    LinearGrad(_) => () // TODO: gradient stroke not yet supported
    RadialGrad(_) => () // TODO: gradient stroke not yet supported
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
    LinearGrad(_) => () // TODO: gradient fill for circles not yet supported
    RadialGrad(grad) =>
      if node.fill_opacity > 0.0 {
        raster_circle_radial_gradient(
          icx,
          icy,
          tr,
          grad,
          node.fill_opacity * node.opacity,
          ctx.setter,
        )
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
    LinearGrad(_) => () // TODO: gradient stroke not yet supported
    RadialGrad(_) => () // TODO: gradient stroke not yet supported
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
    LinearGrad(_) => () // TODO: gradient fill for ellipses not yet supported
    RadialGrad(grad) =>
      if node.fill_opacity > 0.0 {
        raster_ellipse_radial_gradient(
          icx,
          icy,
          trx,
          try_,
          grad,
          node.fill_opacity * node.opacity,
          ctx.setter,
        )
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
    LinearGrad(_) => () // TODO: gradient stroke not yet supported
    RadialGrad(_) => () // TODO: gradient stroke not yet supported
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
        // Check for dash pattern
        match node.stroke.dasharray {
          Some(dasharray) =>
            raster_line_dashed(
              tx1.to_int(),
              ty1.to_int(),
              tx2.to_int(),
              ty2.to_int(),
              stroke_color,
              dasharray,
              node.stroke.dashoffset,
              ctx.setter,
            )
          None =>
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
      }
    LinearGrad(_) => () // TODO: gradient stroke not yet supported
    RadialGrad(_) => () // TODO: gradient stroke not yet supported
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
        match node.stroke.dasharray {
          Some(dasharray) =>
            raster_polyline_dashed(
              transformed,
              stroke_color,
              dasharray,
              node.stroke.dashoffset,
              ctx.setter,
            )
          None => raster_polyline(transformed, stroke_color, ctx.setter)
        }
      }
    LinearGrad(_) => () // TODO: gradient stroke not yet supported
    RadialGrad(_) => () // TODO: gradient stroke not yet supported
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
    LinearGrad(_) => () // TODO: gradient fill for polygons not yet supported
    RadialGrad(_) => () // TODO: gradient fill for polygons not yet supported
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
    LinearGrad(_) => () // TODO: gradient stroke not yet supported
    RadialGrad(_) => () // TODO: gradient stroke not yet supported
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
      LinearGrad(_) => () // TODO: gradient fill for paths not yet supported
      RadialGrad(_) => () // TODO: gradient fill for paths not yet supported
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
      LinearGrad(_) => () // TODO: gradient stroke not yet supported
      RadialGrad(_) => () // TODO: gradient stroke not yet supported
      None => ()
    }
  }
}

///|
fn render_text(
  x : Double,
  y : Double,
  text : String,
  font_size : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
) -> Unit {
  let (tx, ty) = transform.apply(x, y)
  let (sx, _) = transform.get_scale()
  let scaled_size = (font_size * sx).to_int()
  // Fill color for text
  match node.fill {
    SolidColor(color) =>
      if node.fill_opacity > 0.0 {
        let fill_color = apply_opacity(color, node.fill_opacity * node.opacity)
        raster_text(
          tx.to_int(),
          ty.to_int(),
          text,
          scaled_size,
          fill_color,
          ctx.setter,
        )
      }
    LinearGrad(_) => () // TODO: gradient fill for text not yet supported
    RadialGrad(_) => () // TODO: gradient fill for text not yet supported
    None => ()
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
/// Helper: Create a text node
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
  font_size : Double,
) -> SVGNode {
  let node = SVGNode::new(Text(x~, y~, text=content, font_size~))
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

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
  Group |> SVGNode::new |> Scene::new
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
    node.view_box = updated.view_box
    node.preserve_aspect_ratio = updated.preserve_aspect_ratio
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
    if node.prev_bounds is Some(prev) {
      dirty_bbox = dirty_bbox.union(prev)
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
  let resources = RenderResources::empty()
  let base_transform = match self.root.view_box {
    Some(vb) =>
      vb.get_transform(
        ctx.width.to_double(),
        ctx.height.to_double(),
        self.root.preserve_aspect_ratio,
      )
    None => Transform::identity()
  }
  // Render nodes, update bounds, and clear dirty flags
  render_and_update_dirty(self.root, base_transform, clipped_ctx, resources)
  self.clear_dirty()
  dirty_region
}

///|
fn render_and_update_dirty(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
) -> Unit {
  let transform = parent_transform.multiply(node.transform)
  // Update previous bounds and clear dirty
  let current_bbox = get_shape_bounds(node.shape)
  if not(current_bbox.is_empty()) {
    node.prev_bounds = Some(transform.apply_bbox(current_bbox))
  }
  node.node_dirty = false
  // Render the node (existing render_node logic will handle clipping)
  render_node(node, parent_transform, ctx, resources, true, Color::black())
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
  for i in 1..<nodes.length() {
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
  for i in 1..<nodes.length() {
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
/// Compute bounds without applying the node's own transform
fn compute_bounds_without_self_transform(
  node : SVGNode,
  parent_transform : Transform,
) -> BoundingBox {
  let transform = parent_transform
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
      if width <= 0.0 || height <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(x, y, width, height)
      }
    Circle(cx~, cy~, r~) =>
      if r <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(cx - r, cy - r, r * 2.0, r * 2.0)
      }
    Ellipse(cx~, cy~, rx~, ry~) =>
      if rx <= 0.0 || ry <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(cx - rx, cy - ry, rx * 2.0, ry * 2.0)
      }
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
    Image(x~, y~, width~, height~, ..) =>
      if width <= 0.0 || height <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(x, y, width, height)
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
  /// Font callback: (codepoint, font_size) -> (path_commands, advance_width)
  text_to_paths : ((Int, Double) -> (Array[PathCommand], Double))?
}

///|
priv struct RenderResources {
  clips : ClipPathRegistry
  masks : MaskRegistry
  patterns : PatternRegistry
  gradients : GradientRegistry
  markers : MarkerRegistry
}

///|
fn RenderResources::empty() -> RenderResources {
  {
    clips: ClipPathRegistry::new(),
    masks: MaskRegistry::new(),
    patterns: PatternRegistry::new(),
    gradients: GradientRegistry::new(),
    markers: MarkerRegistry::new(),
  }
}

///|
/// Render a parsed SVG document with registered resources
pub fn SVGDocument::render(self : SVGDocument, ctx : RenderContext) -> Unit {
  let resources = {
    clips: self.clips,
    masks: self.masks,
    patterns: self.patterns,
    gradients: self.gradients,
    markers: self.markers,
  }
  match self.root.view_box {
    Some(vb) => {
      let viewbox_transform = vb.get_transform(
        ctx.width.to_double(),
        ctx.height.to_double(),
        self.root.preserve_aspect_ratio,
      )
      render_node(
        self.root,
        viewbox_transform,
        ctx,
        resources,
        true,
        Color::black(),
      )
    }
    None =>
      render_node(
        self.root,
        Transform::identity(),
        ctx,
        resources,
        true,
        Color::black(),
      )
  }
}

///|
/// Render the scene to a pixel setter
pub fn Scene::render(self : Scene, ctx : RenderContext) -> Unit {
  let resources = RenderResources::empty()
  let base_transform = match self.root.view_box {
    Some(vb) =>
      vb.get_transform(
        ctx.width.to_double(),
        ctx.height.to_double(),
        self.root.preserve_aspect_ratio,
      )
    None => Transform::identity()
  }
  render_node(self.root, base_transform, ctx, resources, true, Color::black())
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
  let resources = RenderResources::empty()
  render_node(self.root, camera_transform, ctx, resources, true, Color::black())
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
  let resources = RenderResources::empty()
  render_node(
    self.root,
    viewbox_transform,
    ctx,
    resources,
    true,
    Color::black(),
  )
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
  let resources = RenderResources::empty()
  render_node(self.root, combined, ctx, resources, true, Color::black())
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
fn intersect_clip(a : ClipRect, b : ClipRect) -> ClipRect? {
  let x0 = if a.x > b.x { a.x } else { b.x }
  let y0 = if a.y > b.y { a.y } else { b.y }
  let x1 = if a.x + a.width < b.x + b.width {
    a.x + a.width
  } else {
    b.x + b.width
  }
  let y1 = if a.y + a.height < b.y + b.height {
    a.y + a.height
  } else {
    b.y + b.height
  }
  let w = x1 - x0
  let h = y1 - y0
  if w <= 0 || h <= 0 {
    None
  } else {
    Some(ClipRect::new(x0, y0, w, h))
  }
}

///|
fn render_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  allow_mask : Bool,
  parent_color : Color,
) -> Unit {
  // Skip invisible nodes
  if node.opacity <= 0.0 {
    return
  }
  let node_color = match node.color {
    Some(c) => c
    None => parent_color
  }
  let base_transform = parent_transform.multiply(node.transform)
  let transform = match
    (node.view_box, node.viewport_width, node.viewport_height) {
    (Some(vb), Some(w), Some(h)) =>
      base_transform.multiply(
        vb.get_transform(w, h, node.preserve_aspect_ratio),
      )
    _ => base_transform
  }
  // Apply clip path if present
  let ctx_for_node = match node.clip_path_id {
    Some(id) =>
      match resources.clips.get(id) {
        Some(clip) => {
          let bbox_local = match clip.units {
            ClipPathUnits::ObjectBoundingBox =>
              compute_bounds_without_self_transform(node, Transform::identity())
            ClipPathUnits::UserSpaceOnUse => BoundingBox::empty()
          }
          apply_clip_path(ctx, clip, transform, bbox_local)
        }
        None => ctx
      }
    None => ctx
  }
  let ctx_for_node = match
    (node.clip_overflow, node.viewport_width, node.viewport_height) {
    (true, Some(vw), Some(vh)) => {
      let viewport_bbox = BoundingBox::from_rect(0.0, 0.0, vw, vh)
      let world_bbox = base_transform.apply_bbox(viewport_bbox)
      let mut clip_x = floor_to_int(world_bbox.min_x)
      let mut clip_y = floor_to_int(world_bbox.min_y)
      let mut clip_w = ceil_to_int(world_bbox.max_x - world_bbox.min_x)
      let mut clip_h = ceil_to_int(world_bbox.max_y - world_bbox.min_y)
      if clip_x < 0 {
        clip_w = clip_w + clip_x
        clip_x = 0
      }
      if clip_y < 0 {
        clip_h = clip_h + clip_y
        clip_y = 0
      }
      if clip_x + clip_w > ctx_for_node.width {
        clip_w = ctx_for_node.width - clip_x
      }
      if clip_y + clip_h > ctx_for_node.height {
        clip_h = ctx_for_node.height - clip_y
      }
      if clip_w <= 0 || clip_h <= 0 {
        return
      }
      let viewport_clip = ClipRect::new(clip_x, clip_y, clip_w, clip_h)
      let merged = match ctx_for_node.clip {
        Some(existing) => intersect_clip(existing, viewport_clip)
        None => Some(viewport_clip)
      }
      match merged {
        Some(clip) => {
          let setter = ctx_for_node.setter.with_clip(clip)
          { ..ctx_for_node, setter, clip: Some(clip) }
        }
        None => return
      }
    }
    _ => ctx_for_node
  }
  // Apply mask if present
  if allow_mask {
    match node.mask_id {
      Some(id) =>
        match resources.masks.get(id) {
          Some(mask) => {
            render_masked_node(
              node, parent_transform, ctx_for_node, resources, mask, node_color,
            )
            return
          }
          None => ()
        }
      None => ()
    }
  }
  // Early culling: check if node's bounding box is visible
  let shape_bbox = get_shape_bounds(node.shape)
  if not(shape_bbox.is_empty()) {
    let transformed_bbox = transform.apply_bbox(shape_bbox)
    if not(is_visible(transformed_bbox, ctx_for_node)) {
      // Node is outside visible area, but still need to check children
      // (they might have different transforms that make them visible)
      for child in node.children {
        render_node(child, transform, ctx_for_node, resources, true, node_color)
      }
      return
    }
  }
  // Render shape
  match node.shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      render_rect(
        x, y, width, height, rx, ry, node, transform, ctx_for_node, resources, node_color,
      )
    Circle(cx~, cy~, r~) =>
      render_circle(
        cx, cy, r, node, transform, ctx_for_node, resources, node_color,
      )
    Ellipse(cx~, cy~, rx~, ry~) =>
      render_ellipse(
        cx, cy, rx, ry, node, transform, ctx_for_node, resources, node_color,
      )
    Line(x1~, y1~, x2~, y2~) =>
      render_line(
        x1, y1, x2, y2, node, transform, ctx_for_node, resources, node_color,
      )
    Polyline(points~) =>
      render_polyline(
        points, node, transform, ctx_for_node, resources, node_color,
      )
    Polygon(points~) =>
      render_polygon(
        points, node, transform, ctx_for_node, node_color, resources,
      )
    Path(commands~) =>
      render_path(
        commands, node, transform, ctx_for_node, node_color, resources,
      )
    Text(x~, y~, text~, font_size~) =>
      render_text(
        x, y, text, font_size, node, transform, ctx_for_node, node_color, resources,
      )
    Image(x~, y~, width~, height~, href~) =>
      render_image(
        x,
        y,
        width,
        height,
        href,
        transform,
        ctx_for_node,
        node.preserve_aspect_ratio,
        node.preserve_aspect_ratio_is_set,
      )
    Group => ()
  }
  // Render children sorted by z_index (lower z_index first = back to front)
  let sorted_children = sort_by_z_index(node.children)
  for child in sorted_children {
    render_node(child, transform, ctx_for_node, resources, true, node_color)
  }
}

///|
fn apply_clip_path(
  ctx : RenderContext,
  clip : ClipPath,
  element_transform : Transform,
  bbox_local : BoundingBox,
) -> RenderContext {
  let base_transform = match clip.units {
    ClipPathUnits::UserSpaceOnUse => element_transform
    ClipPathUnits::ObjectBoundingBox => {
      if bbox_local.is_empty() {
        return ctx
      }
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      element_transform.multiply(translate.multiply(scale))
    }
  }
  let combined = base_transform.multiply(clip.transform)
  let clip = ClipPath::{
    id: clip.id,
    shape: clip.shape,
    transform: combined,
    clip_rule: clip.clip_rule,
    units: clip.units,
  }
  let inner = ctx.setter
  let setter : PixelSetter = {
    set: fn(x, y, color) {
      let px = x.to_double() + 0.5
      let py = y.to_double() + 0.5
      if clip.contains(px, py) {
        inner.pixel(x, y, color)
      }
    },
  }
  { ..ctx, setter, }
}

///|
fn render_masked_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  mask : Mask,
  parent_color : Color,
) -> Unit {
  let bbox = compute_bounds(node, parent_transform)
  if bbox.is_empty() {
    return
  }
  let bbox_local = compute_bounds_without_self_transform(
    node,
    Transform::identity(),
  )
  let element_transform = parent_transform.multiply(node.transform)
  let min_x = floor_to_int(bbox.min_x)
  let min_y = floor_to_int(bbox.min_y)
  let max_x = ceil_to_int(bbox.max_x)
  let max_y = ceil_to_int(bbox.max_y)
  let width = max_x - min_x
  let height = max_y - min_y
  if width <= 0 || height <= 0 {
    return
  }
  let image = Image::new(width, height)
  let image_ctx = make_image_context(image, width, height, ctx.flatness)
  let offset = Transform::translate(-min_x.to_double(), -min_y.to_double())
  let image_parent = offset.multiply(parent_transform)
  render_node(node, image_parent, image_ctx, resources, false, parent_color)
  let mask_image = Image::new(width, height)
  let mask_ctx = make_image_context(mask_image, width, height, ctx.flatness)
  let mask_bounds_local = mask.get_mask_bounds(bbox_local)
  let mask_bounds = element_transform.apply_bbox(mask_bounds_local)
  let mut clip_min_x = floor_to_int(mask_bounds.min_x) - min_x
  let mut clip_min_y = floor_to_int(mask_bounds.min_y) - min_y
  let mut clip_max_x = ceil_to_int(mask_bounds.max_x) - min_x
  let mut clip_max_y = ceil_to_int(mask_bounds.max_y) - min_y
  if clip_min_x < 0 {
    clip_min_x = 0
  }
  if clip_min_y < 0 {
    clip_min_y = 0
  }
  if clip_max_x > width {
    clip_max_x = width
  }
  if clip_max_y > height {
    clip_max_y = height
  }
  let clip_w = clip_max_x - clip_min_x
  let clip_h = clip_max_y - clip_min_y
  let mask_ctx = if clip_w > 0 && clip_h > 0 {
    let clip = ClipRect::new(clip_min_x, clip_min_y, clip_w, clip_h)
    { ..mask_ctx, setter: mask_ctx.setter.with_clip(clip), clip: Some(clip) }
  } else {
    mask_ctx
  }
  let mask_parent = match mask.mask_content_units {
    MaskUnits::ObjectBoundingBox => {
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let object_transform = element_transform.multiply(
        translate.multiply(scale),
      )
      offset.multiply(object_transform)
    }
    MaskUnits::UserSpaceOnUse => offset.multiply(element_transform)
  }
  for content_node in mask.content {
    render_node(
      content_node, mask_parent, mask_ctx, resources, false, parent_color,
    )
  }
  let masked = apply_mask_to_image(image, mask_image, mask.mask_type)
  blit_image_to_context(masked, ctx, min_x, min_y)
}

///|
fn make_image_context(
  image : Image,
  width : Int,
  height : Int,
  flatness : Double,
) -> RenderContext {
  let setter : PixelSetter = {
    set: (x, y, color) => image.set_pixel(x, y, color),
  }
  { setter, width, height, flatness, clip: None, text_to_paths: None }
}

///|
fn blit_image_to_context(
  image : Image,
  ctx : RenderContext,
  offset_x : Int,
  offset_y : Int,
) -> Unit {
  let setter = match ctx.clip {
    Some(clip) => ctx.setter.with_clip(clip)
    None => ctx.setter
  }
  for y in 0..<image.height {
    for x in 0..<image.width {
      let color = image.get_pixel(x, y)
      if color.a > 0 {
        setter.pixel(x + offset_x, y + offset_y, color)
      }
    }
  }
}

///|
fn floor_to_int(value : Double) -> Int {
  value.floor().to_int()
}

///|
fn ceil_to_int(value : Double) -> Int {
  let i = value.to_int()
  if value > i.to_double() {
    i + 1
  } else {
    i
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
  for i in 1..<result.length() {
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
priv enum ResolvedPaint {
  None
  SolidColor(Color)
  LinearGrad(LinearGradient)
  RadialGrad(RadialGradient)
  Pattern(Pattern)
}

///|
fn resolve_paint_fallback(
  fallback : PaintFallback,
  node_color : Color,
) -> ResolvedPaint {
  match fallback {
    PaintFallback::NoPaint => ResolvedPaint::None
    PaintFallback::SolidColor(color) => ResolvedPaint::SolidColor(color)
    PaintFallback::CurrentColor => ResolvedPaint::SolidColor(node_color)
  }
}

///|
fn pattern_is_valid(pattern : Pattern) -> Bool {
  if pattern.width <= 0.0 || pattern.height <= 0.0 {
    return false
  }
  if not(pattern.transform.is_invertible()) {
    return false
  }
  pattern.content.length() > 0
}

///|
fn resolve_paint_for_render(
  paint : Paint,
  node_color : Color,
  resources : RenderResources,
) -> ResolvedPaint {
  match paint {
    None => ResolvedPaint::None
    SolidColor(color) => ResolvedPaint::SolidColor(color)
    LinearGrad(grad) =>
      if grad.stops.length() == 0 {
        ResolvedPaint::None
      } else {
        ResolvedPaint::LinearGrad(grad)
      }
    RadialGrad(grad) =>
      if grad.stops.length() == 0 {
        ResolvedPaint::None
      } else {
        ResolvedPaint::RadialGrad(grad)
      }
    CurrentColor => ResolvedPaint::SolidColor(node_color)
    PaintServerRef(id, fallback) =>
      match resources.gradients.get(id) {
        Some(Gradient::Linear(grad)) =>
          if not(grad.transform.is_invertible()) {
            resolve_paint_fallback(fallback, node_color)
          } else if grad.stops.length() == 0 {
            ResolvedPaint::None
          } else {
            ResolvedPaint::LinearGrad(grad)
          }
        Some(Gradient::Radial(grad)) =>
          if not(grad.transform.is_invertible()) {
            resolve_paint_fallback(fallback, node_color)
          } else if grad.stops.length() == 0 {
            ResolvedPaint::None
          } else {
            ResolvedPaint::RadialGrad(grad)
          }
        None =>
          match resources.patterns.get(id) {
            Some(pattern) =>
              if pattern_is_valid(pattern) {
                ResolvedPaint::Pattern(pattern)
              } else {
                resolve_paint_fallback(fallback, node_color)
              }
            None => resolve_paint_fallback(fallback, node_color)
          }
      }
  }
}

///|
fn render_paint_order(
  order : PaintOrder,
  draw_fill : () -> Unit,
  draw_stroke : () -> Unit,
  draw_markers : () -> Unit,
) -> Unit {
  for item in order.order {
    match item {
      Fill => draw_fill()
      Stroke => draw_stroke()
      Markers => draw_markers()
    }
  }
}

///|
fn render_pattern_fill(
  shape : Shape,
  transform : Transform,
  ctx : RenderContext,
  pattern : Pattern,
  opacity : Double,
) -> Unit {
  let bbox_local = get_shape_bounds(shape)
  if bbox_local.is_empty() {
    return
  }
  let bbox_world = transform.apply_bbox(bbox_local)
  let mut ix = floor_to_int(bbox_world.min_x)
  let mut iy = floor_to_int(bbox_world.min_y)
  let mut iw = ceil_to_int(bbox_world.max_x - bbox_world.min_x)
  let mut ih = ceil_to_int(bbox_world.max_y - bbox_world.min_y)
  if iw <= 0 || ih <= 0 {
    return
  }
  if ix < 0 {
    iw = iw + ix
    ix = 0
  }
  if iy < 0 {
    ih = ih + iy
    iy = 0
  }
  if ix + iw > ctx.width {
    iw = ctx.width - ix
  }
  if iy + ih > ctx.height {
    ih = ctx.height - iy
  }
  if iw <= 0 || ih <= 0 {
    return
  }
  let inv = transform.inverse()
  let pattern_inv = pattern.transform.inverse()
  for y in iy..<(iy + ih) {
    for x in ix..<(ix + iw) {
      let wx = x.to_double() + 0.5
      let wy = y.to_double() + 0.5
      let (lx, ly) = inv.apply(wx, wy)
      if hit_test_shape(lx, ly, shape) {
        let (px, py) = pattern_inv.apply(lx, ly)
        if pattern.get_color_at(px, py, bbox_local) is Some(color) {
          ctx.setter.pixel(x, y, apply_opacity(color, opacity))
        }
      }
    }
  }
}

///|
fn build_substring_local(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  let len = s.length()
  while i < end && i < len {
    buf.write_char(Int::unsafe_to_char(s[i].to_int()))
    i = i + 1
  }
  buf.to_string()
}

///|
fn string_ends_with_local(s : String, suffix : String) -> Bool {
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
fn trim_string_local(s : String) -> String {
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
  build_substring_local(s, start, end)
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn char_at(s : String, i : Int) -> Char {
  Int::unsafe_to_char(s[i].to_int())
}

///|
fn parse_simple_number(s : String) -> Double {
  let s = trim_string_local(s)
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  let first = char_at(s, i)
  if first == '-' {
    sign = -1.0
    i = i + 1
  } else if first == '+' {
    i = i + 1
  }
  while i < len {
    let c = char_at(s, i)
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
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
fn parse_length_simple(s : String) -> Double {
  let s = trim_string_local(s)
  let cleaned = if string_ends_with_local(s, "px") {
    build_substring_local(s, 0, s.length() - 2)
  } else if string_ends_with_local(s, "em") || string_ends_with_local(s, "pt") {
    build_substring_local(s, 0, s.length() - 2)
  } else if string_ends_with_local(s, "%") {
    build_substring_local(s, 0, s.length() - 1)
  } else {
    s
  }
  parse_simple_number(cleaned)
}

///|
fn replace_viewport_units(value : String, vw : Double, vh : Double) -> String {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c = char_at(value, i)
    let is_number_start = (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' ||
      c == '+'
    if is_number_start {
      let start = i
      i = i + 1
      while i < len {
        let nc = char_at(value, i)
        if (nc >= '0' && nc <= '9') || nc == '.' {
          i = i + 1
        } else {
          break
        }
      }
      let num_str = build_substring_local(value, start, i)
      if i + 1 < len && char_at(value, i) == 'v' {
        let unit = char_at(value, i + 1)
        if unit == 'w' || unit == 'h' {
          let num = parse_simple_number(num_str)
          let val = if unit == 'w' {
            num * vw / 100.0
          } else {
            num * vh / 100.0
          }
          buf.write_string(val.to_string())
          i = i + 2
          continue
        }
      }
      buf.write_string(num_str)
      continue
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
fn match_at(s : String, idx : Int, pat : String) -> Bool {
  if idx + pat.length() > s.length() {
    return false
  }
  for i in 0..<pat.length() {
    if s[idx + i] != pat[i] {
      return false
    }
  }
  true
}

///|
fn find_attr_value(svg : String, name : String) -> String? {
  let len = svg.length()
  let mut end = len
  for i in 0..<len {
    if char_at(svg, i) == '>' {
      end = i
      break
    }
  }
  let mut i = 0
  while i < end {
    if match_at(svg, i, name) {
      let mut j = i + name.length()
      while j < end && is_space_char(char_at(svg, j)) {
        j = j + 1
      }
      if j < end && char_at(svg, j) == '=' {
        j = j + 1
        while j < end && is_space_char(char_at(svg, j)) {
          j = j + 1
        }
        if j >= end {
          return None
        }
        let quote = char_at(svg, j)
        if quote == '"' || quote == '\'' {
          j = j + 1
          let start = j
          while j < end && char_at(svg, j) != quote {
            j = j + 1
          }
          if j > start {
            return Some(build_substring_local(svg, start, j))
          }
          return None
        } else {
          let start = j
          while j < end &&
                (char_at(svg, j) |> is_space_char |> not) &&
                char_at(svg, j) != '>' {
            j = j + 1
          }
          if j > start {
            return Some(build_substring_local(svg, start, j))
          }
          return None
        }
      }
    }
    i = i + 1
  }
  None
}

///|
fn extract_svg_size(svg : String) -> (Double, Double) {
  let width = match find_attr_value(svg, "width") {
    Some(v) => parse_length_simple(v)
    None => 0.0
  }
  let height = match find_attr_value(svg, "height") {
    Some(v) => parse_length_simple(v)
    None => 0.0
  }
  (width, height)
}

///|
fn render_image(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  href : String,
  transform : Transform,
  ctx : RenderContext,
  preserve_aspect_ratio : PreserveAspectRatio,
  preserve_aspect_ratio_is_set : Bool,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  if href.length() == 0 {
    return
  }
  let (x0, y0) = transform.apply(x, y)
  let (x1, y1) = transform.apply(x + width, y + height)
  let min_x = min(x0, x1)
  let min_y = min(y0, y1)
  let max_x = max(x0, x1)
  let max_y = max(y0, y1)
  let ix = floor_to_int(min_x)
  let iy = floor_to_int(min_y)
  let iw = ceil_to_int(max_x - min_x)
  let ih = ceil_to_int(max_y - min_y)
  if iw <= 0 || ih <= 0 {
    return
  }
  let processed = replace_viewport_units(href, iw.to_double(), ih.to_double())
  match parse_svg_document(processed) {
    Some(doc) => {
      if preserve_aspect_ratio_is_set {
        doc.root.preserve_aspect_ratio = preserve_aspect_ratio
      }
      if doc.root.view_box is None {
        let (svg_w, svg_h) = extract_svg_size(processed)
        if svg_w > 0.0 && svg_h > 0.0 {
          doc.root.view_box = Some(ViewBox::{
            min_x: 0.0,
            min_y: 0.0,
            width: svg_w,
            height: svg_h,
          })
        }
      }
      let image = Image::new(iw, ih)
      let setter : PixelSetter = {
        set: (px, py, color) => image.set_pixel(px, py, color),
      }
      let image_ctx = RenderContext::new(setter, iw, ih)
      doc.render(image_ctx)
      blit_image_to_context(image, ctx, ix, iy)
    }
    None => ()
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
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  // Transform corners
  let (x0, y0) = transform.apply(x, y)
  let (x1, y1) = transform.apply(x + width, y + height)
  let min_x = min(x0, x1)
  let min_y = min(y0, y1)
  let max_x = max(x0, x1)
  let max_y = max(y0, y1)
  let ix = floor_to_int(min_x)
  let iy = floor_to_int(min_y)
  let iw = ceil_to_int(max_x - min_x)
  let ih = ceil_to_int(max_y - min_y)
  if iw <= 0 || ih <= 0 {
    return
  }
  let (sx, sy) = transform.get_scale()
  let irx = (rx * sx).to_int()
  let iry = (ry * sy).to_int()
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          if irx > 0 || iry > 0 {
            raster_rounded_rect_fill(
              ix,
              iy,
              iw,
              ih,
              irx,
              iry,
              fill_color,
              ctx.setter,
            )
          } else {
            raster_rect_fill(ix, iy, iw, ih, fill_color, ctx.setter)
          }
        }
      ResolvedPaint::LinearGrad(grad) =>
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
      ResolvedPaint::RadialGrad(grad) =>
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
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          render_pattern_fill(
            node.shape,
            transform,
            ctx,
            pattern,
            node.fill_opacity * node.opacity,
          )
        }
      ResolvedPaint::None => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          let stroke_width = node.stroke.width * (sx + sy) / 2.0
          let stroke_px = if stroke_width > 0.0 {
            ceil_to_int(stroke_width)
          } else {
            0
          }
          if stroke_px > 0 {
            if irx > 0 || iry > 0 {
              raster_rounded_rect_stroke_thick(
                ix,
                iy,
                iw,
                ih,
                irx,
                iry,
                stroke_px,
                stroke_color,
                ctx.setter,
              )
            } else {
              raster_rect_stroke_thick(
                ix,
                iy,
                iw,
                ih,
                stroke_px,
                stroke_color,
                ctx.setter,
              )
            }
          }
        }
      _ => ()
    }
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, () => ())
}

///|
fn render_circle(
  cx : Double,
  cy : Double,
  r : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if r <= 0.0 {
    return
  }
  let (tx, ty) = transform.apply(cx, cy)
  let (sx, sy) = transform.get_scale()
  let tr = (r * (sx + sy) / 2.0).to_int()
  if tr <= 0 {
    return
  }
  let icx = tx.to_int()
  let icy = ty.to_int()
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_circle_fill(icx, icy, tr, fill_color, ctx.setter)
        }
      ResolvedPaint::RadialGrad(grad) =>
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
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          render_pattern_fill(
            node.shape,
            transform,
            ctx,
            pattern,
            node.fill_opacity * node.opacity,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_circle_stroke(icx, icy, tr, stroke_color, ctx.setter)
        }
      _ => ()
    }
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, () => ())
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
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if rx <= 0.0 || ry <= 0.0 {
    return
  }
  let (tx, ty) = transform.apply(cx, cy)
  let (sx, sy) = transform.get_scale()
  let trx = (rx * sx).to_int()
  let try_ = (ry * sy).to_int()
  if trx <= 0 || try_ <= 0 {
    return
  }
  let icx = tx.to_int()
  let icy = ty.to_int()
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_ellipse_fill(icx, icy, trx, try_, fill_color, ctx.setter)
        }
      ResolvedPaint::RadialGrad(grad) =>
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
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          render_pattern_fill(
            node.shape,
            transform,
            ctx,
            pattern,
            node.fill_opacity * node.opacity,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_ellipse_stroke(icx, icy, trx, try_, stroke_color, ctx.setter)
        }
      _ => ()
    }
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, () => ())
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
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  let (tx1, ty1) = transform.apply(x1, y1)
  let (tx2, ty2) = transform.apply(x2, y2)
  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          let stroke_px = node.stroke.width.to_int()
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
                  stroke_px,
                  stroke_color,
                  ctx.setter,
                )
                draw_line_caps(
                  tx1.to_int(),
                  ty1.to_int(),
                  tx2.to_int(),
                  ty2.to_int(),
                  stroke_px,
                  node.stroke.linecap,
                  stroke_color,
                  ctx.setter,
                )
              }
          }
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_points(
      [(x1, y1), (x2, y2)],
      node,
      transform,
      ctx,
      resources,
      node_color,
    )
  }

  render_paint_order(node.paint_order, () => (), draw_stroke, draw_markers)
}

///|
fn draw_line_caps(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if width <= 1 {
    return
  }
  match linecap {
    Butt => ()
    Round => {
      let half_w = width / 2
      raster_circle_fill(x0, y0, half_w, color, setter)
      raster_circle_fill(x1, y1, half_w, color, setter)
    }
    Square => {
      let dx = (x1 - x0).to_double()
      let dy = (y1 - y0).to_double()
      let len = (dx * dx + dy * dy).sqrt()
      if len < 0.001 {
        let half_w = width / 2
        raster_circle_fill(x0, y0, half_w, color, setter)
        return
      }
      let ux = dx / len
      let uy = dy / len
      let half_w = width / 2
      let ex = (ux * half_w.to_double()).to_int()
      let ey = (uy * half_w.to_double()).to_int()
      raster_thick_line(x0 - ex, y0 - ey, x0, y0, width, color, setter)
      raster_thick_line(x1, y1, x1 + ex, y1 + ey, width, color, setter)
    }
  }
}

///|
fn marker_transform_with_ref_ratio(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  scale : Double,
  ref_ratio : Double,
) -> Transform {
  let orient_angle = match marker.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  let content_transform = match marker.view_box {
    Some(vb) => {
      let view_t = vb.get_transform(
        marker.marker_width,
        marker.marker_height,
        marker.preserve_aspect_ratio,
      )
      let (ref_px, ref_py) = view_t.apply(marker.ref_x, marker.ref_y)
      let ref_t = Transform::translate(-ref_px * ref_ratio, -ref_py * ref_ratio)
      ref_t.multiply(view_t)
    }
    None =>
      Transform::translate(-marker.ref_x * ref_ratio, -marker.ref_y * ref_ratio)
  }
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  t1.multiply(r).multiply(s).multiply(content_transform)
}

///|
fn render_marker_instance(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  let (marker_scale, ref_ratio) = match marker.marker_units {
    StrokeWidth => {
      let scale = node.stroke.width
      if scale > 0.0 {
        (scale, 1.0)
      } else {
        (0.0, 1.0)
      }
    }
    UserSpaceOnUse_ => (1.0, 1.0)
  }
  let marker_transform = marker_transform_with_ref_ratio(
    marker, x, y, angle, marker_scale, ref_ratio,
  )
  let viewport_transform = marker_viewport_transform(
    marker, x, y, angle, marker_scale, ref_ratio,
  )
  let parent_transform = transform.multiply(marker_transform)
  let mut ctx_for_marker = ctx
  if marker.clip_overflow &&
    marker.marker_width > 0.0 &&
    marker.marker_height > 0.0 {
    let viewport_bbox = BoundingBox::from_rect(
      0.0,
      0.0,
      marker.marker_width,
      marker.marker_height,
    )
    let clip_transform = transform.multiply(viewport_transform)
    let clip_shape = Rect(
      x=viewport_bbox.min_x,
      y=viewport_bbox.min_y,
      width=viewport_bbox.width(),
      height=viewport_bbox.height(),
      rx=0.0,
      ry=0.0,
    )
    let clip = ClipPath::with_transform(
      "marker-viewport", clip_shape, clip_transform,
    )
    ctx_for_marker = apply_clip_path(
      ctx_for_marker,
      clip,
      Transform::identity(),
      BoundingBox::empty(),
    )
  }
  render_node(
    marker.content,
    parent_transform,
    ctx_for_marker,
    resources,
    true,
    node_color,
  )
}

///|
fn marker_viewport_transform(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  scale : Double,
  ref_ratio : Double,
) -> Transform {
  let orient_angle = match marker.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  let (ref_px, ref_py) = match marker.view_box {
    Some(vb) => {
      let view_t = vb.get_transform(
        marker.marker_width,
        marker.marker_height,
        marker.preserve_aspect_ratio,
      )
      view_t.apply(marker.ref_x, marker.ref_y)
    }
    None => (marker.ref_x, marker.ref_y)
  }
  let ref_t = Transform::translate(-ref_px * ref_ratio, -ref_py * ref_ratio)
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  t1.multiply(r).multiply(s).multiply(ref_t)
}

///|
fn render_markers_for_points(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if points.length() < 2 {
    return
  }
  if node.marker_start is None &&
    node.marker_mid is None &&
    node.marker_end is None {
    return
  }
  let (sx, sy) = transform.get_scale()
  let skew = transform.a * transform.c + transform.b * transform.d
  let use_transformed = (sx - sy).abs() > 0.0001 || skew.abs() > 0.0001
  let angle_points = if use_transformed {
    points.map(p => transform.apply(p.0, p.1))
  } else {
    points
  }
  let line = MarkedLine::new(angle_points)
  let inv = transform.inverse()
  fn to_local_angle(angle : Double) -> Double {
    let dx = @math.cos(angle)
    let dy = @math.sin(angle)
    let lx = inv.a * dx + inv.c * dy
    let ly = inv.b * dx + inv.d * dy
    @math.atan2(ly, lx)
  }

  let last = points.length() - 1
  for i in 0..<points.length() {
    let marker_id = if i == 0 {
      node.marker_start
    } else if i == last {
      node.marker_end
    } else {
      node.marker_mid
    }
    match marker_id {
      Some(id) =>
        match resources.markers.get(id) {
          Some(marker) => {
            let (x, y) = points[i]
            let angle = if use_transformed {
              to_local_angle(line.get_angle_at(i))
            } else {
              line.get_angle_at(i)
            }
            render_marker_instance(
              marker, x, y, angle, node, transform, ctx, resources, node_color,
            )
          }
          None => ()
        }
      None => ()
    }
  }
}

///|
fn is_closed_polyline_double(points : Array[(Double, Double)]) -> Bool {
  if points.length() < 2 {
    false
  } else {
    let last = points.length() - 1
    let (x0, y0) = points[0]
    let (x1, y1) = points[last]
    x0 == x1 && y0 == y1
  }
}

///|
fn render_markers_for_polylines(
  polylines : Array[Array[(Double, Double)]],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if node.marker_start is None &&
    node.marker_mid is None &&
    node.marker_end is None {
    return
  }
  if polylines.length() == 0 {
    return
  }
  // Find first/last non-empty polyline
  let mut first_idx = -1
  let mut last_idx = -1
  for i in 0..<polylines.length() {
    if polylines[i].length() >= 2 {
      if first_idx < 0 {
        first_idx = i
      }
      last_idx = i
    }
  }
  if first_idx < 0 || last_idx < 0 {
    return
  }
  let eps = 0.0001
  let (sx, sy) = transform.get_scale()
  let skew = transform.a * transform.c + transform.b * transform.d
  let use_transformed = (sx - sy).abs() > eps || skew.abs() > eps
  let inv = transform.inverse()
  fn angle_from(dx : Double, dy : Double) -> Double {
    if use_transformed {
      let lx = inv.a * dx + inv.c * dy
      let ly = inv.b * dx + inv.d * dy
      @math.atan2(ly, lx)
    } else {
      @math.atan2(dy, dx)
    }
  }

  fn normalize(dx : Double, dy : Double) -> (Double, Double, Double) {
    let len = (dx * dx + dy * dy).sqrt()
    if len < eps {
      (0.0, 0.0, len)
    } else {
      (dx / len, dy / len, len)
    }
  }

  fn angle_start(points : Array[(Double, Double)]) -> Double {
    if points.length() < 2 {
      return 0.0
    }
    for i in 1..<points.length() {
      let dx = points[i].0 - points[0].0
      let dy = points[i].1 - points[0].1
      let (_, _, l) = normalize(dx, dy)
      if l >= eps {
        return angle_from(dx, dy)
      }
    }
    0.0
  }

  fn angle_end(points : Array[(Double, Double)]) -> Double {
    if points.length() < 2 {
      return 0.0
    }
    for i = points.length() - 1; i > 0; i = i - 1 {
      let dx = points[i].0 - points[i - 1].0
      let dy = points[i].1 - points[i - 1].1
      let (_, _, l) = normalize(dx, dy)
      if l >= eps {
        return angle_from(dx, dy)
      }
    }
    0.0
  }

  fn angle_mid(
    points : Array[(Double, Double)],
    index : Int,
    closed : Bool,
    has_duplicate : Bool,
  ) -> Double {
    let len = points.length()
    if len < 2 {
      return 0.0
    }
    if not(closed) && index == 0 {
      for i in 1..<len {
        let dx = points[i].0 - points[0].0
        let dy = points[i].1 - points[0].1
        let (_, _, l) = normalize(dx, dy)
        if l >= eps {
          return angle_from(dx, dy)
        }
      }
      return 0.0
    }
    if not(closed) && index >= len - 1 {
      for i = len - 1; i > 0; i = i - 1 {
        let dx = points[i].0 - points[i - 1].0
        let dy = points[i].1 - points[i - 1].1
        let (_, _, l) = normalize(dx, dy)
        if l >= eps {
          return angle_from(dx, dy)
        }
      }
      return 0.0
    }
    let prev = if has_duplicate && closed {
      if index == 0 || index == len - 1 {
        if len > 1 {
          len - 2
        } else {
          0
        }
      } else {
        index - 1
      }
    } else if index == 0 {
      len - 1
    } else {
      index - 1
    }
    let next = if has_duplicate && closed {
      if index == len - 1 {
        if len > 1 {
          1
        } else {
          0
        }
      } else if index + 1 == len {
        0
      } else {
        index + 1
      }
    } else if index + 1 == len {
      0
    } else {
      index + 1
    }
    let dx1 = points[index].0 - points[prev].0
    let dy1 = points[index].1 - points[prev].1
    let dx2 = points[next].0 - points[index].0
    let dy2 = points[next].1 - points[index].1
    let (ux1, uy1, l1) = normalize(dx1, dy1)
    let (ux2, uy2, l2) = normalize(dx2, dy2)
    if l1 < eps && l2 < eps {
      return 0.0
    }
    if l1 < eps {
      return angle_from(dx2, dy2)
    }
    if l2 < eps {
      return angle_from(dx1, dy1)
    }
    let sx = ux1 + ux2
    let sy = uy1 + uy2
    if sx * sx + sy * sy < eps * eps {
      angle_from(dx2, dy2)
    } else {
      angle_from(sx, sy)
    }
  }

  for poly_idx in 0..<polylines.length() {
    let points = polylines[poly_idx]
    if points.length() < 2 {
      continue
    }
    let angle_points = if use_transformed {
      points.map(p => transform.apply(p.0, p.1))
    } else {
      points
    }
    let closed = is_closed_polyline_double(points)
    let has_duplicate = closed
    let last = points.length() - 1
    for i in 0..<points.length() {
      let marker_id = if poly_idx == first_idx && i == 0 {
        node.marker_start
      } else if poly_idx == last_idx && i == last {
        node.marker_end
      } else {
        node.marker_mid
      }
      match marker_id {
        Some(id) =>
          match resources.markers.get(id) {
            Some(marker) => {
              let (x, y) = points[i]
              let angle = if i == 0 {
                if closed {
                  angle_mid(angle_points, i, closed, has_duplicate)
                } else {
                  angle_start(angle_points)
                }
              } else if i == last {
                if closed {
                  angle_mid(angle_points, i, closed, has_duplicate)
                } else {
                  angle_end(angle_points)
                }
              } else {
                angle_mid(angle_points, i, closed, has_duplicate)
              }
              render_marker_instance(
                marker, x, y, angle, node, transform, ctx, resources, node_color,
              )
            }
            None => ()
          }
        None => ()
      }
    }
  }
}

///|
priv struct MarkerPoint {
  x : Double
  y : Double
  mut has_in : Bool
  mut in_dx : Double
  mut in_dy : Double
  mut has_out : Bool
  mut out_dx : Double
  mut out_dy : Double
}

///|
fn MarkerPoint::new(x : Double, y : Double) -> MarkerPoint {
  {
    x,
    y,
    has_in: false,
    in_dx: 0.0,
    in_dy: 0.0,
    has_out: false,
    out_dx: 0.0,
    out_dy: 0.0,
  }
}

///|
priv struct MarkerSubpath {
  points : Array[MarkerPoint]
}

///|
fn arc_tangent_at(
  theta : Double,
  cos_phi : Double,
  sin_phi : Double,
  rx : Double,
  ry : Double,
) -> (Double, Double) {
  let sin_t = @math.sin(theta)
  let cos_t = @math.cos(theta)
  let dx = -cos_phi * rx * sin_t - sin_phi * ry * cos_t
  let dy = -sin_phi * rx * sin_t + cos_phi * ry * cos_t
  (dx, dy)
}

///|
fn angle_between_vec(
  ux : Double,
  uy : Double,
  vx : Double,
  vy : Double,
) -> Double {
  let dot = ux * vx + uy * vy
  let len_u = (ux * ux + uy * uy).sqrt()
  let len_v = (vx * vx + vy * vy).sqrt()
  let len_prod = len_u * len_v
  if len_prod == 0.0 {
    return 0.0
  }
  let mut cos_angle = dot / len_prod
  if cos_angle > 1.0 {
    cos_angle = 1.0
  }
  if cos_angle < -1.0 {
    cos_angle = -1.0
  }
  let angle = @math.acos(cos_angle)
  let cross = ux * vy - uy * vx
  if cross < 0.0 {
    -angle
  } else {
    angle
  }
}

///|
fn compute_arc_tangents(
  x1 : Double,
  y1 : Double,
  rx_in : Double,
  ry_in : Double,
  rotation_degrees : Double,
  large_arc : Bool,
  sweep : Bool,
  x2 : Double,
  y2 : Double,
) -> (Double, Double, Double, Double) {
  let dx_line = x2 - x1
  let dy_line = y2 - y1
  if (x1 == x2 && y1 == y2) || rx_in == 0.0 || ry_in == 0.0 {
    return (dx_line, dy_line, dx_line, dy_line)
  }
  let mut rx = if rx_in < 0.0 { -rx_in } else { rx_in }
  let mut ry = if ry_in < 0.0 { -ry_in } else { ry_in }
  let phi = degrees_to_radians(rotation_degrees)
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let dx = (x1 - x2) / 2.0
  let dy = (y1 - y2) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if lambda > 1.0 {
    let sqrt_lambda = lambda.sqrt()
    rx = rx * sqrt_lambda
    ry = ry * sqrt_lambda
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let sq = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / (rx2 * y1p2 + ry2 * x1p2)
  let sq_abs = if sq < 0.0 { 0.0 } else { sq }
  let coef = sq_abs.sqrt() * (if large_arc == sweep { -1.0 } else { 1.0 })
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  let theta1 = angle_between_vec(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  let mut dtheta = angle_between_vec(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  )
  let pi = 3.14159265358979323846
  if not(sweep) && dtheta > 0.0 {
    dtheta = dtheta - 2.0 * pi
  } else if sweep && dtheta < 0.0 {
    dtheta = dtheta + 2.0 * pi
  }
  let theta2 = theta1 + dtheta
  let sign = if dtheta < 0.0 { -1.0 } else { 1.0 }
  let (sx, sy) = arc_tangent_at(theta1, cos_phi, sin_phi, rx, ry)
  let (ex, ey) = arc_tangent_at(theta2, cos_phi, sin_phi, rx, ry)
  (sx * sign, sy * sign, ex * sign, ey * sign)
}

///|
fn build_marker_subpaths(commands : Array[PathCommand]) -> Array[MarkerSubpath] {
  let subpaths : Array[MarkerSubpath] = []
  let mut points : Array[MarkerPoint] = []
  let mut closed = false
  let mut cur_x = 0.0
  let mut cur_y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  let mut last_ctrl_x = 0.0
  let mut last_ctrl_y = 0.0
  let mut last_cmd_was_curve = false
  let mut last_cmd_was_quad = false
  let eps = 0.0001
  fn finish_subpath(
    subpaths : Array[MarkerSubpath],
    points : Array[MarkerPoint],
    closed : Bool,
  ) -> Unit {
    if points.length() == 0 {
      return
    }
    let out_points = points
    if closed {
      let first = out_points[0]
      let dup = MarkerPoint::new(first.x, first.y)
      if first.has_in {
        dup.has_in = true
        dup.in_dx = first.in_dx
        dup.in_dy = first.in_dy
      }
      out_points.push(dup)
    }
    subpaths.push(MarkerSubpath::{ points: out_points })
  }

  fn record_out(
    points : Array[MarkerPoint],
    idx : Int,
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> Unit {
    let len = (dx * dx + dy * dy).sqrt()
    if len >= eps {
      points[idx].has_out = true
      points[idx].out_dx = dx
      points[idx].out_dy = dy
    }
  }

  fn record_in(
    points : Array[MarkerPoint],
    idx : Int,
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> Unit {
    let len = (dx * dx + dy * dy).sqrt()
    if len >= eps {
      points[idx].has_in = true
      points[idx].in_dx = dx
      points[idx].in_dy = dy
    }
  }

  fn add_segment(
    points : Array[MarkerPoint],
    cur_x : Double,
    cur_y : Double,
    end_x : Double,
    end_y : Double,
    out_dx : Double,
    out_dy : Double,
    in_dx : Double,
    in_dy : Double,
    eps : Double,
  ) -> Unit {
    if points.length() == 0 {
      points.push(MarkerPoint::new(cur_x, cur_y))
    }
    let last_idx = points.length() - 1
    record_out(points, last_idx, out_dx, out_dy, eps)
    let end_point = MarkerPoint::new(end_x, end_y)
    let in_len = (in_dx * in_dx + in_dy * in_dy).sqrt()
    if in_len >= eps {
      end_point.has_in = true
      end_point.in_dx = in_dx
      end_point.in_dy = in_dy
    }
    points.push(end_point)
  }

  for cmd in commands {
    match cmd {
      MoveTo(x, y) => {
        finish_subpath(subpaths, points, closed)
        points = [MarkerPoint::new(x, y)]
        closed = false
        cur_x = x
        cur_y = y
        start_x = x
        start_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      MoveToRel(dx, dy) => {
        finish_subpath(subpaths, points, closed)
        let x = cur_x + dx
        let y = cur_y + dy
        points = [MarkerPoint::new(x, y)]
        closed = false
        cur_x = x
        cur_y = y
        start_x = x
        start_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      LineTo(x, y) => {
        let dx = x - cur_x
        let dy = y - cur_y
        add_segment(points, cur_x, cur_y, x, y, dx, dy, dx, dy, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      LineToRel(dx, dy) => {
        let x = cur_x + dx
        let y = cur_y + dy
        add_segment(points, cur_x, cur_y, x, y, dx, dy, dx, dy, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      HorizontalLineTo(x) => {
        let dx = x - cur_x
        add_segment(points, cur_x, cur_y, x, cur_y, dx, 0.0, dx, 0.0, eps)
        cur_x = x
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      HorizontalLineToRel(dx) => {
        let x = cur_x + dx
        add_segment(points, cur_x, cur_y, x, cur_y, dx, 0.0, dx, 0.0, eps)
        cur_x = x
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      VerticalLineTo(y) => {
        let dy = y - cur_y
        add_segment(points, cur_x, cur_y, cur_x, y, 0.0, dy, 0.0, dy, eps)
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      VerticalLineToRel(dy) => {
        let y = cur_y + dy
        add_segment(points, cur_x, cur_y, cur_x, y, 0.0, dy, 0.0, dy, eps)
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      CurveTo(x1, y1, x2, y2, x, y) => {
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy) => {
        let x1 = cur_x + dx1
        let y1 = cur_y + dy1
        let x2 = cur_x + dx2
        let y2 = cur_y + dy2
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      SmoothCurveTo(x2, y2, x, y) => {
        let x1 = if last_cmd_was_curve {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_curve {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      SmoothCurveToRel(dx2, dy2, dx, dy) => {
        let x1 = if last_cmd_was_curve {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_curve {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let x2 = cur_x + dx2
        let y2 = cur_y + dy2
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      QuadraticCurveTo(x1, y1, x, y) => {
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      QuadraticCurveToRel(dx1, dy1, dx, dy) => {
        let x1 = cur_x + dx1
        let y1 = cur_y + dy1
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      SmoothQuadraticCurveTo(x, y) => {
        let x1 = if last_cmd_was_quad {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_quad {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      SmoothQuadraticCurveToRel(dx, dy) => {
        let x1 = if last_cmd_was_quad {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_quad {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      ArcTo(rx, ry, rotation, large_arc, sweep, x, y) => {
        let (sx, sy, ex, ey) = compute_arc_tangents(
          cur_x, cur_y, rx, ry, rotation, large_arc, sweep, x, y,
        )
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) => {
        let x = cur_x + dx
        let y = cur_y + dy
        let (sx, sy, ex, ey) = compute_arc_tangents(
          cur_x, cur_y, rx, ry, rotation, large_arc, sweep, x, y,
        )
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      ClosePath => {
        if points.length() > 0 {
          let dx = start_x - cur_x
          let dy = start_y - cur_y
          let last_idx = points.length() - 1
          record_out(points, last_idx, dx, dy, eps)
          record_in(points, 0, dx, dy, eps)
          cur_x = start_x
          cur_y = start_y
          closed = true
        }
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
    }
  }
  finish_subpath(subpaths, points, closed)
  subpaths
}

///|
fn render_markers_for_path_commands(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if node.marker_start is None &&
    node.marker_mid is None &&
    node.marker_end is None {
    return
  }
  let subpaths = build_marker_subpaths(commands)
  if subpaths.length() == 0 {
    return
  }
  let eps = 0.0001
  let (sx, sy) = transform.get_scale()
  let skew = transform.a * transform.c + transform.b * transform.d
  let use_transformed = (sx - sy).abs() > eps || skew.abs() > eps
  let inv = transform.inverse()
  fn to_local_angle(angle : Double) -> Double {
    let dx = @math.cos(angle)
    let dy = @math.sin(angle)
    let lx = inv.a * dx + inv.c * dy
    let ly = inv.b * dx + inv.d * dy
    @math.atan2(ly, lx)
  }

  fn apply_vec(
    dx : Double,
    dy : Double,
    t : Transform,
    use_t : Bool,
  ) -> (Double, Double) {
    if use_t {
      (t.a * dx + t.c * dy, t.b * dx + t.d * dy)
    } else {
      (dx, dy)
    }
  }

  fn normalize(
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> (Double, Double, Double) {
    let len = (dx * dx + dy * dy).sqrt()
    if len < eps {
      (0.0, 0.0, len)
    } else {
      (dx / len, dy / len, len)
    }
  }

  fn angle_from_vec(
    dx : Double,
    dy : Double,
    use_t : Bool,
    t : Transform,
  ) -> Double {
    let (vx, vy) = apply_vec(dx, dy, t, use_t)
    let ang = @math.atan2(vy, vx)
    if use_t {
      to_local_angle(ang)
    } else {
      ang
    }
  }

  fn angle_mid_vec(
    in_dx : Double,
    in_dy : Double,
    out_dx : Double,
    out_dy : Double,
    eps : Double,
  ) -> Double {
    let (ux1, uy1, l1) = normalize(in_dx, in_dy, eps)
    let (ux2, uy2, l2) = normalize(out_dx, out_dy, eps)
    if l1 < eps && l2 < eps {
      0.0
    } else if l1 < eps {
      @math.atan2(out_dy, out_dx)
    } else if l2 < eps {
      @math.atan2(in_dy, in_dx)
    } else {
      let sx = ux1 + ux2
      let sy = uy1 + uy2
      if sx * sx + sy * sy < eps * eps {
        @math.atan2(out_dx, -out_dy)
      } else {
        @math.atan2(sy, sx)
      }
    }
  }

  let sub_last = subpaths.length() - 1
  for sub_idx in 0..<subpaths.length() {
    let sub = subpaths[sub_idx]
    if sub.points.length() < 2 {
      continue
    }
    let last = sub.points.length() - 1
    for i in 0..<sub.points.length() {
      let marker_id = if sub_idx == 0 && i == 0 {
        node.marker_start
      } else if sub_idx == sub_last && i == last {
        node.marker_end
      } else {
        node.marker_mid
      }
      match marker_id {
        Some(id) =>
          match resources.markers.get(id) {
            Some(marker) => {
              let p = sub.points[i]
              let angle = if i == 0 {
                if p.has_in && p.has_out {
                  let (in_dx, in_dy) = apply_vec(
                    p.in_dx,
                    p.in_dy,
                    transform,
                    use_transformed,
                  )
                  let (out_dx, out_dy) = apply_vec(
                    p.out_dx,
                    p.out_dy,
                    transform,
                    use_transformed,
                  )
                  let ang = angle_mid_vec(in_dx, in_dy, out_dx, out_dy, eps)
                  if use_transformed {
                    to_local_angle(ang)
                  } else {
                    ang
                  }
                } else if p.has_out {
                  angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
                } else if p.has_in {
                  angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
                } else {
                  0.0
                }
              } else if i == last {
                if p.has_in {
                  angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
                } else if p.has_out {
                  angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
                } else {
                  0.0
                }
              } else if p.has_in && p.has_out {
                let (in_dx, in_dy) = apply_vec(
                  p.in_dx,
                  p.in_dy,
                  transform,
                  use_transformed,
                )
                let (out_dx, out_dy) = apply_vec(
                  p.out_dx,
                  p.out_dy,
                  transform,
                  use_transformed,
                )
                let ang = angle_mid_vec(in_dx, in_dy, out_dx, out_dy, eps)
                if use_transformed {
                  to_local_angle(ang)
                } else {
                  ang
                }
              } else if p.has_in {
                angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
              } else if p.has_out {
                angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
              } else {
                0.0
              }
              render_marker_instance(
                marker,
                p.x,
                p.y,
                angle,
                node,
                transform,
                ctx,
                resources,
                node_color,
              )
            }
            None => ()
          }
        None => ()
      }
    }
  }
}

///|
fn is_closed_polyline(points : Array[(Int, Int)]) -> Bool {
  if points.length() < 2 {
    false
  } else {
    let last = points.length() - 1
    let (x0, y0) = points[0]
    let (x1, y1) = points[last]
    x0 == x1 && y0 == y1
  }
}

///|
fn polygon_area_int(points : Array[(Int, Int)]) -> Int {
  if points.length() < 3 {
    return 0
  }
  let mut area = 0
  let last = points.length() - 1
  for i in 0..<last {
    let (x0, y0) = points[i]
    let (x1, y1) = points[i + 1]
    area = area + (x0 * y1 - x1 * y0)
  }
  let (lx, ly) = points[last]
  let (fx, fy) = points[0]
  if lx != fx || ly != fy {
    area = area + (lx * fy - fx * ly)
  }
  area
}

///|
fn draw_polyline_joins_caps(
  points : Array[(Int, Int)],
  stroke_px : Int,
  linecap : LineCap,
  linejoin : LineJoin,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
  closed : Bool,
) -> Unit {
  if stroke_px <= 1 || points.length() < 2 {
    return
  }
  if closed {
    let mut count = points.length()
    if is_closed_polyline(points) {
      count = count - 1
    }
    if count < 2 {
      return
    }
    for i in 0..<count {
      let prev = if i == 0 { points[count - 1] } else { points[i - 1] }
      let cur = points[i]
      let next = if i + 1 == count { points[0] } else { points[i + 1] }
      draw_line_join(
        prev, cur, next, stroke_px, linejoin, miterlimit, color, setter,
      )
    }
  } else {
    for i = 1; i < points.length() - 1; i = i + 1 {
      draw_line_join(
        points[i - 1],
        points[i],
        points[i + 1],
        stroke_px,
        linejoin,
        miterlimit,
        color,
        setter,
      )
    }
    draw_line_cap_start(points[0], points[1], stroke_px, linecap, color, setter)
    let last = points.length() - 1
    draw_line_cap_end(
      points[last - 1],
      points[last],
      stroke_px,
      linecap,
      color,
      setter,
    )
  }
}

///|
fn draw_line_cap_start(
  p0 : (Int, Int),
  p1 : (Int, Int),
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  draw_line_cap(p0, p1, width, linecap, color, setter, true)
}

///|
fn draw_line_cap_end(
  p0 : (Int, Int),
  p1 : (Int, Int),
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  draw_line_cap(p0, p1, width, linecap, color, setter, false)
}

///|
fn draw_line_cap(
  p0 : (Int, Int),
  p1 : (Int, Int),
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
  is_start : Bool,
) -> Unit {
  if width <= 1 {
    return
  }
  match linecap {
    Butt => ()
    Round => {
      let (x, y) = if is_start { p0 } else { p1 }
      raster_circle_fill(x, y, width / 2, color, setter)
    }
    Square => {
      let (x0, y0) = p0
      let (x1, y1) = p1
      let dx = (x1 - x0).to_double()
      let dy = (y1 - y0).to_double()
      let len = (dx * dx + dy * dy).sqrt()
      if len < 0.001 {
        raster_circle_fill(x0, y0, width / 2, color, setter)
        return
      }
      let ux = dx / len
      let uy = dy / len
      let half_w = width / 2
      let ex = (ux * half_w.to_double()).to_int()
      let ey = (uy * half_w.to_double()).to_int()
      if is_start {
        raster_thick_line(x0 - ex, y0 - ey, x0, y0, width, color, setter)
      } else {
        raster_thick_line(x1, y1, x1 + ex, y1 + ey, width, color, setter)
      }
    }
  }
}

///|
fn draw_line_join(
  p0 : (Int, Int),
  p1 : (Int, Int),
  p2 : (Int, Int),
  width : Int,
  linejoin : LineJoin,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if width <= 1 {
    return
  }
  let (x0, y0) = p0
  let (x1, y1) = p1
  let (x2, y2) = p2
  let dx0 = (x1 - x0).to_double()
  let dy0 = (y1 - y0).to_double()
  let dx1 = (x2 - x1).to_double()
  let dy1 = (y2 - y1).to_double()
  let len0 = (dx0 * dx0 + dy0 * dy0).sqrt()
  let len1 = (dx1 * dx1 + dy1 * dy1).sqrt()
  if len0 < 0.001 || len1 < 0.001 {
    return
  }
  let ux0 = dx0 / len0
  let uy0 = dy0 / len0
  let ux1 = dx1 / len1
  let uy1 = dy1 / len1
  let cross = ux0 * uy1 - uy0 * ux1
  if cross.abs() < 0.0001 {
    return
  }
  let side = select_join_side(x1, y1, ux0, uy0, ux1, uy1, width)
  match linejoin {
    Round => raster_circle_fill(x1, y1, width / 2, color, setter)
    Bevel =>
      draw_bevel_join(x1, y1, ux0, uy0, ux1, uy1, side, width, color, setter)
    Miter =>
      draw_miter_join(
        x1, y1, ux0, uy0, ux1, uy1, side, width, miterlimit, color, setter,
      )
  }
}

///|
fn select_join_side(
  x1 : Int,
  y1 : Int,
  ux0 : Double,
  uy0 : Double,
  ux1 : Double,
  uy1 : Double,
  width : Int,
) -> Double {
  let half = width.to_double() / 2.0
  let side_a = 1.0
  let side_b = -1.0
  let len_a = compute_miter_len_for_side(
    x1, y1, ux0, uy0, ux1, uy1, side_a, half,
  )
  let len_b = compute_miter_len_for_side(
    x1, y1, ux0, uy0, ux1, uy1, side_b, half,
  )
  if len_a < 0.0 && len_b < 0.0 {
    side_a
  } else if len_a < 0.0 {
    side_b
  } else if len_b < 0.0 {
    side_a
  } else if len_a >= len_b {
    side_a
  } else {
    side_b
  }
}

///|
fn compute_miter_len_for_side(
  x1 : Int,
  y1 : Int,
  ux0 : Double,
  uy0 : Double,
  ux1 : Double,
  uy1 : Double,
  side : Double,
  half : Double,
) -> Double {
  let ox0 = x1.to_double() + side * -uy0 * half
  let oy0 = y1.to_double() + side * ux0 * half
  let ox1 = x1.to_double() + side * -uy1 * half
  let oy1 = y1.to_double() + side * ux1 * half
  let denom = ux0 * uy1 - uy0 * ux1
  if denom.abs() < 0.0001 {
    return -1.0
  }
  let t = ((ox1 - ox0) * uy1 - (oy1 - oy0) * ux1) / denom
  let ix = ox0 + t * ux0
  let iy = oy0 + t * uy0
  let dx = ix - x1.to_double()
  let dy = iy - y1.to_double()
  (dx * dx + dy * dy).sqrt() / half
}

///|
fn draw_bevel_join(
  x1 : Int,
  y1 : Int,
  ux0 : Double,
  uy0 : Double,
  ux1 : Double,
  uy1 : Double,
  side : Double,
  width : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let half = width.to_double() / 2.0
  let ox0 = x1.to_double() + side * -uy0 * half
  let oy0 = y1.to_double() + side * ux0 * half
  let ox1 = x1.to_double() + side * -uy1 * half
  let oy1 = y1.to_double() + side * ux1 * half
  let points : Array[(Int, Int)] = [
    (ox0.to_int(), oy0.to_int()),
    (ox1.to_int(), oy1.to_int()),
    (x1, y1),
  ]
  raster_polygon_fill(points, color, setter)
}

///|
fn draw_miter_join(
  x1 : Int,
  y1 : Int,
  ux0 : Double,
  uy0 : Double,
  ux1 : Double,
  uy1 : Double,
  side : Double,
  width : Int,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let half = width.to_double() / 2.0
  let ox0 = x1.to_double() + side * -uy0 * half
  let oy0 = y1.to_double() + side * ux0 * half
  let ox1 = x1.to_double() + side * -uy1 * half
  let oy1 = y1.to_double() + side * ux1 * half
  // Intersection of offset lines
  let denom = ux0 * uy1 - uy0 * ux1
  if denom.abs() < 0.0001 {
    draw_bevel_join(x1, y1, ux0, uy0, ux1, uy1, side, width, color, setter)
    return
  }
  let px = ox0
  let py = oy0
  let qx = ox1
  let qy = oy1
  let t = ((qx - px) * uy1 - (qy - py) * ux1) / denom
  let ix = px + t * ux0
  let iy = py + t * uy0
  let dx = ix - x1.to_double()
  let dy = iy - y1.to_double()
  let miter_len = (dx * dx + dy * dy).sqrt() / half
  if miter_len > miterlimit {
    draw_bevel_join(x1, y1, ux0, uy0, ux1, uy1, side, width, color, setter)
    return
  }
  let points : Array[(Int, Int)] = [
    (ox0.to_int(), oy0.to_int()),
    (ix.to_int(), iy.to_int()),
    (ox1.to_int(), oy1.to_int()),
  ]
  raster_polygon_fill(points, color, setter)
}

///|
fn render_polyline(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if points.length() < 2 {
    return
  }
  let transformed = points.map(fn(p) {
    let (x, y) = transform.apply(p.0, p.1)
    (x.to_int(), y.to_int())
  })
  let (sx, sy) = transform.get_scale()
  let stroke_px = if node.stroke.width > 0.0 {
    ceil_to_int(node.stroke.width * (sx + sy) / 2.0)
  } else {
    0
  }
  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && stroke_px > 0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          if stroke_px <= 1 {
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
          } else {
            for i = 0; i < transformed.length() - 1; i = i + 1 {
              let (x1, y1) = transformed[i]
              let (x2, y2) = transformed[i + 1]
              raster_thick_line(
                x1,
                y1,
                x2,
                y2,
                stroke_px,
                stroke_color,
                ctx.setter,
              )
            }
            draw_polyline_joins_caps(
              transformed,
              stroke_px,
              node.stroke.linecap,
              node.stroke.linejoin,
              node.stroke.miterlimit,
              stroke_color,
              ctx.setter,
              false,
            )
          }
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_polylines(
      [points],
      node,
      transform,
      ctx,
      resources,
      node_color,
    )
  }

  render_paint_order(node.paint_order, () => (), draw_stroke, draw_markers)
}

///|
fn render_polygon(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  if points.length() < 3 {
    return
  }
  let transformed = points.map(fn(p) {
    let (x, y) = transform.apply(p.0, p.1)
    (x.to_int(), y.to_int())
  })
  let (sx, sy) = transform.get_scale()
  let stroke_px = if node.stroke.width > 0.0 {
    ceil_to_int(node.stroke.width * (sx + sy) / 2.0)
  } else {
    0
  }
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_polygon_fill_rule(
            transformed,
            fill_color,
            node.fill_rule,
            ctx.setter,
          )
        }
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          render_pattern_fill(
            node.shape,
            transform,
            ctx,
            pattern,
            node.fill_opacity * node.opacity,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && stroke_px > 0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          if stroke_px <= 1 {
            raster_polygon_stroke(transformed, stroke_color, ctx.setter)
          } else {
            let n = transformed.length()
            for i in 0..<n {
              let j = (i + 1) % n
              let (x1, y1) = transformed[i]
              let (x2, y2) = transformed[j]
              raster_thick_line(
                x1,
                y1,
                x2,
                y2,
                stroke_px,
                stroke_color,
                ctx.setter,
              )
            }
            draw_polyline_joins_caps(
              transformed,
              stroke_px,
              node.stroke.linecap,
              node.stroke.linejoin,
              node.stroke.miterlimit,
              stroke_color,
              ctx.setter,
              true,
            )
          }
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_polylines(
      [points],
      node,
      transform,
      ctx,
      resources,
      node_color,
    )
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, draw_markers)
}

///|
fn render_path(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  // Convert to polylines with transform
  let polylines = path_to_polylines(commands, ctx.flatness)
  let transformed_polylines : Array[Array[(Int, Int)]] = []
  for polyline in polylines {
    let transformed = polyline.map(fn(p) {
      let (x, y) = transform.apply(p.0, p.1)
      (x.to_int(), y.to_int())
    })
    transformed_polylines.push(transformed)
  }
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          let fill_polylines : Array[Array[(Int, Int)]] = []
          for polyline in transformed_polylines {
            if polyline.length() >= 3 {
              let area = polygon_area_int(polyline)
              if area == 0 {
                continue
              }
              fill_polylines.push(polyline)
            }
          }
          if fill_polylines.length() > 0 {
            raster_polygons_fill_rule(
              fill_polylines,
              fill_color,
              node.fill_rule,
              ctx.setter,
            )
          }
        }
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          render_pattern_fill(
            node.shape,
            transform,
            ctx,
            pattern,
            node.fill_opacity * node.opacity,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    let (sx, sy) = transform.get_scale()
    let stroke_px = if node.stroke.width > 0.0 {
      ceil_to_int(node.stroke.width * (sx + sy) / 2.0)
    } else {
      0
    }
    for polyline in transformed_polylines {
      match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
        ResolvedPaint::SolidColor(color) =>
          if node.stroke_opacity > 0.0 && stroke_px > 0 {
            let stroke_color = apply_opacity(
              color,
              node.stroke_opacity * node.opacity,
            )
            if stroke_px <= 1 {
              raster_polyline(polyline, stroke_color, ctx.setter)
            } else {
              for i = 0; i < polyline.length() - 1; i = i + 1 {
                let (x1, y1) = polyline[i]
                let (x2, y2) = polyline[i + 1]
                raster_thick_line(
                  x1,
                  y1,
                  x2,
                  y2,
                  stroke_px,
                  stroke_color,
                  ctx.setter,
                )
              }
              let closed = is_closed_polyline(polyline)
              draw_polyline_joins_caps(
                polyline,
                stroke_px,
                node.stroke.linecap,
                node.stroke.linejoin,
                node.stroke.miterlimit,
                stroke_color,
                ctx.setter,
                closed,
              )
            }
          }
        _ => ()
      }
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_path_commands(
      commands, node, transform, ctx, resources, node_color,
    )
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, draw_markers)
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
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  let (tx, ty) = transform.apply(x, y)
  let (sx, _) = transform.get_scale()
  let scaled_size = (font_size * sx).to_int()
  // Fill color for text
  let fill_paint = resolve_paint_for_render(node.fill, node_color, resources)
  match ctx.text_to_paths {
    Some(to_paths) => {
      // Use font callback: render each character as path commands
      let fill_color : Color? = match fill_paint {
        ResolvedPaint::SolidColor(color) =>
          if node.fill_opacity > 0.0 {
            Some(apply_opacity(color, node.fill_opacity * node.opacity))
          } else {
            None
          }
        _ => None
      }
      let mut cursor_x = tx
      for i in 0..<text.length() {
        let codepoint = text[i].unsafe_to_char().to_int()
        let (cmds, advance) = to_paths(codepoint, font_size * sx)
        // Translate commands to cursor position
        let translated = translate_path_commands(cmds, cursor_x, ty)
        raster_path(translated, fill_color, None, ctx.flatness, ctx.setter)
        cursor_x = cursor_x + advance
      }
    }
    None =>
      // Fallback: bitmap font
      match fill_paint {
        ResolvedPaint::SolidColor(color) =>
          if node.fill_opacity > 0.0 {
            let fill_color = apply_opacity(
              color,
              node.fill_opacity * node.opacity,
            )
            raster_text(
              tx.to_int(),
              ty.to_int(),
              text,
              scaled_size,
              fill_color,
              ctx.setter,
            )
          }
        ResolvedPaint::Pattern(pattern) =>
          if node.fill_opacity > 0.0 {
            render_pattern_fill(
              node.shape,
              transform,
              ctx,
              pattern,
              node.fill_opacity * node.opacity,
            )
          }
        _ => ()
      }
  }
}

///|
/// Translate path commands by (dx, dy) offset
fn translate_path_commands(
  commands : Array[PathCommand],
  dx : Double,
  dy : Double,
) -> Array[PathCommand] {
  let result : Array[PathCommand] = []
  for cmd in commands {
    let translated : PathCommand = match cmd {
      MoveTo(x, y) => MoveTo(x + dx, y + dy)
      LineTo(x, y) => LineTo(x + dx, y + dy)
      QuadraticCurveTo(cx, cy, x, y) =>
        QuadraticCurveTo(cx + dx, cy + dy, x + dx, y + dy)
      CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        CurveTo(cx1 + dx, cy1 + dy, cx2 + dx, cy2 + dy, x + dx, y + dy)
      ClosePath => ClosePath
      other => other
    }
    result.push(translated)
  }
  result
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
  { setter, width, height, flatness: 0.5, clip: None, text_to_paths: None }
}

///|
/// Create a RenderContext with clipping
pub fn RenderContext::with_clip(
  setter : PixelSetter,
  width : Int,
  height : Int,
  clip : ClipRect,
) -> RenderContext {
  {
    setter,
    width,
    height,
    flatness: 0.5,
    clip: Some(clip),
    text_to_paths: None,
  }
}

///|
/// Create a RenderContext with font callback for text rendering
pub fn RenderContext::with_font(
  setter : PixelSetter,
  width : Int,
  height : Int,
  text_to_paths : (Int, Double) -> (Array[PathCommand], Double),
) -> RenderContext {
  {
    setter,
    width,
    height,
    flatness: 0.5,
    clip: None,
    text_to_paths: Some(text_to_paths),
  }
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
    text_to_paths: None,
  }
}

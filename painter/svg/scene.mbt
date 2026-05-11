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
    if !tween.is_complete() {
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
    if !tween.is_complete() {
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
  svg_scene_from_msvg(@msvg.Scene::empty())
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
  bounding_box_from_msvg(scene_to_msvg(self).get_bounds())
}

///|
/// Compute the dirty region (union of all dirty node bounds)
pub fn Scene::get_dirty_region(self : Scene) -> BoundingBox {
  bounding_box_from_msvg(scene_to_msvg(self).get_dirty_region())
}

///|
/// Render only nodes that intersect with the dirty region
pub fn Scene::render_dirty(self : Scene, ctx : RenderContext) -> BoundingBox {
  let scene = scene_to_msvg(self)
  let dirty_region = bounding_box_from_msvg(
    scene.render_dirty(render_context_to_msvg(ctx)),
  )
  copy_svg_scene_dirty_state_from_msvg(self, scene)
  dirty_region
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
  let scene = scene_to_msvg(self)
  scene.render(render_context_to_msvg(ctx))
  self.clear_dirty()
}

///|
/// Render the scene with a camera transform
pub fn Scene::render_with_camera(
  self : Scene,
  ctx : RenderContext,
  camera : Camera,
) -> Unit {
  let scene = scene_to_msvg(self)
  scene.render_with_camera(render_context_to_msvg(ctx), camera_to_msvg(camera))
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
  let scene = scene_to_msvg(self)
  scene.render_with_viewbox(
    render_context_to_msvg(ctx),
    view_box_to_msvg(viewbox),
    preserve_aspect_ratio.to_msvg(),
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
  let scene = scene_to_msvg(self)
  scene.render_with_viewbox_and_camera(
    render_context_to_msvg(ctx),
    view_box_to_msvg(viewbox),
    preserve_aspect_ratio.to_msvg(),
    camera_to_msvg(camera),
  )
  self.clear_dirty()
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
  svg_node_from_msvg(@msvg.rect(id, x, y, width, height))
}

///|
/// Helper: Create a circle node
pub fn circle(id : String, cx : Double, cy : Double, r : Double) -> SVGNode {
  svg_node_from_msvg(@msvg.circle(id, cx, cy, r))
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
  svg_node_from_msvg(@msvg.line(id, x1, y1, x2, y2))
}

///|
/// Helper: Create a path node from path data string
pub fn path(id : String, d : String) -> SVGNode {
  svg_node_from_msvg(@msvg.path(id, d))
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
  svg_node_from_msvg(@msvg.text(id, x, y, content, font_size))
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
  render_context_from_msvg(
    @msvg.RenderContext::new(pixel_setter_to_msvg(setter), width, height),
  )
}

///|
/// Create a RenderContext with clipping
pub fn RenderContext::with_clip(
  setter : PixelSetter,
  width : Int,
  height : Int,
  clip : ClipRect,
) -> RenderContext {
  render_context_from_msvg(
    @msvg.RenderContext::with_clip(
      pixel_setter_to_msvg(setter),
      width,
      height,
      clip_rect_to_msvg(clip),
    ),
  )
}

///|
/// Create a RenderContext for a camera
pub fn RenderContext::for_camera(
  setter : PixelSetter,
  camera : Camera,
) -> RenderContext {
  render_context_from_msvg(
    @msvg.RenderContext::for_camera(
      pixel_setter_to_msvg(setter),
      camera_to_msvg(camera),
    ),
  )
}

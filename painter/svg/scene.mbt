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
  Scene::from_msvg(@msvg.Scene::empty())
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
fn Scene::sync_animation_state_from_msvg(
  self : Scene,
  source : @msvg.Scene,
) -> Unit {
  self.dirty = source.dirty
  self.root.sync_animation_tree_state_from_msvg(source.root)
}

///|
fn Scene::to_msvg(self : Scene) -> @msvg.Scene {
  @msvg.Scene::{ root: self.root.to_msvg(), dirty: self.dirty }
}

///|
fn Scene::from_msvg(scene : @msvg.Scene) -> Scene {
  { root: SVGNode::from_msvg(scene.root), dirty: scene.dirty }
}

///|
fn Scene::sync_dirty_state_from_msvg(
  self : Scene,
  source : @msvg.Scene,
) -> Unit {
  self.dirty = source.dirty
  self.root.sync_dirty_state_from_msvg(source.root)
}

///|
fn Scene::sync_z_order_state_from_msvg(
  self : Scene,
  source : @msvg.Scene,
) -> Unit {
  self.dirty = source.dirty
  self.root.sync_z_order_state_from_msvg(source.root)
}

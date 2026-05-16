///|
/// Compute the bounding box of the entire scene
pub fn Scene::get_bounds(self : Scene) -> BoundingBox {
  BoundingBox::from_msvg(self.to_msvg().get_bounds())
}

///|
/// Compute the dirty region (union of all dirty node bounds)
pub fn Scene::get_dirty_region(self : Scene) -> BoundingBox {
  BoundingBox::from_msvg(self.to_msvg().get_dirty_region())
}

///|
/// Render only nodes that intersect with the dirty region
pub fn Scene::render_dirty(self : Scene, ctx : RenderContext) -> BoundingBox {
  let scene = self.to_msvg()
  let dirty_region = BoundingBox::from_msvg(
    scene.render_dirty(ctx.to_msvg()),
  )
  self.sync_dirty_state_from_msvg(scene)
  dirty_region
}

///|
/// Mark a node and its ancestors as dirty
pub fn Scene::mark_node_dirty(self : Scene, id : String) -> Bool {
  let scene = self.to_msvg()
  let found = scene.mark_node_dirty(id)
  self.sync_dirty_state_from_msvg(scene)
  found
}

///|
/// Clear all dirty flags in the scene
pub fn Scene::clear_all_dirty(self : Scene) -> Unit {
  let scene = self.to_msvg()
  scene.clear_all_dirty()
  self.sync_dirty_state_from_msvg(scene)
}

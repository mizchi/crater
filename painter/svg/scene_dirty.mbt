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
  let scene = scene_to_msvg(self)
  let found = scene.mark_node_dirty(id)
  copy_svg_scene_dirty_state_from_msvg(self, scene)
  found
}

///|
/// Clear all dirty flags in the scene
pub fn Scene::clear_all_dirty(self : Scene) -> Unit {
  let scene = scene_to_msvg(self)
  scene.clear_all_dirty()
  copy_svg_scene_dirty_state_from_msvg(self, scene)
}

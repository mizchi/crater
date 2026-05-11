///|
/// Set z_index of a node by ID
pub fn Scene::set_z_index(self : Scene, id : String, z_index : Int) -> Bool {
  let scene = scene_to_msvg(self)
  let found = scene.set_z_index(id, z_index)
  copy_svg_scene_z_order_state_from_msvg(self, scene)
  found
}

///|
/// Bring a node to front (set z_index higher than all siblings)
pub fn Scene::bring_to_front(self : Scene, id : String) -> Bool {
  let scene = scene_to_msvg(self)
  let found = scene.bring_to_front(id)
  copy_svg_scene_z_order_state_from_msvg(self, scene)
  found
}

///|
/// Send a node to back (set z_index lower than all siblings)
pub fn Scene::send_to_back(self : Scene, id : String) -> Bool {
  let scene = scene_to_msvg(self)
  let found = scene.send_to_back(id)
  copy_svg_scene_z_order_state_from_msvg(self, scene)
  found
}

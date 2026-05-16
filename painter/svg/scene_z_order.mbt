///|
/// Set z_index of a node by ID
pub fn Scene::set_z_index(self : Scene, id : String, z_index : Int) -> Bool {
  let scene = self.to_msvg()
  let found = scene.set_z_index(id, z_index)
  self.sync_z_order_state_from_msvg(scene)
  found
}

///|
/// Bring a node to front (set z_index higher than all siblings)
pub fn Scene::bring_to_front(self : Scene, id : String) -> Bool {
  let scene = self.to_msvg()
  let found = scene.bring_to_front(id)
  self.sync_z_order_state_from_msvg(scene)
  found
}

///|
/// Send a node to back (set z_index lower than all siblings)
pub fn Scene::send_to_back(self : Scene, id : String) -> Bool {
  let scene = self.to_msvg()
  let found = scene.send_to_back(id)
  self.sync_z_order_state_from_msvg(scene)
  found
}

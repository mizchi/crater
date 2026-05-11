// ============================================================================
// ClipPath
// ============================================================================

///|
/// Clip path definition
pub(all) struct ClipPath {
  id : String
  shape : Shape // The clipping shape
  transform : Transform
  clip_rule : FillRule // nonzero or evenodd
}

///|
pub fn ClipPath::new(id : String, shape : Shape) -> ClipPath {
  clip_path_from_msvg(@msvg.ClipPath::new(id, shape_to_msvg(shape)))
}

///|
pub fn ClipPath::with_transform(
  id : String,
  shape : Shape,
  transform : Transform,
) -> ClipPath {
  clip_path_from_msvg(
    @msvg.ClipPath::with_transform(
      id,
      shape_to_msvg(shape),
      transform.to_msvg(),
    ),
  )
}

///|
/// Check if a point is inside the clip path
pub fn ClipPath::contains(self : ClipPath, x : Double, y : Double) -> Bool {
  clip_path_to_msvg(self).contains(x, y)
}

///|
/// Clip path registry for referencing by ID
pub(all) struct ClipPathRegistry {
  clips : Map[String, ClipPath]
}

///|
pub fn ClipPathRegistry::new() -> ClipPathRegistry {
  { clips: {} }
}

///|
pub fn ClipPathRegistry::add(self : ClipPathRegistry, clip : ClipPath) -> Unit {
  self.clips.set(clip.id, clip)
}

///|
pub fn ClipPathRegistry::get(self : ClipPathRegistry, id : String) -> ClipPath? {
  self.clips.get(id)
}

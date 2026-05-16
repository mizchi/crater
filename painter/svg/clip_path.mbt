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
  ClipPath::from_msvg(@msvg.ClipPath::new(id, shape.to_msvg()))
}

///|
pub fn ClipPath::with_transform(
  id : String,
  shape : Shape,
  transform : Transform,
) -> ClipPath {
  ClipPath::from_msvg(
    @msvg.ClipPath::with_transform(
      id,
      shape.to_msvg(),
      transform.to_msvg(),
    ),
  )
}

///|
/// Check if a point is inside the clip path
pub fn ClipPath::contains(self : ClipPath, x : Double, y : Double) -> Bool {
  self.to_msvg().contains(x, y)
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

///|
fn ClipPath::from_msvg(clip : @msvg.ClipPath) -> ClipPath {
  {
    id: clip.id,
    shape: Shape::from_msvg(clip.shape),
    transform: Transform::from_msvg(clip.transform),
    clip_rule: FillRule::from_msvg(clip.clip_rule),
  }
}

///|
fn ClipPath::to_msvg(self : ClipPath) -> @msvg.ClipPath {
  @msvg.ClipPath::{
    id: self.id,
    shape: self.shape.to_msvg(),
    transform: self.transform.to_msvg(),
    clip_rule: self.clip_rule.to_msvg(),
    units: @msvg.ClipPathUnits::UserSpaceOnUse,
  }
}

// ============================================================================
// Mask
// ============================================================================

///|
/// Mask content units
pub(all) enum MaskUnits {
  UserSpaceOnUse // Coordinates relative to current user space
  ObjectBoundingBox // Coordinates relative to bounding box (0-1)
} derive(Eq, Debug)

///|
pub impl Show for MaskUnits with output(self, logger) {
  let name = match self {
    UserSpaceOnUse => "UserSpaceOnUse"
    ObjectBoundingBox => "ObjectBoundingBox"
  }
  logger.write_string(name)
}

///|
/// Mask type - how mask values are interpreted
pub(all) enum MaskType {
  Luminance // Use luminance (brightness) as mask value
  Alpha // Use alpha channel as mask value
} derive(Eq, Debug)

///|
pub impl Show for MaskType with output(self, logger) {
  let name = match self {
    Luminance => "Luminance"
    Alpha => "Alpha"
  }
  logger.write_string(name)
}

///|
/// Mask definition for transparency masking
pub(all) struct Mask {
  id : String
  content : Array[SVGNode] // Mask content (rendered to get mask values)
  x : Double // Mask region x
  y : Double // Mask region y
  width : Double // Mask region width
  height : Double // Mask region height
  mask_units : MaskUnits
  mask_content_units : MaskUnits
  mask_type : MaskType
}

///|
pub fn Mask::new(id : String, content : Array[SVGNode]) -> Mask {
  Mask::from_msvg(@msvg.Mask::new(id, []), content)
}

///|
pub fn Mask::with_bounds(
  id : String,
  content : Array[SVGNode],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Mask {
  Mask::from_msvg(@msvg.Mask::with_bounds(id, [], x, y, width, height), content)
}

///|
/// Compute mask value (0.0-1.0) at a point using luminance
pub fn compute_luminance(color : Color) -> Double {
  @msvg.compute_luminance(color.to_msvg())
}

///|
/// Compute mask value using alpha channel
pub fn compute_alpha_mask(color : Color) -> Double {
  @msvg.compute_alpha_mask(color.to_msvg())
}

///|
/// Mask registry for referencing by ID
pub(all) struct MaskRegistry {
  masks : Map[String, Mask]
}

///|
pub fn MaskRegistry::new() -> MaskRegistry {
  { masks: {} }
}

///|
pub fn MaskRegistry::add(self : MaskRegistry, mask : Mask) -> Unit {
  self.masks.set(mask.id, mask)
}

///|
pub fn MaskRegistry::get(self : MaskRegistry, id : String) -> Mask? {
  self.masks.get(id)
}

///|
/// Get the mask region bounds for a given target bounds
pub fn Mask::get_mask_bounds(self : Mask, target : BoundingBox) -> BoundingBox {
  BoundingBox::from_msvg(
    self.to_msvg().get_mask_bounds(target.to_msvg()),
  )
}

///|
/// Apply mask to an image using luminance or alpha
pub fn apply_mask_to_image(
  image : Image,
  mask_buffer : Image,
  mask_type : MaskType,
) -> Image {
  Image::from_msvg(
    @msvg.apply_mask_to_image(
      image.to_msvg(),
      mask_buffer.to_msvg(),
      mask_type.to_msvg(),
    ),
  )
}

///|
fn MaskUnits::from_msvg(units : @msvg.MaskUnits) -> MaskUnits {
  match units {
    UserSpaceOnUse => UserSpaceOnUse
    ObjectBoundingBox => ObjectBoundingBox
  }
}

///|
fn MaskUnits::to_msvg(self : MaskUnits) -> @msvg.MaskUnits {
  match self {
    UserSpaceOnUse => @msvg.MaskUnits::UserSpaceOnUse
    ObjectBoundingBox => @msvg.MaskUnits::ObjectBoundingBox
  }
}

///|
fn MaskType::from_msvg(mask_type : @msvg.MaskType) -> MaskType {
  match mask_type {
    Luminance => Luminance
    Alpha => Alpha
  }
}

///|
fn MaskType::to_msvg(self : MaskType) -> @msvg.MaskType {
  match self {
    Luminance => @msvg.MaskType::Luminance
    Alpha => @msvg.MaskType::Alpha
  }
}

///|
fn Mask::from_msvg(mask : @msvg.Mask, content : Array[SVGNode]) -> Mask {
  {
    id: mask.id,
    content,
    x: mask.x,
    y: mask.y,
    width: mask.width,
    height: mask.height,
    mask_units: MaskUnits::from_msvg(mask.mask_units),
    mask_content_units: MaskUnits::from_msvg(mask.mask_content_units),
    mask_type: MaskType::from_msvg(mask.mask_type),
  }
}

///|
fn Mask::to_msvg(self : Mask) -> @msvg.Mask {
  @msvg.Mask::{
    id: self.id,
    content: [],
    x: self.x,
    y: self.y,
    width: self.width,
    height: self.height,
    x_is_percent: false,
    y_is_percent: false,
    width_is_percent: false,
    height_is_percent: false,
    mask_units: self.mask_units.to_msvg(),
    mask_content_units: self.mask_content_units.to_msvg(),
    mask_type: self.mask_type.to_msvg(),
  }
}

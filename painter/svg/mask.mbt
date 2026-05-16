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
  mask_from_msvg(@msvg.Mask::new(id, []), content)
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
  mask_from_msvg(@msvg.Mask::with_bounds(id, [], x, y, width, height), content)
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
  bounding_box_from_msvg(
    mask_to_msvg(self).get_mask_bounds(bounding_box_to_msvg(target)),
  )
}

///|
/// Apply mask to an image using luminance or alpha
pub fn apply_mask_to_image(
  image : Image,
  mask_buffer : Image,
  mask_type : MaskType,
) -> Image {
  image_from_msvg(
    @msvg.apply_mask_to_image(
      image_to_msvg(image),
      image_to_msvg(mask_buffer),
      mask_type_to_msvg(mask_type),
    ),
  )
}

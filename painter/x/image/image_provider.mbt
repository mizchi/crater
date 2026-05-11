///|
pub(all) struct RasterImage {
  width : Int
  height : Int
  rgba : Array[Int]
}

///|
pub(all) enum ResolvedImage {
  Raster(RasterImage)
  Svg(String)
}

///|
pub(all) struct ImageProvider {
  resolve : (String) -> ResolvedImage?
}

///|
let image_provider_override : Ref[ImageProvider?] = { val: None }

///|
pub fn set_image_provider(provider : ImageProvider) -> Unit {
  image_provider_override.val = Some(provider)
}

///|
pub fn clear_image_provider() -> Unit {
  image_provider_override.val = None
}

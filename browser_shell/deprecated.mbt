///|
/// Compatibility facade. Prefer @terminal_image_cache.ImageCache directly.
pub using @terminal_image_cache {type ImageCache}

///|
/// Compatibility facade. Prefer @html_assets.extract_img_srcs directly.
pub fn extract_img_srcs(html : String) -> Array[String] {
  @html_assets.extract_img_srcs(html)
}

///|
/// Compatibility facade. Prefer @terminal_image_cache types directly.
pub using @terminal_image_cache {
  type RgbaCacheEntry,
  type TerminalImageCacheEntry,
}

///|
/// Compatibility facade. Prefer @terminal_image_cache.data_image_src_to_kitty_cache directly.
pub fn data_image_src_to_kitty_cache(src : String) -> String? {
  @terminal_image_cache.data_image_src_to_kitty_cache(src)
}

///|
/// Compatibility facade. Prefer @terminal_image_cache.decode_raster_image_to_rgba_cache_entry directly.
pub fn decode_raster_image_to_rgba_cache_entry(
  image_format : String,
  b64_data : String,
) -> RgbaCacheEntry? {
  @terminal_image_cache.decode_raster_image_to_rgba_cache_entry(
    image_format, b64_data,
  )
}

///|
/// Compatibility facade. Prefer @terminal_image_cache.detect_raster_image_format_from_base64 directly.
pub fn detect_raster_image_format_from_base64(b64_data : String) -> String {
  @terminal_image_cache.detect_raster_image_format_from_base64(b64_data)
}

///|
/// Compatibility facade. Prefer @terminal_image_cache.normalize_raster_image_for_kitty directly.
pub fn normalize_raster_image_for_kitty(b64_data : String) -> String {
  @terminal_image_cache.normalize_raster_image_for_kitty(b64_data)
}

///|
/// Compatibility facade. Prefer @terminal_image_cache.parse_terminal_image_cache_entry directly.
pub fn parse_terminal_image_cache_entry(
  cached_data : String,
) -> TerminalImageCacheEntry? {
  @terminal_image_cache.parse_terminal_image_cache_entry(cached_data)
}

///|
/// Compatibility facade. Prefer @terminal_image_cache.prepare_raster_image_for_kitty_cache directly.
pub fn prepare_raster_image_for_kitty_cache(b64_data : String) -> String {
  @terminal_image_cache.prepare_raster_image_for_kitty_cache(b64_data)
}

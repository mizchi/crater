///|
/// Raster image source resolution and region blitting helpers.

///|
fn resolve_image_src(src : String) -> ResolvedImage? {
  match image_provider_override.val {
    Some(provider) =>
      match (provider.resolve)(src) {
        Some(image) => Some(image)
        None =>
          if src.has_prefix("data:image/svg+xml") {
            let svg_text = decode_svg_data_uri(src)
            if svg_text.length() > 0 {
              Some(ResolvedImage::Svg(svg_text))
            } else {
              None
            }
          } else {
            None
          }
      }
    None =>
      if src.has_prefix("data:image/svg+xml") {
        let svg_text = decode_svg_data_uri(src)
        if svg_text.length() > 0 {
          Some(ResolvedImage::Svg(svg_text))
        } else {
          None
        }
      } else {
        None
      }
  }
}

///|
fn render_image_src_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  src : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
  opacity : Double,
) -> Bool {
  match resolve_image_src(src) {
    Some(ResolvedImage::Raster(image)) =>
      render_raster_image_into_region(
        fb, palette, image, x, y, w, h, clip, opacity,
      )
    Some(ResolvedImage::Svg(svg_text)) =>
      if svg_text.length() > 0 {
        render_svg_into_region(fb, palette, svg_text, x, y, w, h, clip)
        true
      } else {
        false
      }
    None => false
  }
}

///|
fn render_raster_image_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  image : RasterImage,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
  opacity : Double,
) -> Bool {
  if image.width <= 0 ||
    image.height <= 0 ||
    w <= 0 ||
    h <= 0 ||
    image.rgba.length() < image.width * image.height * 4 {
    return false
  }
  for py = 0; py < h; py = py + 1 {
    let dst_y = y + py
    if dst_y < 0 || dst_y >= fb.height {
      continue
    }
    let src_y = (py * image.height / h).min(image.height - 1)
    for px = 0; px < w; px = px + 1 {
      let dst_x = x + px
      if dst_x < 0 || dst_x >= fb.width {
        continue
      }
      if !pixel_in_clip(clip, dst_x, dst_y) {
        continue
      }
      let src_x = (px * image.width / w).min(image.width - 1)
      let idx = (src_y * image.width + src_x) * 4
      let alpha = clamp_byte(
        (image.rgba[idx + 3].to_double() * opacity).to_int(),
      )
      if alpha <= 0 {
        continue
      }
      blend_raster_color_over_pixel(
        fb,
        palette,
        dst_x,
        dst_y,
        {
          r: clamp_byte(image.rgba[idx]),
          g: clamp_byte(image.rgba[idx + 1]),
          b: clamp_byte(image.rgba[idx + 2]),
        },
        alpha,
      )
    }
  }
  true
}

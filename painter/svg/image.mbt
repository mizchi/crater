// ============================================================================
// Image Support
// ============================================================================

///|
/// Image data (RGBA pixels)
pub(all) struct Image {
  width : Int
  height : Int
  pixels : Array[Color] // Row-major order
}

///|
/// Create a new image with specified dimensions
pub fn Image::new(width : Int, height : Int) -> Image {
  image_from_msvg(@msvg.Image::new(width, height))
}

///|
/// Create an image filled with a color
pub fn Image::filled(width : Int, height : Int, color : Color) -> Image {
  image_from_msvg(@msvg.Image::filled(width, height, color_to_msvg(color)))
}

///|
/// Get pixel at coordinates
pub fn Image::get_pixel(self : Image, x : Int, y : Int) -> Color {
  color_from_msvg(image_to_msvg(self).get_pixel(x, y))
}

///|
/// Set pixel at coordinates
pub fn Image::set_pixel(self : Image, x : Int, y : Int, color : Color) -> Unit {
  let image = image_to_msvg(self)
  image.set_pixel(x, y, color_to_msvg(color))
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Fill a rectangle region
pub fn Image::fill_rect(
  self : Image,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
) -> Unit {
  let image = image_to_msvg(self)
  image.fill_rect(x, y, w, h, color_to_msvg(color))
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Clear image to transparent
pub fn Image::clear(self : Image) -> Unit {
  let image = image_to_msvg(self)
  image.clear()
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Clone the image
pub fn Image::clone(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).clone())
}

///|
/// Apply blur filter in place
pub fn Image::apply_blur_in_place(self : Image, radius : Int) -> Unit {
  let image = image_to_msvg(self)
  image.apply_blur_in_place(radius)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply brightness filter in place
pub fn Image::apply_brightness_in_place(self : Image, factor : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_brightness_in_place(factor)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply contrast filter in place
pub fn Image::apply_contrast_in_place(self : Image, factor : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_contrast_in_place(factor)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply grayscale filter in place
pub fn Image::apply_grayscale_in_place(self : Image, amount : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_grayscale_in_place(amount)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply sepia filter in place
pub fn Image::apply_sepia_in_place(self : Image, amount : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_sepia_in_place(amount)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply hue rotate filter in place
pub fn Image::apply_hue_rotate_in_place(
  self : Image,
  angle_degrees : Double,
) -> Unit {
  let image = image_to_msvg(self)
  image.apply_hue_rotate_in_place(angle_degrees)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply invert filter in place
pub fn Image::apply_invert_in_place(self : Image, amount : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_invert_in_place(amount)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply saturate filter in place
pub fn Image::apply_saturate_in_place(self : Image, factor : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_saturate_in_place(factor)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply color matrix filter in place
pub fn Image::apply_color_matrix_in_place(
  self : Image,
  matrix : FixedArray[Double],
) -> Unit {
  let image = image_to_msvg(self)
  image.apply_color_matrix_in_place(matrix)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply a filter and return a new image
pub fn Image::apply_filter(self : Image, filter : Filter) -> Image {
  apply_filter(self, filter)
}

///|
/// Sprite definition (sub-region of an image)
pub(all) struct Sprite {
  image : Image
  x : Int // Source x
  y : Int // Source y
  width : Int
  height : Int
}

///|
/// Create a sprite from an image region
pub fn Sprite::new(
  image : Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Sprite {
  sprite_from_msvg(@msvg.Sprite::new(image_to_msvg(image), x, y, width, height))
}

///|
/// Create a sprite from the entire image
pub fn Sprite::from_image(image : Image) -> Sprite {
  sprite_from_msvg(@msvg.Sprite::from_image(image_to_msvg(image)))
}

///|
/// Get pixel from sprite (local coordinates)
pub fn Sprite::get_pixel(self : Sprite, x : Int, y : Int) -> Color {
  color_from_msvg(sprite_to_msvg(self).get_pixel(x, y))
}

///|
/// Sprite sheet for animations
pub(all) struct SpriteSheet {
  image : Image
  tile_width : Int
  tile_height : Int
  columns : Int
  rows : Int
}

///|
/// Create a sprite sheet from an image
pub fn SpriteSheet::new(
  image : Image,
  tile_width : Int,
  tile_height : Int,
) -> SpriteSheet {
  sprite_sheet_from_msvg(
    @msvg.SpriteSheet::new(image_to_msvg(image), tile_width, tile_height),
  )
}

///|
/// Get sprite at grid position
pub fn SpriteSheet::get_sprite(
  self : SpriteSheet,
  col : Int,
  row : Int,
) -> Sprite {
  sprite_from_msvg(sprite_sheet_to_msvg(self).get_sprite(col, row))
}

///|
/// Get sprite by index (left-to-right, top-to-bottom)
pub fn SpriteSheet::get_sprite_by_index(
  self : SpriteSheet,
  index : Int,
) -> Sprite {
  sprite_from_msvg(sprite_sheet_to_msvg(self).get_sprite_by_index(index))
}

///|
/// Total number of sprites in the sheet
pub fn SpriteSheet::sprite_count(self : SpriteSheet) -> Int {
  sprite_sheet_to_msvg(self).sprite_count()
}

///|
/// Blit (copy) source image onto destination at position
pub fn blit(dest : Image, src : Image, dest_x : Int, dest_y : Int) -> Unit {
  let output = image_to_msvg(dest)
  @msvg.blit(output, image_to_msvg(src), dest_x, dest_y)
  copy_image_pixels_from_msvg(dest, output)
}

///|
/// Blit sprite onto image
pub fn blit_sprite(
  dest : Image,
  sprite : Sprite,
  dest_x : Int,
  dest_y : Int,
) -> Unit {
  let output = image_to_msvg(dest)
  @msvg.blit_sprite(output, sprite_to_msvg(sprite), dest_x, dest_y)
  copy_image_pixels_from_msvg(dest, output)
}

///|
/// Blit with scaling
pub fn blit_scaled(
  dest : Image,
  src : Image,
  dest_x : Int,
  dest_y : Int,
  dest_w : Int,
  dest_h : Int,
) -> Unit {
  let output = image_to_msvg(dest)
  @msvg.blit_scaled(output, image_to_msvg(src), dest_x, dest_y, dest_w, dest_h)
  copy_image_pixels_from_msvg(dest, output)
}

///|
/// Flip image horizontally
pub fn Image::flip_horizontal(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).flip_horizontal())
}

///|
/// Flip image vertically
pub fn Image::flip_vertical(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).flip_vertical())
}

///|
/// Rotate image 90 degrees clockwise
pub fn Image::rotate_90_cw(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).rotate_90_cw())
}

///|
/// Rotate image 90 degrees counter-clockwise
pub fn Image::rotate_90_ccw(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).rotate_90_ccw())
}

///|
/// Create a sub-image (crop)
pub fn Image::sub_image(
  self : Image,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Image {
  image_from_msvg(image_to_msvg(self).sub_image(x, y, w, h))
}

///|
/// Animated sprite helper
pub(all) struct AnimatedSprite {
  sheet : SpriteSheet
  frames : Array[Int] // Frame indices
  mut current_frame : Int
  frame_duration : Double // Seconds per frame
  mut elapsed : Double
  mut looping : Bool
  mut playing : Bool
}

///|
/// Create an animated sprite
pub fn AnimatedSprite::new(
  sheet : SpriteSheet,
  frames : Array[Int],
  frame_duration : Double,
) -> AnimatedSprite {
  animated_sprite_from_msvg(
    @msvg.AnimatedSprite::new(
      sprite_sheet_to_msvg(sheet),
      frames,
      frame_duration,
    ),
  )
}

///|
/// Create animation for a range of frames
pub fn AnimatedSprite::from_range(
  sheet : SpriteSheet,
  start : Int,
  end : Int,
  frame_duration : Double,
) -> AnimatedSprite {
  animated_sprite_from_msvg(
    @msvg.AnimatedSprite::from_range(
      sprite_sheet_to_msvg(sheet),
      start,
      end,
      frame_duration,
    ),
  )
}

///|
/// Update animation with delta time
pub fn AnimatedSprite::update(self : AnimatedSprite, dt : Double) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.update(dt)
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Get current sprite
pub fn AnimatedSprite::get_current_sprite(self : AnimatedSprite) -> Sprite {
  sprite_from_msvg(animated_sprite_to_msvg(self).get_current_sprite())
}

///|
/// Play animation from beginning
pub fn AnimatedSprite::play(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.play()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Stop animation
pub fn AnimatedSprite::stop(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.stop()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Pause animation
pub fn AnimatedSprite::pause(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.pause()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Continue animation
pub fn AnimatedSprite::continue_playing(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.continue_playing()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Set looping
pub fn AnimatedSprite::set_looping(
  self : AnimatedSprite,
  looping : Bool,
) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.set_looping(looping)
  copy_animated_sprite_state_from_msvg(self, sprite)
}

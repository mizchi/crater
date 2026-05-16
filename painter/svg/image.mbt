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
  Image::from_msvg(@msvg.Image::new(width, height))
}

///|
/// Create an image filled with a color
pub fn Image::filled(width : Int, height : Int, color : Color) -> Image {
  Image::from_msvg(@msvg.Image::filled(width, height, color.to_msvg()))
}

///|
/// Get pixel at coordinates
pub fn Image::get_pixel(self : Image, x : Int, y : Int) -> Color {
  Color::from_msvg(self.to_msvg().get_pixel(x, y))
}

///|
/// Set pixel at coordinates
pub fn Image::set_pixel(self : Image, x : Int, y : Int, color : Color) -> Unit {
  let image = self.to_msvg()
  image.set_pixel(x, y, color.to_msvg())
  self.sync_pixels_from_msvg(image)
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
  let image = self.to_msvg()
  image.fill_rect(x, y, w, h, color.to_msvg())
  self.sync_pixels_from_msvg(image)
}

///|
/// Clear image to transparent
pub fn Image::clear(self : Image) -> Unit {
  let image = self.to_msvg()
  image.clear()
  self.sync_pixels_from_msvg(image)
}

///|
/// Clone the image
pub fn Image::clone(self : Image) -> Image {
  Image::from_msvg(self.to_msvg().clone())
}

///|
/// Apply blur filter in place
pub fn Image::apply_blur_in_place(self : Image, radius : Int) -> Unit {
  let image = self.to_msvg()
  image.apply_blur_in_place(radius)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply brightness filter in place
pub fn Image::apply_brightness_in_place(self : Image, factor : Double) -> Unit {
  let image = self.to_msvg()
  image.apply_brightness_in_place(factor)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply contrast filter in place
pub fn Image::apply_contrast_in_place(self : Image, factor : Double) -> Unit {
  let image = self.to_msvg()
  image.apply_contrast_in_place(factor)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply grayscale filter in place
pub fn Image::apply_grayscale_in_place(self : Image, amount : Double) -> Unit {
  let image = self.to_msvg()
  image.apply_grayscale_in_place(amount)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply sepia filter in place
pub fn Image::apply_sepia_in_place(self : Image, amount : Double) -> Unit {
  let image = self.to_msvg()
  image.apply_sepia_in_place(amount)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply hue rotate filter in place
pub fn Image::apply_hue_rotate_in_place(
  self : Image,
  angle_degrees : Double,
) -> Unit {
  let image = self.to_msvg()
  image.apply_hue_rotate_in_place(angle_degrees)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply invert filter in place
pub fn Image::apply_invert_in_place(self : Image, amount : Double) -> Unit {
  let image = self.to_msvg()
  image.apply_invert_in_place(amount)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply saturate filter in place
pub fn Image::apply_saturate_in_place(self : Image, factor : Double) -> Unit {
  let image = self.to_msvg()
  image.apply_saturate_in_place(factor)
  self.sync_pixels_from_msvg(image)
}

///|
/// Apply color matrix filter in place
pub fn Image::apply_color_matrix_in_place(
  self : Image,
  matrix : FixedArray[Double],
) -> Unit {
  let image = self.to_msvg()
  image.apply_color_matrix_in_place(matrix)
  self.sync_pixels_from_msvg(image)
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
  Sprite::from_msvg(@msvg.Sprite::new(image.to_msvg(), x, y, width, height))
}

///|
/// Create a sprite from the entire image
pub fn Sprite::from_image(image : Image) -> Sprite {
  Sprite::from_msvg(@msvg.Sprite::from_image(image.to_msvg()))
}

///|
/// Get pixel from sprite (local coordinates)
pub fn Sprite::get_pixel(self : Sprite, x : Int, y : Int) -> Color {
  Color::from_msvg(self.to_msvg().get_pixel(x, y))
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
  SpriteSheet::from_msvg(
    @msvg.SpriteSheet::new(image.to_msvg(), tile_width, tile_height),
  )
}

///|
/// Get sprite at grid position
pub fn SpriteSheet::get_sprite(
  self : SpriteSheet,
  col : Int,
  row : Int,
) -> Sprite {
  Sprite::from_msvg(self.to_msvg().get_sprite(col, row))
}

///|
/// Get sprite by index (left-to-right, top-to-bottom)
pub fn SpriteSheet::get_sprite_by_index(
  self : SpriteSheet,
  index : Int,
) -> Sprite {
  Sprite::from_msvg(self.to_msvg().get_sprite_by_index(index))
}

///|
/// Total number of sprites in the sheet
pub fn SpriteSheet::sprite_count(self : SpriteSheet) -> Int {
  self.to_msvg().sprite_count()
}

///|
/// Blit (copy) source image onto destination at position
pub fn blit(dest : Image, src : Image, dest_x : Int, dest_y : Int) -> Unit {
  let output = dest.to_msvg()
  @msvg.blit(output, src.to_msvg(), dest_x, dest_y)
  dest.sync_pixels_from_msvg(output)
}

///|
/// Blit sprite onto image
pub fn blit_sprite(
  dest : Image,
  sprite : Sprite,
  dest_x : Int,
  dest_y : Int,
) -> Unit {
  let output = dest.to_msvg()
  @msvg.blit_sprite(output, sprite.to_msvg(), dest_x, dest_y)
  dest.sync_pixels_from_msvg(output)
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
  let output = dest.to_msvg()
  @msvg.blit_scaled(output, src.to_msvg(), dest_x, dest_y, dest_w, dest_h)
  dest.sync_pixels_from_msvg(output)
}

///|
/// Flip image horizontally
pub fn Image::flip_horizontal(self : Image) -> Image {
  Image::from_msvg(self.to_msvg().flip_horizontal())
}

///|
/// Flip image vertically
pub fn Image::flip_vertical(self : Image) -> Image {
  Image::from_msvg(self.to_msvg().flip_vertical())
}

///|
/// Rotate image 90 degrees clockwise
pub fn Image::rotate_90_cw(self : Image) -> Image {
  Image::from_msvg(self.to_msvg().rotate_90_cw())
}

///|
/// Rotate image 90 degrees counter-clockwise
pub fn Image::rotate_90_ccw(self : Image) -> Image {
  Image::from_msvg(self.to_msvg().rotate_90_ccw())
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
  Image::from_msvg(self.to_msvg().sub_image(x, y, w, h))
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
  AnimatedSprite::from_msvg(
    @msvg.AnimatedSprite::new(
      sheet.to_msvg(),
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
  AnimatedSprite::from_msvg(
    @msvg.AnimatedSprite::from_range(
      sheet.to_msvg(),
      start,
      end,
      frame_duration,
    ),
  )
}

///|
/// Update animation with delta time
pub fn AnimatedSprite::update(self : AnimatedSprite, dt : Double) -> Unit {
  let sprite = self.to_msvg()
  sprite.update(dt)
  self.sync_state_from_msvg(sprite)
}

///|
/// Get current sprite
pub fn AnimatedSprite::get_current_sprite(self : AnimatedSprite) -> Sprite {
  Sprite::from_msvg(self.to_msvg().get_current_sprite())
}

///|
/// Play animation from beginning
pub fn AnimatedSprite::play(self : AnimatedSprite) -> Unit {
  let sprite = self.to_msvg()
  sprite.play()
  self.sync_state_from_msvg(sprite)
}

///|
/// Stop animation
pub fn AnimatedSprite::stop(self : AnimatedSprite) -> Unit {
  let sprite = self.to_msvg()
  sprite.stop()
  self.sync_state_from_msvg(sprite)
}

///|
/// Pause animation
pub fn AnimatedSprite::pause(self : AnimatedSprite) -> Unit {
  let sprite = self.to_msvg()
  sprite.pause()
  self.sync_state_from_msvg(sprite)
}

///|
/// Continue animation
pub fn AnimatedSprite::continue_playing(self : AnimatedSprite) -> Unit {
  let sprite = self.to_msvg()
  sprite.continue_playing()
  self.sync_state_from_msvg(sprite)
}

///|
/// Set looping
pub fn AnimatedSprite::set_looping(
  self : AnimatedSprite,
  looping : Bool,
) -> Unit {
  let sprite = self.to_msvg()
  sprite.set_looping(looping)
  self.sync_state_from_msvg(sprite)
}

///|
fn Image::from_msvg(image : @msvg.Image) -> Image {
  {
    width: image.width,
    height: image.height,
    pixels: image.pixels.map(Color::from_msvg),
  }
}

///|
fn Image::to_msvg(self : Image) -> @msvg.Image {
  @msvg.Image::{
    width: self.width,
    height: self.height,
    pixels: self.pixels.map(fn(c) { c.to_msvg() }),
  }
}

///|
fn Image::sync_pixels_from_msvg(self : Image, source : @msvg.Image) -> Unit {
  let len = if self.pixels.length() < source.pixels.length() {
    self.pixels.length()
  } else {
    source.pixels.length()
  }
  for i in 0..<len {
    self.pixels[i] = Color::from_msvg(source.pixels[i])
  }
}

///|
fn Sprite::from_msvg(sprite : @msvg.Sprite) -> Sprite {
  {
    image: Image::from_msvg(sprite.image),
    x: sprite.x,
    y: sprite.y,
    width: sprite.width,
    height: sprite.height,
  }
}

///|
fn Sprite::to_msvg(self : Sprite) -> @msvg.Sprite {
  @msvg.Sprite::{
    image: self.image.to_msvg(),
    x: self.x,
    y: self.y,
    width: self.width,
    height: self.height,
  }
}

///|
fn SpriteSheet::from_msvg(sheet : @msvg.SpriteSheet) -> SpriteSheet {
  {
    image: Image::from_msvg(sheet.image),
    tile_width: sheet.tile_width,
    tile_height: sheet.tile_height,
    columns: sheet.columns,
    rows: sheet.rows,
  }
}

///|
fn SpriteSheet::to_msvg(self : SpriteSheet) -> @msvg.SpriteSheet {
  @msvg.SpriteSheet::{
    image: self.image.to_msvg(),
    tile_width: self.tile_width,
    tile_height: self.tile_height,
    columns: self.columns,
    rows: self.rows,
  }
}

///|
fn AnimatedSprite::from_msvg(sprite : @msvg.AnimatedSprite) -> AnimatedSprite {
  {
    sheet: SpriteSheet::from_msvg(sprite.sheet),
    frames: sprite.frames,
    current_frame: sprite.current_frame,
    frame_duration: sprite.frame_duration,
    elapsed: sprite.elapsed,
    looping: sprite.looping,
    playing: sprite.playing,
  }
}

///|
fn AnimatedSprite::to_msvg(self : AnimatedSprite) -> @msvg.AnimatedSprite {
  @msvg.AnimatedSprite::{
    sheet: self.sheet.to_msvg(),
    frames: self.frames,
    current_frame: self.current_frame,
    frame_duration: self.frame_duration,
    elapsed: self.elapsed,
    looping: self.looping,
    playing: self.playing,
  }
}

///|
fn AnimatedSprite::sync_state_from_msvg(
  self : AnimatedSprite,
  source : @msvg.AnimatedSprite,
) -> Unit {
  self.current_frame = source.current_frame
  self.elapsed = source.elapsed
  self.looping = source.looping
  self.playing = source.playing
}

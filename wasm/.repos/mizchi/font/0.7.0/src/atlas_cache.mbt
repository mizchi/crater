///|
/// Atlas cache serialization — save/load GlyphAtlas to/from flat Int arrays.
///
/// Format: [magic, width, height, page_id, entry_count, next_x_bits_hi, next_x_bits_lo,
///          next_y_bits_hi, next_y_bits_lo, row_height_bits_hi, row_height_bits_lo,
///          entries..., pixels...]

///|
let cache_magic : Int = 0x47_4C_43_41 // "GLCA"

///|
/// Serialize a GlyphAtlas to a flat Int array for persistent caching.
pub fn GlyphAtlas::serialize(self : GlyphAtlas) -> Array[Int] {
  let cache = self.cache
  let entry_count = cache.entry_count()
  let result : Array[Int] = []
  // Header
  result.push(cache_magic)
  result.push(self.width)
  result.push(self.height)
  result.push(cache.atlas_page_id)
  result.push(entry_count)
  // next_x, next_y, row_height as f64 → two i32s each
  push_f64(result, cache.next_x)
  push_f64(result, cache.next_y)
  push_f64(result, cache.row_height)
  // Entries: [key, ax_hi, ax_lo, ay_hi, ay_lo, aw_hi, aw_lo, ah_hi, ah_lo] × N
  cache.entries.each(fn(key, entry) {
    result.push(key)
    push_f64(result, entry.atlas_x)
    push_f64(result, entry.atlas_y)
    push_f64(result, entry.atlas_w)
    push_f64(result, entry.atlas_h)
  })
  // Pixels (RGBA8)
  for px in self.pixels {
    result.push(px)
  }
  result
}

///|
/// Deserialize a GlyphAtlas from a flat Int array.
pub fn GlyphAtlas::deserialize(data : Array[Int]) -> GlyphAtlas? {
  if data.length() < 11 {
    return None
  }
  if data[0] != cache_magic {
    return None
  }
  let width = data[1]
  let height = data[2]
  let page_id = data[3]
  let entry_count = data[4]
  let mut pos = 5
  let next_x = read_f64(data, pos)
  pos += 2
  let next_y = read_f64(data, pos)
  pos += 2
  let row_height = read_f64(data, pos)
  pos += 2
  // Read entries
  let cache = GlyphCache::new(width.to_double(), height.to_double(), page_id)
  cache.next_x = next_x
  cache.next_y = next_y
  cache.row_height = row_height
  for _i = 0; _i < entry_count; _i = _i + 1 {
    if pos + 9 > data.length() {
      return None
    }
    let key = data[pos]
    pos += 1
    let ax = read_f64(data, pos)
    pos += 2
    let ay = read_f64(data, pos)
    pos += 2
    let aw = read_f64(data, pos)
    pos += 2
    let ah = read_f64(data, pos)
    pos += 2
    let entry : GlyphCacheEntry = {
      glyph_id: key,
      atlas_x: ax,
      atlas_y: ay,
      atlas_w: aw,
      atlas_h: ah,
      atlas_page_id: page_id,
    }
    cache.entries.set(key, entry)
  }
  // Read pixels
  let pixel_count = width * height * 4
  let pixels : Array[Int] = Array::make(pixel_count, 0)
  for i = 0; i < pixel_count; i = i + 1 {
    if pos + i < data.length() {
      pixels[i] = data[pos + i]
    }
  }
  Some({
    cache,
    width,
    height,
    pixels,
    dirty: true, // Mark dirty so GPU uploads on first use
    last_used_generation: 0,
  })
}

///|
/// Serialize all pages of a TextRenderer.
pub fn TextRenderer::serialize_cache(self : TextRenderer) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for page in self.pages {
    if page.cache.entry_count() > 0 {
      result.push(page.serialize())
    }
  }
  result
}

///|
/// Restore atlas pages from serialized data.
/// Returns number of pages loaded.
pub fn TextRenderer::load_cache(
  self : TextRenderer,
  pages_data : Array[Array[Int]],
) -> Int {
  let mut loaded = 0
  for data in pages_data {
    match GlyphAtlas::deserialize(data) {
      Some(atlas) => {
        if loaded < self.pages.length() {
          self.pages[loaded] = atlas
        } else if self.pages.length() < self.max_pages {
          self.pages.push(atlas)
        }
        loaded += 1
      }
      None => ()
    }
  }
  loaded
}

///|
/// Encode a Double as two Ints: integer part and fractional part (×1000000).
fn push_f64(arr : Array[Int], value : Double) -> Unit {
  let int_part = value.to_int()
  let frac_part = ((value - int_part.to_double()) * 1000000.0).to_int()
  arr.push(int_part)
  arr.push(frac_part)
}

///|
/// Decode a Double from two Ints (integer + fractional×1000000).
fn read_f64(data : Array[Int], pos : Int) -> Double {
  data[pos].to_double() + data[pos + 1].to_double() / 1000000.0
}

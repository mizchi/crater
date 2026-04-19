///|
/// TextRenderer — manages glyph atlas pages and provides text measurement.
/// GPU-independent; consumers use flush_dirty_pages() to upload atlas data.

///|
pub struct TextRenderer {
  mut pages : Array[GlyphAtlas]
  font : TTFont
  pipeline_id : Int
  atlas_size : Int
  base_page_id : Int
  max_pages : Int
  mut generation : Int
}

///|
pub fn TextRenderer::new(
  font : TTFont,
  atlas_size : Int,
  base_page_id : Int,
  pipeline_id : Int,
) -> TextRenderer {
  TextRenderer::new_with_options(
    font, atlas_size, base_page_id, pipeline_id, 16,
  )
}

///|
pub fn TextRenderer::new_with_options(
  font : TTFont,
  atlas_size : Int,
  base_page_id : Int,
  pipeline_id : Int,
  max_pages : Int,
) -> TextRenderer {
  {
    pages: [GlyphAtlas::new(atlas_size, atlas_size, base_page_id)],
    font,
    pipeline_id,
    atlas_size,
    base_page_id,
    max_pages,
    generation: 0,
  }
}

///|
pub fn TextRenderer::measure(
  self : TextRenderer,
  text : String,
  size_px : Double,
) -> TextMetrics {
  let width = self.font.measure_text(text, size_px)
  let ascent = self.font.ascent.to_double() /
    self.font.units_per_em.to_double() *
    size_px
  let descent = -self.font.descent.to_double() /
    self.font.units_per_em.to_double() *
    size_px
  { width, height: ascent + descent, baseline: ascent }
}

///|
pub fn TextRenderer::get_atlas(self : TextRenderer) -> GlyphAtlas {
  self.pages[0]
}

///|
pub fn TextRenderer::get_page_id(self : TextRenderer) -> Int {
  self.base_page_id
}

///|
pub fn TextRenderer::glyph_count(self : TextRenderer) -> Int {
  let mut total = 0
  for page in self.pages {
    total += page.cache.entry_count()
  }
  total
}

///|
pub fn TextRenderer::clear(self : TextRenderer) -> Unit {
  let first = self.pages[0]
  first.cache.clear()
  for i in 0..<first.pixels.length() {
    first.pixels[i] = 0
  }
  first.dirty = false
  first.last_used_generation = 0
  self.pages = [first]
  self.generation = 0
}

///|
pub fn TextRenderer::page_count(self : TextRenderer) -> Int {
  self.pages.length()
}

///|
pub fn TextRenderer::get_page(self : TextRenderer, index : Int) -> GlyphAtlas {
  self.pages[index]
}

///|
pub fn TextRenderer::get_page_ids(self : TextRenderer) -> Array[Int] {
  let ids : Array[Int] = []
  for page in self.pages {
    ids.push(page.cache.atlas_page_id)
  }
  ids
}

///|
pub fn TextRenderer::flush_dirty_pages(
  self : TextRenderer,
) -> Array[AtlasPageInfo] {
  let result : Array[AtlasPageInfo] = []
  for page in self.pages {
    if page.dirty {
      result.push({
        page_id: page.cache.atlas_page_id,
        width: page.width,
        height: page.height,
        dirty: true,
      })
      page.dirty = false
    }
  }
  result
}

///|
/// Ensure a glyph is rasterized and cached. Returns the page index and cache entry.
/// Used by GPU renderers to build draw commands.
pub fn TextRenderer::ensure_glyph(
  self : TextRenderer,
  codepoint : Int,
  size_px : Double,
) -> (Int, GlyphCacheEntry)? {
  self.generation += 1
  let glyph_id = self.font.glyph_index(codepoint)
  let cache_key = make_glyph_cache_key(glyph_id, size_px)
  // Search existing pages
  for i, page in self.pages {
    match page.cache.get(cache_key) {
      Some(entry) => {
        page.last_used_generation = self.generation
        return Some((i, entry))
      }
      None => ()
    }
  }
  // Try rasterizing into existing pages
  for i, page in self.pages {
    match page.rasterize_glyph(self.font, codepoint, size_px) {
      Some(entry) => {
        page.last_used_generation = self.generation
        return Some((i, entry))
      }
      None => ()
    }
  }
  // Add new page or evict oldest
  if self.pages.length() < self.max_pages {
    let new_page_id = self.base_page_id + self.pages.length()
    let new_page = GlyphAtlas::new(
      self.atlas_size,
      self.atlas_size,
      new_page_id,
    )
    self.pages.push(new_page)
    let idx = self.pages.length() - 1
    match self.pages[idx].rasterize_glyph(self.font, codepoint, size_px) {
      Some(entry) => {
        self.pages[idx].last_used_generation = self.generation
        return Some((idx, entry))
      }
      None => None
    }
  } else {
    // Evict oldest page
    let mut oldest_idx = 0
    let mut oldest_gen = self.pages[0].last_used_generation
    for i = 1; i < self.pages.length(); i = i + 1 {
      if self.pages[i].last_used_generation < oldest_gen {
        oldest_gen = self.pages[i].last_used_generation
        oldest_idx = i
      }
    }
    let evicted = self.pages[oldest_idx]
    evicted.cache.clear()
    for j in 0..<evicted.pixels.length() {
      evicted.pixels[j] = 0
    }
    evicted.dirty = true
    match evicted.rasterize_glyph(self.font, codepoint, size_px) {
      Some(entry) => {
        evicted.last_used_generation = self.generation
        Some((oldest_idx, entry))
      }
      None => None
    }
  }
}

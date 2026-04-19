///|
/// Layout text into positioned glyphs with kerning
pub fn TTFont::layout_text(
  self : TTFont,
  text : String,
  font_size : Double,
) -> Array[GlyphPosition] {
  let scale = font_size / self.units_per_em.to_double()
  let codepoints = string_to_codepoints(text)
  let positions : Array[GlyphPosition] = []
  let mut x = 0.0
  let mut prev_gid = -1
  for cp in codepoints {
    let gid = self.glyph_index(cp)
    // Apply kerning
    if prev_gid >= 0 {
      let kern = self.kern_pair(prev_gid, gid)
      x += kern.to_double() * scale
    }
    let advance = if gid < self.advance_widths.length() {
      self.advance_widths[gid]
    } else {
      0
    }
    let x_advance = advance.to_double() * scale
    positions.push({
      codepoint: cp,
      glyph_id: gid,
      x_offset: x,
      y_offset: 0.0,
      x_advance,
    })
    x += x_advance
    prev_gid = gid
  }
  positions
}

///|
/// Measure total text width
pub fn TTFont::measure_text(
  self : TTFont,
  text : String,
  font_size : Double,
) -> Double {
  let scale = font_size / self.units_per_em.to_double()
  let codepoints = string_to_codepoints(text)
  let mut width = 0.0
  let mut prev_gid = -1
  for cp in codepoints {
    let gid = self.glyph_index(cp)
    if prev_gid >= 0 {
      let kern = self.kern_pair(prev_gid, gid)
      width += kern.to_double() * scale
    }
    let advance = if gid < self.advance_widths.length() {
      self.advance_widths[gid]
    } else {
      0
    }
    width += advance.to_double() * scale
    prev_gid = gid
  }
  width
}

///|
/// Layout text vertically (top-to-bottom) into positioned glyphs
pub fn TTFont::layout_text_vertical(
  self : TTFont,
  text : String,
  font_size : Double,
) -> Array[GlyphPosition] {
  let scale = font_size / self.units_per_em.to_double()
  let codepoints = string_to_codepoints(text)
  let positions : Array[GlyphPosition] = []
  let mut y = 0.0
  for cp in codepoints {
    let gid = self.glyph_index(cp)
    let advance_height = match self.vertical {
      Some(vm) =>
        if gid < vm.advance_heights.length() {
          vm.advance_heights[gid]
        } else {
          self.units_per_em
        }
      None => self.units_per_em
    }
    let origin_y = self.vert_origin_y(gid)
    let y_advance = advance_height.to_double() * scale
    positions.push({
      codepoint: cp,
      glyph_id: gid,
      x_offset: origin_y.to_double() * scale,
      y_offset: y,
      x_advance: y_advance,
    })
    y += y_advance
  }
  positions
}

///|
/// Measure total text height for vertical layout
pub fn TTFont::measure_text_vertical(
  self : TTFont,
  text : String,
  font_size : Double,
) -> Double {
  let scale = font_size / self.units_per_em.to_double()
  let codepoints = string_to_codepoints(text)
  let mut height = 0.0
  for cp in codepoints {
    let gid = self.glyph_index(cp)
    let advance_height = match self.vertical {
      Some(vm) =>
        if gid < vm.advance_heights.length() {
          vm.advance_heights[gid]
        } else {
          self.units_per_em
        }
      None => self.units_per_em
    }
    height += advance_height.to_double() * scale
  }
  height
}

///|
/// Convert String to array of Unicode codepoints (handling surrogate pairs)
fn string_to_codepoints(s : String) -> Array[Int] {
  let result : Array[Int] = []
  let len = s.length()
  let mut i = 0
  while i < len {
    let c = s[i].to_int()
    if c >= 0xD800 && c <= 0xDBFF && i + 1 < len {
      let lo = s[i + 1].to_int()
      if lo >= 0xDC00 && lo <= 0xDFFF {
        let cp = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00)
        result.push(cp)
        i += 2
        continue
      }
    }
    result.push(c)
    i += 1
  }
  result
}

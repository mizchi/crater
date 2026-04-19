///|
/// Parse a font from raw bytes, auto-detecting format (TTF, OTF, or WOFF1)
pub fn parse_font(data : Bytes) -> TTFont? {
  // Minimum header: sfnt = 12 bytes, WOFF1 = 44 bytes
  if data.length() < 12 {
    return None
  }
  let magic = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  if magic == 0x774F4646 {
    // wOFF (WOFF1)
    parse_woff1(data)
  } else if magic == 0x774F4632 {
    // wOF2 (WOFF2)
    parse_woff2(data)
  } else if magic == 0x74746366 {
    // ttcf (TTC/OTC font collection) — return first font
    parse_font_at(data, 0)
  } else {
    // 0x00010000 (TrueType), 0x4F54544F (OTTO/CFF), 0x74727565 (true)
    parse_ttf(data)
  }
}

///|
/// Parse a TrueType/OpenType font from raw bytes starting at a given offset
fn parse_ttf_at_offset(data : Bytes, base_offset : Int) -> TTFont? {
  let reader = BinaryReader::at(data, base_offset)
  let _sfnt_version = reader.read_uint32()
  let num_tables = reader.read_uint16()
  let _search_range = reader.read_uint16()
  let _entry_selector = reader.read_uint16()
  let _range_shift = reader.read_uint16()
  let tables : Map[String, TableRecord] = {}
  for i = 0; i < num_tables; i = i + 1 {
    let tag = reader.read_tag()
    let _checksum = reader.read_uint32()
    let offset = reader.read_uint32()
    let _length = reader.read_uint32()
    tables[tag] = { offset, }
    ignore(i)
  }
  guard tables.get("head") is Some(head_rec) else { return None }
  guard tables.get("maxp") is Some(maxp_rec) else { return None }
  guard tables.get("hhea") is Some(hhea_rec) else { return None }
  guard tables.get("hmtx") is Some(hmtx_rec) else { return None }
  guard tables.get("cmap") is Some(cmap_rec) else { return None }
  let has_glyf = tables.get("glyf") is Some(_)
  let has_cff = tables.get("CFF ") is Some(_)
  let has_cff2 = tables.get("CFF2") is Some(_)
  let (units_per_em, index_to_loc_format) = parse_head(reader, head_rec.offset)
  let num_glyphs = parse_maxp(reader, maxp_rec.offset)
  let (ascent, descent, line_gap, num_h_metrics) = parse_hhea(
    reader,
    hhea_rec.offset,
  )
  let (advance_widths, left_side_bearings) = parse_hmtx(
    reader,
    hmtx_rec.offset,
    num_glyphs,
    num_h_metrics,
  )
  let cmap = parse_cmap(reader, cmap_rec.offset)
  let var_axes : Array[VarAxis] = match tables.get("fvar") {
    Some(fvar_rec) => parse_fvar(reader, fvar_rec.offset)
    None => []
  }
  let kern_pairs : Map[Int, Int] = match tables.get("kern") {
    Some(kern_rec) => parse_kern(reader, kern_rec.offset)
    None => {}
  }
  let avar_segments : Array[Array[(Double, Double)]] = match
    tables.get("avar") {
    Some(avar_rec) => parse_avar(reader, avar_rec.offset, var_axes.length())
    None => []
  }
  let name_records : Map[Int, String] = match tables.get("name") {
    Some(name_rec) => parse_name(reader, name_rec.offset)
    None => {}
  }
  let vertical : VerticalMetrics? = match
    (tables.get("vhea"), tables.get("vmtx")) {
    (Some(vhea_rec), Some(vmtx_rec)) => {
      let (v_ascent, v_descent, num_v_metrics) = parse_vhea(
        reader,
        vhea_rec.offset,
      )
      let (advance_heights, top_side_bearings) = parse_vmtx(
        reader,
        vmtx_rec.offset,
        num_glyphs,
        num_v_metrics,
      )
      Some({ v_ascent, v_descent, advance_heights, top_side_bearings })
    }
    _ => None
  }
  let os2 : OS2Table? = tables
    .get("OS/2")
    .map(fn(os2_rec) { parse_os2(reader, os2_rec.offset) })
  let post : PostTable? = tables
    .get("post")
    .map(fn(post_rec) { parse_post(reader, post_rec.offset, num_glyphs) })
  let gasp : Array[GaspRange] = match tables.get("gasp") {
    Some(gasp_rec) => parse_gasp(reader, gasp_rec.offset)
    None => []
  }
  let vorg : VorgData? = tables
    .get("VORG")
    .map(fn(vorg_rec) { parse_vorg(reader, vorg_rec.offset) })
  if has_glyf {
    guard tables.get("loca") is Some(loca_rec) else { return None }
    guard tables.get("glyf") is Some(glyf_rec) else { return None }
    let loca = parse_loca(
      reader,
      loca_rec.offset,
      num_glyphs,
      index_to_loc_format,
    )
    let gvar_data : GvarData? = tables
      .get("gvar")
      .map(fn(gvar_rec) { parse_gvar(reader, gvar_rec.offset, num_glyphs) })
      .bind(fn(x) { x })
    Some({
      units_per_em,
      index_to_loc_format,
      num_glyphs,
      ascent,
      descent,
      line_gap,
      num_h_metrics,
      glyf_offset: glyf_rec.offset,
      data,
      cmap,
      loca,
      advance_widths,
      left_side_bearings,
      cff: None,
      gvar: gvar_data,
      var_axes,
      kern_pairs,
      avar_segments,
      name_records,
      os2,
      post,
      vertical,
      gasp,
      vorg,
    })
  } else if has_cff {
    guard tables.get("CFF ") is Some(cff_rec) else { return None }
    parse_cff_table(data, cff_rec.offset).map(fn(cff) {
      {
        units_per_em,
        index_to_loc_format,
        num_glyphs,
        ascent,
        descent,
        line_gap,
        num_h_metrics,
        glyf_offset: 0,
        data,
        cmap,
        loca: [],
        advance_widths,
        left_side_bearings,
        cff: Some(cff),
        gvar: None,
        var_axes,
        kern_pairs,
        avar_segments,
        name_records,
        os2,
        post,
        vertical,
        gasp,
        vorg,
      }
    })
  } else if has_cff2 {
    guard tables.get("CFF2") is Some(cff2_rec) else { return None }
    parse_cff2_table(data, cff2_rec.offset).map(fn(cff) {
      {
        units_per_em,
        index_to_loc_format,
        num_glyphs,
        ascent,
        descent,
        line_gap,
        num_h_metrics,
        glyf_offset: 0,
        data,
        cmap,
        loca: [],
        advance_widths,
        left_side_bearings,
        cff: Some(cff),
        gvar: None,
        var_axes,
        kern_pairs,
        avar_segments,
        name_records,
        os2,
        post,
        vertical,
        gasp,
        vorg,
      }
    })
  } else {
    None
  }
}

///|
/// Parse a TrueType/OpenType font from raw bytes
pub fn parse_ttf(data : Bytes) -> TTFont? {
  parse_ttf_at_offset(data, 0)
}

///|
pub fn TTFont::glyph_index(self : TTFont, codepoint : Int) -> Int {
  self.cmap.get(codepoint).unwrap_or(0)
}

///|
pub fn TTFont::glyph_outline(
  self : TTFont,
  glyph_id : Int,
) -> Array[@svg.PathCommand] {
  glyph_outline_by_id(self, glyph_id)
}

///|
pub fn TTFont::char_outline(
  self : TTFont,
  codepoint : Int,
) -> Array[@svg.PathCommand] {
  let gid = self.glyph_index(codepoint)
  self.glyph_outline(gid)
}

///|
pub fn TTFont::glyph_metrics(self : TTFont, glyph_id : Int) -> GlyphMetrics {
  let advance = if glyph_id < self.advance_widths.length() {
    self.advance_widths[glyph_id]
  } else {
    0
  }
  let lsb = if glyph_id < self.left_side_bearings.length() {
    self.left_side_bearings[glyph_id]
  } else {
    0
  }
  let bbox : GlyphBBox = match self.cff {
    Some(_) => {
      // CFF fonts: compute bbox from outline
      let outline = self.glyph_outline(glyph_id)
      compute_path_bbox(outline)
    }
    None =>
      if glyph_id < self.num_glyphs && glyph_id < self.loca.length() - 1 {
        let glyf_off = self.loca[glyph_id]
        let next_off = self.loca[glyph_id + 1]
        if glyf_off != next_off {
          let offset = self.glyf_offset + glyf_off
          let r = BinaryReader::at(self.data, offset)
          let _num_contours = r.read_int16()
          let x_min = r.read_int16()
          let y_min = r.read_int16()
          let x_max = r.read_int16()
          let y_max = r.read_int16()
          { x_min, y_min, x_max, y_max }
        } else {
          { x_min: 0, y_min: 0, x_max: 0, y_max: 0 }
        }
      } else {
        { x_min: 0, y_min: 0, x_max: 0, y_max: 0 }
      }
  }
  { advance_width: advance, left_side_bearing: lsb, bbox }
}

///|
pub fn TTFont::get_glyph(self : TTFont, codepoint : Int) -> Glyph {
  let gid = self.glyph_index(codepoint)
  let metrics = self.glyph_metrics(gid)
  let outline = self.glyph_outline(gid)
  { glyph_id: gid, metrics, outline }
}

///|
/// Get glyph metrics with variable font interpolation.
/// For glyf+gvar fonts, advance width is interpolated via phantom points.
/// For CFF2 fonts, bbox is computed from the variable outline (advance uses static value).
pub fn TTFont::glyph_metrics_at(
  self : TTFont,
  glyph_id : Int,
  axis_values : Map[String, Double],
) -> GlyphMetrics {
  if self.var_axes.is_empty() {
    return self.glyph_metrics(glyph_id)
  }
  // Normalize coordinates with avar mapping
  let coords : Array[Double] = []
  for i, axis in self.var_axes {
    let user_val = axis_values.get(axis.tag).unwrap_or(axis.default_value)
    let mut coord = normalize_axis_coord(user_val, axis)
    if i < self.avar_segments.length() {
      coord = apply_avar(coord, self.avar_segments[i])
    }
    coords.push(coord)
  }
  let advance = if glyph_id < self.advance_widths.length() {
    self.advance_widths[glyph_id]
  } else {
    0
  }
  let lsb = if glyph_id < self.left_side_bearings.length() {
    self.left_side_bearings[glyph_id]
  } else {
    0
  }
  // glyf+gvar: interpolate metrics via phantom points
  if self.gvar is Some(gvar) && self.cff is None {
    let (var_advance, var_lsb, var_bbox) = gvar_interpolate_metrics(
      self, gvar, glyph_id, coords, advance, lsb,
    )
    return {
      advance_width: var_advance,
      left_side_bearing: var_lsb,
      bbox: var_bbox,
    }
  }
  // CFF2: compute bbox from variable outline, advance stays static
  if self.cff is Some(cff) && cff.ivs is Some(ivs) {
    let scalars = precompute_scalars(ivs, 0, coords)
    let outline = glyph_outline_by_id_var(self, glyph_id, scalars)
    let bbox = compute_path_bbox(outline)
    return { advance_width: advance, left_side_bearing: lsb, bbox }
  }
  self.glyph_metrics(glyph_id)
}

///|
pub fn TTFont::glyph_outline_at(
  self : TTFont,
  glyph_id : Int,
  axis_values : Map[String, Double],
) -> Array[@svg.PathCommand] {
  if self.var_axes.is_empty() {
    return self.glyph_outline(glyph_id)
  }
  // Normalize coordinates with avar mapping
  let coords : Array[Double] = []
  for i, axis in self.var_axes {
    let user_val = match axis_values.get(axis.tag) {
      Some(v) => v
      None => axis.default_value
    }
    let mut coord = normalize_axis_coord(user_val, axis)
    if i < self.avar_segments.length() {
      coord = apply_avar(coord, self.avar_segments[i])
    }
    coords.push(coord)
  }
  // CFF2 variable font path
  if self.cff is Some(cff) && cff.ivs is Some(ivs) {
    let scalars = precompute_scalars(ivs, 0, coords)
    return glyph_outline_by_id_var(self, glyph_id, scalars)
  }
  // glyf+gvar variable font path
  if self.gvar is Some(_) {
    return glyf_outline_by_id_var_gvar(self, glyph_id, coords)
  }
  self.glyph_outline(glyph_id)
}

///|
pub fn TTFont::char_outline_at(
  self : TTFont,
  codepoint : Int,
  axis_values : Map[String, Double],
) -> Array[@svg.PathCommand] {
  let gid = self.glyph_index(codepoint)
  self.glyph_outline_at(gid, axis_values)
}

///|
pub fn TTFont::scaled_outline(
  self : TTFont,
  codepoint : Int,
  font_size : Double,
) -> Array[@svg.PathCommand] {
  let outline = self.char_outline(codepoint)
  let s = font_size / self.units_per_em.to_double()
  scale_commands(outline, s, true)
}

///|
/// Get kerning value for a pair of glyph IDs
pub fn TTFont::kern_pair(self : TTFont, left_gid : Int, right_gid : Int) -> Int {
  let key = (left_gid << 16) | right_gid
  self.kern_pairs.get(key).unwrap_or(0)
}

///|
/// Get font name by nameID (1=family, 2=subfamily, 4=full name, 6=postscript name)
pub fn TTFont::font_name(self : TTFont, name_id : Int) -> String? {
  self.name_records.get(name_id)
}

///|
/// Get weight class from OS/2 table (400=Regular, 700=Bold)
pub fn TTFont::weight_class(self : TTFont) -> Int {
  match self.os2 {
    Some(os2) => os2.us_weight_class
    None => 400
  }
}

///|
/// Check if font is fixed-pitch from post table
pub fn TTFont::is_fixed_pitch(self : TTFont) -> Bool {
  match self.post {
    Some(post) => post.is_fixed_pitch
    None => false
  }
}

///|
/// Get italic angle from post table
pub fn TTFont::italic_angle(self : TTFont) -> Double {
  match self.post {
    Some(post) => post.italic_angle
    None => 0.0
  }
}

///|
/// Get x-height from OS/2 table
pub fn TTFont::x_height(self : TTFont) -> Int {
  match self.os2 {
    Some(os2) => os2.sx_height
    None => 0
  }
}

///|
/// Get cap-height from OS/2 table
pub fn TTFont::cap_height(self : TTFont) -> Int {
  match self.os2 {
    Some(os2) => os2.s_cap_height
    None => 0
  }
}

///|
/// Get glyph name from post table
pub fn TTFont::glyph_name(self : TTFont, glyph_id : Int) -> String {
  match self.post {
    Some(post) =>
      if glyph_id < post.glyph_names.length() {
        post.glyph_names[glyph_id]
      } else {
        ""
      }
    None => ""
  }
}

///|
/// Apply avar segment mapping (piecewise linear interpolation)
fn apply_avar(coord : Double, segment : Array[(Double, Double)]) -> Double {
  if segment.is_empty() {
    return coord
  }
  // Below first point
  let (first_from, first_to) = segment[0]
  if coord <= first_from {
    return first_to
  }
  // Above last point
  let (last_from, last_to) = segment[segment.length() - 1]
  if coord >= last_from {
    return last_to
  }
  // Find segment and interpolate
  for i = 1; i < segment.length(); i = i + 1 {
    let (from1, to1) = segment[i - 1]
    let (from2, to2) = segment[i]
    if coord <= from2 {
      if from2 == from1 {
        return to2
      }
      let t = (coord - from1) / (from2 - from1)
      return to1 + t * (to2 - to1)
    }
  }
  coord
}

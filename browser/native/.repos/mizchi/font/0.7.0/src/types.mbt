///|
pub(all) struct GlyphBBox {
  x_min : Int
  y_min : Int
  x_max : Int
  y_max : Int
}

///|
pub(all) struct GlyphMetrics {
  advance_width : Int
  left_side_bearing : Int
  bbox : GlyphBBox
}

///|
pub(all) struct Glyph {
  glyph_id : Int
  metrics : GlyphMetrics
  outline : Array[@svg.PathCommand]
}

///|
pub(all) struct TTFont {
  units_per_em : Int
  index_to_loc_format : Int
  num_glyphs : Int
  ascent : Int
  descent : Int
  line_gap : Int
  num_h_metrics : Int
  glyf_offset : Int
  data : Bytes
  cmap : Map[Int, Int]
  loca : Array[Int]
  advance_widths : Array[Int]
  left_side_bearings : Array[Int]
  cff : CFFData?
  gvar : GvarData?
  var_axes : Array[VarAxis]
  kern_pairs : Map[Int, Int]
  avar_segments : Array[Array[(Double, Double)]]
  name_records : Map[Int, String]
  os2 : OS2Table?
  post : PostTable?
  vertical : VerticalMetrics?
  gasp : Array[GaspRange]
  vorg : VorgData?
}

///|
pub(all) struct VarAxis {
  tag : String
  min_value : Double
  default_value : Double
  max_value : Double
}

///|
pub(all) struct VarRegionAxis {
  start_coord : Double
  peak_coord : Double
  end_coord : Double
}

///|
pub(all) struct VarRegion {
  axes : Array[VarRegionAxis]
}

///|
pub(all) struct ItemVariationData {
  region_indices : Array[Int]
  delta_sets : Array[Array[Int]]
}

///|
pub(all) struct ItemVariationStore {
  regions : Array[VarRegion]
  data : Array[ItemVariationData]
}

///|
pub(all) struct CFFIndex {
  data_offset : Int
  offsets : Array[Int]
}

///|
pub(all) struct CFFData {
  charstrings : CFFIndex
  global_subrs : CFFIndex
  local_subrs : CFFIndex
  default_width_x : Int
  nominal_width_x : Int
  is_cff2 : Bool
  ivs : ItemVariationStore?
}

///|
pub(all) struct GvarData {
  axis_count : Int
  shared_tuples : Array[Array[Double]]
  gvar_offset : Int
  glyph_var_data_offset : Int
  glyph_offsets : Array[Int]
}

///|
pub(all) struct OS2Table {
  version : Int
  us_weight_class : Int
  us_width_class : Int
  fs_type : Int
  panose : FixedArray[Int]
  ul_unicode_range1 : Int
  ul_unicode_range2 : Int
  ul_unicode_range3 : Int
  ul_unicode_range4 : Int
  fs_selection : Int
  s_typo_ascender : Int
  s_typo_descender : Int
  s_typo_line_gap : Int
  us_win_ascent : Int
  us_win_descent : Int
  sx_height : Int
  s_cap_height : Int
}

///|
pub(all) struct VerticalMetrics {
  v_ascent : Int
  v_descent : Int
  advance_heights : Array[Int]
  top_side_bearings : Array[Int]
}

///|
pub(all) struct GaspRange {
  max_ppem : Int
  behavior : Int
}

///|
pub(all) struct VorgData {
  default_vert_origin_y : Int
  vert_origins : Map[Int, Int]
}

///|
pub(all) struct PostTable {
  italic_angle : Double
  underline_position : Int
  underline_thickness : Int
  is_fixed_pitch : Bool
  glyph_names : Array[String]
}

///|
pub(all) struct GlyphPosition {
  codepoint : Int
  glyph_id : Int
  x_offset : Double
  y_offset : Double
  x_advance : Double
}

///|
priv struct TableRecord {
  offset : Int
}

///|
priv struct GlyphPoint {
  x : Int
  y : Int
  on_curve : Bool
}

///|
/// A built-in 5x7 bitmap font for `gfx_text`.
///
/// gfx_text's `text_run_commands` lowers a real glyph layout (crater's
/// `@glyph`) but needs a configured font provider and a texture-capable
/// backend to show actual glyph shapes. This bitmap font is the
/// self-contained alternative: it renders readable ASCII glyphs as solid
/// fill quads (one per lit cell), so text can be drawn to pixels
/// deterministically with no external font and on any backend that draws
/// solid quads (e.g. gfx_software). It mirrors kagura's debug dot-matrix
/// text path.
///
/// Coverage: space, 0-9, A-Z (uppercase). Unknown characters render blank.

///|
/// The 7 rows (top to bottom) of a 5-wide glyph as "#"/" " strings, or
/// `None` for an unsupported character. Lowercase letters fall back to
/// their uppercase form.
fn glyph_rows(ch : Char) -> Array[String]? {
  let c = if ch >= 'a' && ch <= 'z' {
    Int::unsafe_to_char(ch.to_int() - 32)
  } else {
    ch
  }
  match c {
    ' ' => Some(["     ", "     ", "     ", "     ", "     ", "     ", "     "])
    '0' => Some([" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "])
    '1' => Some(["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "])
    '2' => Some([" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"])
    '3' => Some(["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "])
    '4' => Some(["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "])
    '5' => Some(["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "])
    '6' => Some(["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "])
    '7' => Some(["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "])
    '8' => Some([" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "])
    '9' => Some([" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "])
    'A' => Some([" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"])
    'B' => Some(["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "])
    'C' => Some([" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "])
    'D' => Some(["###  ", "#  # ", "#   #", "#   #", "#   #", "#  # ", "###  "])
    'E' => Some(["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"])
    'F' => Some(["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "])
    'G' => Some([" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ### "])
    'H' => Some(["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"])
    'I' => Some([" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "])
    'J' => Some(["  ###", "   # ", "   # ", "   # ", "#  # ", "#  # ", " ##  "])
    'K' => Some(["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"])
    'L' => Some(["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"])
    'M' => Some(["#   #", "## ##", "# # #", "#   #", "#   #", "#   #", "#   #"])
    'N' => Some(["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"])
    'O' => Some([" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "])
    'P' => Some(["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "])
    'Q' => Some([" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"])
    'R' => Some(["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"])
    'S' => Some([" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "])
    'T' => Some(["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "])
    'U' => Some(["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "])
    'V' => Some(["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "])
    'W' => Some(["#   #", "#   #", "#   #", "#   #", "# # #", "## ##", "#   #"])
    'X' => Some(["#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #"])
    'Y' => Some(["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "])
    'Z' => Some(["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"])
    _ => None
  }
}

///|
/// Width / height of a single glyph cell, and the inter-glyph advance, in
/// font cells (multiply by the pixel scale).
pub let bitmap_glyph_w : Int = 5

///|
pub let bitmap_glyph_h : Int = 7

///|
/// Lower `text` into solid fill commands using the built-in 5x7 font, at
/// pixel position `(x, y)`, with each font cell `scale` pixels square.
/// Glyphs advance by `(5 + 1) * scale` pixels; unsupported characters
/// advance but draw nothing.
pub fn bitmap_text_commands(
  frame : @gfx_frame.RenderFrame2D,
  text : String,
  x : Int,
  y : Int,
  scale : Int,
  color : @gfx.Color,
) -> Array[@gfx.DrawTrianglesCommand] {
  let commands : Array[@gfx.DrawTrianglesCommand] = []
  let s = if scale < 1 { 1 } else { scale }
  let advance = (bitmap_glyph_w + 1) * s
  let mut pen_x = x
  for ch in text {
    match glyph_rows(ch) {
      Some(rows) =>
        for row in 0..<rows.length() {
          let line = rows[row]
          for col in 0..<bitmap_glyph_w {
            if col < line.length() && line[col] == '#' {
              let (vertices, indices) = @gfx_frame.ndc_rect_fill_vertices(
                (pen_x + col * s).to_double(),
                (y + row * s).to_double(),
                s.to_double(),
                s.to_double(),
                frame.screen_w.to_double(),
                frame.screen_h.to_double(),
              )
              commands.push(
                @gfx_frame.new_primitive_command(
                  frame, vertices, indices, color,
                ),
              )
            }
          }
        }
      None => ()
    }
    pen_x = pen_x + advance
  }
  commands
}

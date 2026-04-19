///|
/// Global font storage
let global_font : Ref[@font.TTFont?] = { val: None }

///|
/// Load font from bytes and return info JSON, or empty string on failure
pub fn loadFont(data : Bytes) -> String {
  match @font.parse_font(data) {
    Some(font) => {
      global_font.val = Some(font)
      let buf = StringBuilder::new()
      buf.write_string("{\"units_per_em\":")
      buf.write_string(font.units_per_em.to_string())
      buf.write_string(",\"num_glyphs\":")
      buf.write_string(font.num_glyphs.to_string())
      buf.write_string(",\"ascent\":")
      buf.write_string(font.ascent.to_string())
      buf.write_string(",\"descent\":")
      buf.write_string(font.descent.to_string())
      buf.write_string("}")
      buf.to_string()
    }
    None => ""
  }
}

///|
/// Get font metrics as JSON
pub fn getFontInfo() -> String {
  match global_font.val {
    Some(font) => {
      let buf = StringBuilder::new()
      buf.write_string("{\"units_per_em\":")
      buf.write_string(font.units_per_em.to_string())
      buf.write_string(",\"num_glyphs\":")
      buf.write_string(font.num_glyphs.to_string())
      buf.write_string(",\"ascent\":")
      buf.write_string(font.ascent.to_string())
      buf.write_string(",\"descent\":")
      buf.write_string(font.descent.to_string())
      buf.write_string("}")
      buf.to_string()
    }
    None => ""
  }
}

///|
/// Get glyph outline as SVG path data string
/// Returns SVG path d attribute for the given codepoint at the given font size
pub fn glyphToSvgPath(codepoint : Int, font_size : Double) -> String {
  match global_font.val {
    Some(font) => {
      let cmds = font.scaled_outline(codepoint, font_size)
      commands_to_svg_path(cmds)
    }
    None => ""
  }
}

///|
/// Get glyph advance width scaled to font size
pub fn glyphAdvance(codepoint : Int, font_size : Double) -> Double {
  match global_font.val {
    Some(font) => {
      let gid = font.glyph_index(codepoint)
      let metrics = font.glyph_metrics(gid)
      metrics.advance_width.to_double() *
      font_size /
      font.units_per_em.to_double()
    }
    None => 0.0
  }
}

///|
/// Get font name by nameID
pub fn fontName(name_id : Int) -> String {
  match global_font.val {
    Some(font) => font.font_name(name_id).unwrap_or("")
    None => ""
  }
}

///|
/// Get kerning advance for two codepoints at given font size
pub fn kernAdvance(cp1 : Int, cp2 : Int, font_size : Double) -> Double {
  match global_font.val {
    Some(font) => {
      let gid1 = font.glyph_index(cp1)
      let gid2 = font.glyph_index(cp2)
      let kern = font.kern_pair(gid1, gid2)
      kern.to_double() * font_size / font.units_per_em.to_double()
    }
    None => 0.0
  }
}

///|
/// Layout text and return JSON array of glyph positions
pub fn layoutText(text : String, font_size : Double) -> String {
  match global_font.val {
    Some(font) => {
      let positions = font.layout_text(text, font_size)
      let buf = StringBuilder::new()
      buf.write_char('[')
      for i, pos in positions {
        if i > 0 {
          buf.write_char(',')
        }
        buf.write_string("{\"codepoint\":")
        buf.write_string(pos.codepoint.to_string())
        buf.write_string(",\"glyph_id\":")
        buf.write_string(pos.glyph_id.to_string())
        buf.write_string(",\"x_offset\":")
        write_num(buf, pos.x_offset)
        buf.write_string(",\"y_offset\":")
        write_num(buf, pos.y_offset)
        buf.write_string(",\"x_advance\":")
        write_num(buf, pos.x_advance)
        buf.write_char('}')
      }
      buf.write_char(']')
      buf.to_string()
    }
    None => "[]"
  }
}

///|
/// Measure text width at given font size
pub fn measureText(text : String, font_size : Double) -> Double {
  match global_font.val {
    Some(font) => font.measure_text(text, font_size)
    None => 0.0
  }
}

///|
/// Get font weight class from OS/2 table
pub fn fontWeightClass() -> Int {
  match global_font.val {
    Some(font) => font.weight_class()
    None => 0
  }
}

///|
/// Check if font is fixed pitch (returns 0 or 1)
pub fn isFixedPitch() -> Int {
  match global_font.val {
    Some(font) => if font.is_fixed_pitch() { 1 } else { 0 }
    None => 0
  }
}

///|
/// Get codepoint coverage as JSON array
pub fn codepointCoverage() -> String {
  match global_font.val {
    Some(font) => {
      let cps = font.codepoint_coverage()
      let buf = StringBuilder::new()
      buf.write_char('[')
      for i, cp in cps {
        if i > 0 {
          buf.write_char(',')
        }
        buf.write_string(cp.to_string())
      }
      buf.write_char(']')
      buf.to_string()
    }
    None => "[]"
  }
}

///|
/// Get all glyph IDs as JSON array
pub fn glyphIds() -> String {
  match global_font.val {
    Some(font) => {
      let ids = font.glyph_ids()
      let buf = StringBuilder::new()
      buf.write_char('[')
      for i, id in ids {
        if i > 0 {
          buf.write_char(',')
        }
        buf.write_string(id.to_string())
      }
      buf.write_char(']')
      buf.to_string()
    }
    None => "[]"
  }
}

///|
/// Get table sizes as JSON object
pub fn tableSizes() -> String {
  match global_font.val {
    Some(font) =>
      match @font.analyze_tables(font.data) {
        Some(tables) => {
          let buf = StringBuilder::new()
          buf.write_char('{')
          for i, tbl in tables {
            if i > 0 {
              buf.write_char(',')
            }
            buf.write_char('"')
            buf.write_string(tbl.tag)
            buf.write_string("\":")
            buf.write_string(tbl.length.to_string())
          }
          buf.write_char('}')
          buf.to_string()
        }
        None => "{}"
      }
    None => "{}"
  }
}

///|
/// Convert PathCommand array to SVG path data string
fn commands_to_svg_path(cmds : Array[@svg.PathCommand]) -> String {
  let buf = StringBuilder::new()
  for cmd in cmds {
    if buf.to_string().length() > 0 {
      buf.write_char(' ')
    }
    match cmd {
      @svg.MoveTo(x, y) => {
        buf.write_char('M')
        write_num(buf, x)
        buf.write_char(' ')
        write_num(buf, y)
      }
      @svg.LineTo(x, y) => {
        buf.write_char('L')
        write_num(buf, x)
        buf.write_char(' ')
        write_num(buf, y)
      }
      @svg.QuadraticCurveTo(cx, cy, x, y) => {
        buf.write_char('Q')
        write_num(buf, cx)
        buf.write_char(' ')
        write_num(buf, cy)
        buf.write_char(' ')
        write_num(buf, x)
        buf.write_char(' ')
        write_num(buf, y)
      }
      @svg.CurveTo(cx1, cy1, cx2, cy2, x, y) => {
        buf.write_char('C')
        write_num(buf, cx1)
        buf.write_char(' ')
        write_num(buf, cy1)
        buf.write_char(' ')
        write_num(buf, cx2)
        buf.write_char(' ')
        write_num(buf, cy2)
        buf.write_char(' ')
        write_num(buf, x)
        buf.write_char(' ')
        write_num(buf, y)
      }
      @svg.ClosePath => buf.write_char('Z')
      _ => ()
    }
  }
  buf.to_string()
}

///|
/// Write a number rounded to 2 decimal places
fn write_num(buf : StringBuilder, n : Double) -> Unit {
  let rounded = (n * 100.0).to_int().to_double() / 100.0
  buf.write_string(rounded.to_string())
}

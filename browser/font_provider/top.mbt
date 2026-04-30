///|
#cfg(target="js")
extern "js" fn js_read_binary_file(path : String) -> Bytes =
  #| (path) => {
  #|   if (typeof process === "undefined") return new Uint8Array(0);
  #|   try {
  #|     const fs = require("node:fs");
  #|     const buf = fs.readFileSync(String(path));
  #|     return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  #|   } catch (_err) {
  #|     return new Uint8Array(0);
  #|   }
  #| }

///|
#cfg(not(target="js"))
fn js_read_binary_file(_path : String) -> Bytes {
  Bytes::new(0)
}

///|
fn system_font_face_candidates() -> Array[(Array[String], Array[String])] {
  [
    (
      [
        "/System/Library/Fonts/Supplemental/Arial.ttf", "/Library/Fonts/Arial.ttf",
      ],
      [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/Library/Fonts/Arial Bold.ttf",
      ],
    ),
    (
      [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
      ],
      [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
      ],
    ),
    (["/System/Library/Fonts/SFNS.ttf"], []),
    (
      [
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf", "/Library/Fonts/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/AppleGothic.ttf", "/Library/Fonts/AppleGothic.ttf",
        "/System/Library/Fonts/Hiragino Sans GB.ttc", "/System/Library/Fonts/STHeiti Light.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc", "/usr/local/share/fonts/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJKjp-Regular.otf", "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
      ],
      [
        "/System/Library/Fonts/STHeiti Medium.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc", "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",
        "/usr/local/share/fonts/NotoSansCJK-Bold.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJKjp-Bold.otf",
        "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc",
      ],
    ),
  ]
}

///|
fn load_first_glyph_provider(paths : Array[String]) -> @image.GlyphProvider? {
  for path in paths {
    let data = js_read_binary_file(path)
    if data.length() > 100 {
      match @image.glyph_provider_from_bytes(data) {
        Some(provider) => return Some(provider)
        None => ()
      }
    }
  }
  None
}

///|
fn provider_for_weight(
  pair : (@image.GlyphProvider, @image.GlyphProvider?),
  is_bold : Bool,
) -> @image.GlyphProvider {
  let (regular, bold) = pair
  if is_bold {
    match bold {
      Some(bold_provider) => bold_provider
      None => regular
    }
  } else {
    regular
  }
}

///|
fn glyph_from_pair(
  pair : (@image.GlyphProvider, @image.GlyphProvider?),
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> (Array[@svg.PathCommand], Double) {
  let provider = provider_for_weight(pair, is_bold)
  (provider.get_glyph)(codepoint, font_size, is_bold)
}

///|
fn choose_glyph(
  providers : Array[(@image.GlyphProvider, @image.GlyphProvider?)],
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> (Array[@svg.PathCommand], Double) {
  let first = glyph_from_pair(providers[0], codepoint, font_size, is_bold)
  let (_, first_advance) = first
  if first_advance > 0.0 {
    return first
  }
  for pair in providers {
    let candidate = glyph_from_pair(pair, codepoint, font_size, is_bold)
    let (_, advance) = candidate
    if advance > 0.0 {
      return candidate
    }
  }
  first
}

///|
fn max_ascent(pair : (@image.GlyphProvider, @image.GlyphProvider?)) -> Double {
  let (regular, bold) = pair
  match bold {
    Some(bold_provider) =>
      if bold_provider.ascent_ratio > regular.ascent_ratio {
        bold_provider.ascent_ratio
      } else {
        regular.ascent_ratio
      }
    None => regular.ascent_ratio
  }
}

///|
fn resolve_ascent_ratio(
  providers : Array[(@image.GlyphProvider, @image.GlyphProvider?)],
) -> Double {
  let mut ascent = max_ascent(providers[0])
  for pair in providers {
    let candidate = max_ascent(pair)
    if candidate > ascent {
      ascent = candidate
    }
  }
  ascent
}

///|
fn merge_glyph_provider_pairs(
  providers : Array[(@image.GlyphProvider, @image.GlyphProvider?)],
) -> @image.GlyphProvider {
  {
    get_glyph: fn(codepoint, font_size, is_bold) {
      choose_glyph(providers, codepoint, font_size, is_bold)
    },
    get_kern: fn(cp1, cp2, font_size, is_bold) {
      let provider = provider_for_weight(providers[0], is_bold)
      (provider.get_kern)(cp1, cp2, font_size, is_bold)
    },
    ascent_ratio: resolve_ascent_ratio(providers),
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_ascent_for_family: None,
  }
}

///|
pub fn load_system_glyph_provider() -> @image.GlyphProvider? {
  let providers : Array[(@image.GlyphProvider, @image.GlyphProvider?)] = []
  for candidate in system_font_face_candidates() {
    let (regular_paths, bold_paths) = candidate
    match load_first_glyph_provider(regular_paths) {
      Some(regular_provider) => {
        let bold_provider = if bold_paths.is_empty() {
          None
        } else {
          load_first_glyph_provider(bold_paths)
        }
        providers.push((regular_provider, bold_provider))
      }
      None => ()
    }
  }
  if providers.is_empty() {
    None
  } else {
    Some(merge_glyph_provider_pairs(providers))
  }
}

///|
pub fn install_system_glyph_provider() -> Bool {
  match load_system_glyph_provider() {
    Some(provider) => {
      @image.set_glyph_provider(provider)
      true
    }
    None => false
  }
}

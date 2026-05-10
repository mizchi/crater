///|
pub(all) struct RgbaCacheEntry {
  width : Int
  height : Int
  rgba_base64 : String
}

///|
fn make_substr(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end && i < chars.length(); i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
pub fn RgbaCacheEntry::encode(self : RgbaCacheEntry) -> String {
  self.width.to_string() +
  ":" +
  self.height.to_string() +
  ":" +
  self.rgba_base64
}

///|
pub fn RgbaCacheEntry::decode_rgba_bytes(self : RgbaCacheEntry) -> Array[Int]? {
  decode_base64_bytes(self.rgba_base64)
}

///|
fn decode_base64_char(c : Char) -> Int? {
  let cp = c.to_int()
  if cp >= 'A'.to_int() && cp <= 'Z'.to_int() {
    Some(cp - 'A'.to_int())
  } else if cp >= 'a'.to_int() && cp <= 'z'.to_int() {
    Some(cp - 'a'.to_int() + 26)
  } else if cp >= '0'.to_int() && cp <= '9'.to_int() {
    Some(cp - '0'.to_int() + 52)
  } else if c == '+' {
    Some(62)
  } else if c == '/' {
    Some(63)
  } else {
    None
  }
}

///|
fn decode_base64_bytes(encoded : String) -> Array[Int]? {
  let bytes : Array[Int] = []
  let quartet : Array[Int] = []
  for c in encoded {
    if c.is_ascii_whitespace() {
      continue
    }
    if c == '=' {
      quartet.push(-1)
    } else {
      match decode_base64_char(c) {
        Some(v) => quartet.push(v)
        None => return None
      }
    }
    if quartet.length() == 4 {
      let v0 = quartet[0]
      let v1 = quartet[1]
      let v2 = quartet[2]
      let v3 = quartet[3]
      if v0 < 0 || v1 < 0 {
        return None
      }
      bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF)
      if v2 >= 0 {
        bytes.push((((v1 & 0x0F) << 4) | (v2 >> 2)) & 0xFF)
      }
      if v2 >= 0 && v3 >= 0 {
        bytes.push((((v2 & 0x03) << 6) | v3) & 0xFF)
      }
      if v2 < 0 || v3 < 0 {
        break
      }
      quartet.clear()
    }
  }
  Some(bytes)
}

///|
pub(all) enum TerminalImageCacheEntry {
  Svg(String)
  PngBase64(String)
  RgbaBase64(RgbaCacheEntry)
  RawBase64(String)
}

///|
pub fn TerminalImageCacheEntry::encode(
  self : TerminalImageCacheEntry,
) -> String {
  match self {
    Svg(svg_text) => "svg:" + svg_text
    PngBase64(b64_data) => "img_png:" + b64_data
    RgbaBase64(entry) => "img_rgba:" + entry.encode()
    RawBase64(b64_data) => "img:" + b64_data
  }
}

///|
fn parse_int_ascii(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
fn parse_kitty_rgba_cache_entry(entry : String) -> RgbaCacheEntry? {
  match entry.find(":") {
    Some(width_end) => {
      let width_str = entry.unsafe_substring(start=0, end=width_end)
      let rest = entry.unsafe_substring(start=width_end + 1, end=entry.length())
      match rest.find(":") {
        Some(height_end) => {
          let height_str = rest.unsafe_substring(start=0, end=height_end)
          let rgba_base64 = rest.unsafe_substring(
            start=height_end + 1,
            end=rest.length(),
          )
          let width = parse_int_ascii(width_str)
          let height = parse_int_ascii(height_str)
          if width > 0 && height > 0 && rgba_base64.length() > 0 {
            Some({ width, height, rgba_base64 })
          } else {
            None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
pub fn parse_terminal_image_cache_entry(
  cached_data : String,
) -> TerminalImageCacheEntry? {
  if cached_data.has_prefix("svg:") {
    Some(Svg(cached_data.unsafe_substring(start=4, end=cached_data.length())))
  } else if cached_data.has_prefix("img_png:") {
    Some(
      PngBase64(cached_data.unsafe_substring(start=8, end=cached_data.length())),
    )
  } else if cached_data.has_prefix("img_rgba:") {
    match
      parse_kitty_rgba_cache_entry(
        cached_data.unsafe_substring(start=9, end=cached_data.length()),
      ) {
      Some(entry) => Some(RgbaBase64(entry))
      None => None
    }
  } else if cached_data.has_prefix("img:") {
    Some(
      RawBase64(cached_data.unsafe_substring(start=4, end=cached_data.length())),
    )
  } else {
    None
  }
}

///|
pub fn detect_raster_image_format_from_base64(b64_data : String) -> String {
  if b64_data.has_prefix("iVBORw0KGgo") {
    "png"
  } else if b64_data.has_prefix("/9j/") {
    "jpeg"
  } else if b64_data.has_prefix("R0lGOD") {
    "gif"
  } else {
    "unknown"
  }
}

///|
#cfg(target="js")
extern "js" fn js_decode_raster_image_to_rgba_base64(
  image_format : String,
  b64_data : String,
) -> String =
  #| (imageFormat, b64Data) => {
  #|   try {
  #|     if (typeof process === 'undefined' || process.platform !== 'darwin') {
  #|       return '';
  #|     }
  #|     const format = String(imageFormat || '').toLowerCase();
  #|     if (format !== 'png' && format !== 'jpeg' && format !== 'gif') {
  #|       return '';
  #|     }
  #|     const fs = require('node:fs');
  #|     const os = require('node:os');
  #|     const path = require('node:path');
  #|     const { execFileSync } = require('node:child_process');
  #|     function loadPng() {
  #|       try {
  #|         return require('pngjs').PNG;
  #|       } catch (_) {
  #|         const candidates = [
  #|           path.join(process.cwd(), 'node_modules', 'pngjs'),
  #|           path.join(process.cwd(), 'browser', 'node_modules', 'pngjs'),
  #|         ];
  #|         for (const candidate of candidates) {
  #|           try {
  #|             return require(candidate).PNG;
  #|           } catch (_) {}
  #|         }
  #|         throw new Error('pngjs not found');
  #|       }
  #|     }
  #|     const PNG = loadPng();
  #|     if (format === 'png') {
  #|       const decoded = PNG.sync.read(Buffer.from(String(b64Data || ''), 'base64'));
  #|       return (
  #|         String(decoded.width) +
  #|         ':' +
  #|         String(decoded.height) +
  #|         ':' +
  #|         Buffer.from(decoded.data).toString('base64')
  #|       );
  #|     }
  #|     const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'crater-kitty-'));
  #|     const inputExt = format === 'jpeg' ? 'jpg' : 'gif';
  #|     const inputPath = path.join(dir, 'input.' + inputExt);
  #|     const outputPath = path.join(dir, 'output.png');
  #|     try {
  #|       fs.writeFileSync(inputPath, Buffer.from(String(b64Data || ''), 'base64'));
  #|       execFileSync(
  #|         'sips',
  #|         ['-s', 'format', 'png', inputPath, '--out', outputPath],
  #|         { stdio: 'pipe' },
  #|       );
  #|       const pngBuffer = fs.readFileSync(outputPath);
  #|       const decoded = PNG.sync.read(pngBuffer);
  #|       return (
  #|         String(decoded.width) +
  #|         ':' +
  #|         String(decoded.height) +
  #|         ':' +
  #|         Buffer.from(decoded.data).toString('base64')
  #|       );
  #|     } finally {
  #|       try {
  #|         fs.rmSync(dir, { recursive: true, force: true });
  #|       } catch (_) {}
  #|     }
  #|   } catch (_) {
  #|     return '';
  #|   }
  #| }

///|
#cfg(target="js")
fn decode_raster_image_to_rgba_base64(
  image_format : String,
  b64_data : String,
) -> String? {
  let decoded = js_decode_raster_image_to_rgba_base64(image_format, b64_data)
  if decoded.length() > 0 {
    Some(decoded)
  } else {
    None
  }
}

///|
#cfg(target="native")
fn decode_raster_image_to_rgba_base64(
  _image_format : String,
  _b64_data : String,
) -> String? {
  None
}

///|
pub fn decode_raster_image_to_rgba_cache_entry(
  image_format : String,
  b64_data : String,
) -> RgbaCacheEntry? {
  match decode_raster_image_to_rgba_base64(image_format, b64_data) {
    Some(entry) => parse_kitty_rgba_cache_entry(entry)
    None => None
  }
}

///|
#cfg(target="js")
extern "js" fn js_transcode_raster_image_to_png_base64(
  image_format : String,
  b64_data : String,
) -> String =
  #| (imageFormat, b64Data) => {
  #|   try {
  #|     if (typeof process === 'undefined' || process.platform !== 'darwin') {
  #|       return '';
  #|     }
  #|     const format = String(imageFormat || '').toLowerCase();
  #|     if (format !== 'jpeg' && format !== 'gif') {
  #|       return '';
  #|     }
  #|     const fs = require('node:fs');
  #|     const os = require('node:os');
  #|     const path = require('node:path');
  #|     const { execFileSync } = require('node:child_process');
  #|     const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'crater-kitty-'));
  #|     const inputExt = format === 'jpeg' ? 'jpg' : 'gif';
  #|     const inputPath = path.join(dir, 'input.' + inputExt);
  #|     const outputPath = path.join(dir, 'output.png');
  #|     try {
  #|       fs.writeFileSync(inputPath, Buffer.from(String(b64Data || ''), 'base64'));
  #|       execFileSync(
  #|         'sips',
  #|         ['-s', 'format', 'png', inputPath, '--out', outputPath],
  #|         { stdio: 'pipe' },
  #|       );
  #|       return fs.readFileSync(outputPath).toString('base64');
  #|     } finally {
  #|       try {
  #|         fs.rmSync(dir, { recursive: true, force: true });
  #|       } catch (_) {}
  #|     }
  #|   } catch (_) {
  #|     return '';
  #|   }
  #| }

///|
#cfg(target="js")
fn transcode_raster_image_to_png_base64(
  image_format : String,
  b64_data : String,
) -> String? {
  let transcoded = js_transcode_raster_image_to_png_base64(
    image_format, b64_data,
  )
  if transcoded.length() > 0 {
    Some(transcoded)
  } else {
    None
  }
}

///|
#cfg(target="native")
fn transcode_raster_image_to_png_base64(
  _image_format : String,
  _b64_data : String,
) -> String? {
  None
}

///|
pub fn normalize_raster_image_for_kitty(b64_data : String) -> String {
  let image_format = detect_raster_image_format_from_base64(b64_data)
  if image_format == "png" {
    return b64_data
  }
  match transcode_raster_image_to_png_base64(image_format, b64_data) {
    Some(transcoded) => transcoded
    None => b64_data
  }
}

///|
pub fn prepare_raster_image_for_kitty_cache(b64_data : String) -> String {
  let image_format = detect_raster_image_format_from_base64(b64_data)
  if image_format == "png" {
    return TerminalImageCacheEntry::PngBase64(b64_data).encode()
  }
  match decode_raster_image_to_rgba_cache_entry(image_format, b64_data) {
    Some(entry) => TerminalImageCacheEntry::RgbaBase64(entry).encode()
    None => {
      let normalized = normalize_raster_image_for_kitty(b64_data)
      if detect_raster_image_format_from_base64(normalized) == "png" {
        TerminalImageCacheEntry::PngBase64(normalized).encode()
      } else {
        TerminalImageCacheEntry::RawBase64(b64_data).encode()
      }
    }
  }
}

///|
fn hex_digit_to_int(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn percent_decode_data_url_payload(payload : String) -> String {
  let chars = payload.to_array()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '%' && i + 2 < chars.length() {
      match (hex_digit_to_int(chars[i + 1]), hex_digit_to_int(chars[i + 2])) {
        (Some(high), Some(low)) => {
          buf.write_char((high * 16 + low).unsafe_to_char())
          i = i + 3
        }
        _ => {
          buf.write_char(chars[i])
          i = i + 1
        }
      }
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
fn data_url_payload_end(chars : Array[Char], start : Int) -> Int {
  let mut end = chars.length()
  for i = start; i < chars.length(); i = i + 1 {
    if chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  end
}

///|
fn remove_ascii_whitespace(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if !c.is_ascii_whitespace() {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
pub fn data_image_src_to_kitty_cache(src : String) -> String? {
  if !src.to_lower().has_prefix("data:") {
    return None
  }
  let chars = src.to_array()
  let mut comma_idx = -1
  for i = 5; i < chars.length(); i = i + 1 {
    if chars[i] == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  let header = make_substr(chars, 5, comma_idx).to_lower()
  if !header.has_prefix("image/") {
    return None
  }
  let payload_end = data_url_payload_end(chars, comma_idx + 1)
  let payload = make_substr(chars, comma_idx + 1, payload_end)
  if header.has_prefix("image/svg+xml") {
    if header.contains(";base64") {
      return None
    }
    return Some(
      TerminalImageCacheEntry::Svg(percent_decode_data_url_payload(payload)).encode(),
    )
  }
  if !header.contains(";base64") {
    return None
  }
  if header.has_prefix("image/png") ||
    header.has_prefix("image/jpeg") ||
    header.has_prefix("image/jpg") ||
    header.has_prefix("image/gif") ||
    header.has_prefix("image/webp") {
    Some(prepare_raster_image_for_kitty_cache(remove_ascii_whitespace(payload)))
  } else {
    None
  }
}
